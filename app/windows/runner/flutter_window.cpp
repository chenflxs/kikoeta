#include "flutter_window.h"

#include <optional>
#include <string>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "process_shutdown.h"

namespace {
constexpr int kLyricsHotkeyIds[] = {0x4B10, 0x4B11};
constexpr UINT kLyricsHotkeyModifiers = MOD_CONTROL | MOD_ALT | MOD_SHIFT;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  lifecycle_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "kikoeta/lifecycle",
          &flutter::StandardMethodCodec::GetInstance());
  lifecycle_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "registerLyricsHotkey") {
          const auto* args =
              std::get_if<flutter::EncodableList>(call.arguments());
          if (args == nullptr || args->size() != 2) {
            result->Error("lyrics_hotkey_arguments");
            return;
          }
          const auto* modifiers = std::get_if<int32_t>(&(*args)[0]);
          const auto* key = std::get_if<int32_t>(&(*args)[1]);
          if (modifiers == nullptr || key == nullptr ||
              (*modifiers & ~kLyricsHotkeyModifiers) != 0 ||
              (*modifiers & (MOD_CONTROL | MOD_ALT)) == 0 ||
              *key <= 0 || *key > 0xFE) {
            result->Error("lyrics_hotkey_arguments");
            return;
          }
          if (lyrics_hotkey_window_ != nullptr &&
              lyrics_hotkey_modifiers_ == static_cast<UINT>(*modifiers) &&
              lyrics_hotkey_key_ == static_cast<UINT>(*key)) {
            result->Success();
            return;
          }
          const HWND window = GetHandle();
          const int next_id = lyrics_hotkey_id_ == kLyricsHotkeyIds[0]
                                  ? kLyricsHotkeyIds[1]
                                  : kLyricsHotkeyIds[0];
          // Acquire the new combination first so a conflict preserves the
          // existing shortcut.
          if (!RegisterHotKey(window, next_id, *modifiers | MOD_NOREPEAT,
                              *key)) {
            result->Error("lyrics_hotkey_registration",
                          std::to_string(GetLastError()));
            return;
          }
          if (lyrics_hotkey_window_ != nullptr &&
              !UnregisterHotKey(lyrics_hotkey_window_, lyrics_hotkey_id_)) {
            const DWORD error = GetLastError();
            UnregisterHotKey(window, next_id);
            result->Error("lyrics_hotkey_registration", std::to_string(error));
            return;
          }
          lyrics_hotkey_window_ = window;
          lyrics_hotkey_id_ = next_id;
          lyrics_hotkey_modifiers_ = *modifiers;
          lyrics_hotkey_key_ = *key;
          result->Success();
        } else if (call.method_name() != "beginExit") {
          result->NotImplemented();
        } else if (ProcessShutdown::Begin()) {
          result->Success();
        } else {
          result->Error("shutdown_watchdog", "Cannot start shutdown watchdog");
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (lyrics_hotkey_window_ != nullptr) {
    UnregisterHotKey(lyrics_hotkey_window_, lyrics_hotkey_id_);
    lyrics_hotkey_window_ = nullptr;
  }
  lifecycle_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY &&
      wparam == static_cast<WPARAM>(lyrics_hotkey_id_) &&
      (LOWORD(lparam) & kLyricsHotkeyModifiers) == lyrics_hotkey_modifiers_ &&
      HIWORD(lparam) == lyrics_hotkey_key_ &&
      lyrics_hotkey_window_ != nullptr && lifecycle_channel_) {
    lifecycle_channel_->InvokeMethod("toggleDesktopLyrics", nullptr);
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
