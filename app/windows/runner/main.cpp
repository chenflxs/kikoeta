#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "window_constants.h"

namespace {

constexpr wchar_t kSingleInstanceMutexName[] =
    L"Global\\Kikoeta.SingleInstance.4A5549A4-E55C-4BFE-BC58-31DD5796FA66";
constexpr DWORD kExistingWindowWaitMs = 5000;
constexpr DWORD kExistingWindowRetryMs = 100;

enum class InstanceState {
  kPrimary,
  kAlreadyRunning,
  kError,
};

class ScopedHandle {
 public:
  HANDLE* receive() { return &handle_; }

  ~ScopedHandle() {
    if (handle_ != nullptr) {
      CloseHandle(handle_);
    }
  }

 private:
  HANDLE handle_ = nullptr;
};

void ActivateWindow(HWND window) {
  if (IsIconic(window)) {
    ShowWindow(window, SW_RESTORE);
  } else {
    ShowWindow(window, SW_SHOW);
  }
  BringWindowToTop(window);
  SetForegroundWindow(window);
}

// The mutex is owned by the kernel for the lifetime of the primary process.
// Releasing our handle between retries allows us to take over after a process
// that is still shutting down has fully exited.
InstanceState AcquireSingleInstance(HANDLE* instance_mutex) {
  ULONGLONG const deadline = GetTickCount64() + kExistingWindowWaitMs;

  while (true) {
    HANDLE mutex = CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
    if (mutex == nullptr) {
      return InstanceState::kError;
    }

    if (GetLastError() != ERROR_ALREADY_EXISTS) {
      *instance_mutex = mutex;
      return InstanceState::kPrimary;
    }

    HWND const existing_window =
        FindWindowW(kKikoetaWindowClassName, L"Kikoeta");
    if (existing_window != nullptr) {
      ActivateWindow(existing_window);
      CloseHandle(mutex);
      return InstanceState::kAlreadyRunning;
    }

    CloseHandle(mutex);
    if (GetTickCount64() >= deadline) {
      // The owner is still alive but has not created a window yet. Starting a
      // second process here would violate the single-instance guarantee.
      return InstanceState::kAlreadyRunning;
    }
    Sleep(kExistingWindowRetryMs);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Declare this before window resources so the mutex is released last.
  ScopedHandle instance_mutex;
  switch (AcquireSingleInstance(instance_mutex.receive())) {
    case InstanceState::kPrimary:
      break;
    case InstanceState::kAlreadyRunning:
      return EXIT_SUCCESS;
    case InstanceState::kError:
      MessageBoxW(nullptr,
                  L"\u65E0\u6CD5\u786E\u8BA4 Kikoeta \u662F\u5426\u5DF2\u5728\u8FD0\u884C\u3002"
                  L"\u4E3A\u907F\u514D\u540C\u65F6\u542F\u52A8\u591A\u4E2A\u8FDB\u7A0B\uFF0C"
                  L"\u672C\u6B21\u542F\u52A8\u5DF2\u53D6\u6D88\u3002",
                  L"Kikoeta", MB_OK | MB_ICONERROR);
      return EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Kikoeta", origin, size)) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
