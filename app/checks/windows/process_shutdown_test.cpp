#include "../../windows/runner/process_shutdown.h"

#include <iostream>
#include <string>

int wmain(int argc, wchar_t* argv[]) {
  if (argc != 3) return 1;
  if (std::wstring(argv[1]) == L"--child") {
    if (!LoadLibraryW(argv[2])) return 2;
    HANDLE locked = CreateFileW(argv[2], GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                                FILE_ATTRIBUTE_NORMAL, nullptr);
    if (locked != INVALID_HANDLE_VALUE) {
      CloseHandle(locked);
      return 10;
    }
    if (ProcessShutdown::Requested()) return 3;
    if (!ProcessShutdown::Begin() || !ProcessShutdown::Begin()) return 4;
    // Simulate a permanently blocked UI/engine teardown with a loaded DLL.
    Sleep(INFINITE);
    return 5;
  }

  std::wstring command = L"\"" + std::wstring(argv[0]) + L"\" --child \"" +
                         argv[2] + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION child{};
  const ULONGLONG start = GetTickCount64();
  if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &child)) {
    return 6;
  }
  const DWORD wait = WaitForSingleObject(child.hProcess, 7000);
  DWORD code = 1;
  GetExitCodeProcess(child.hProcess, &code);
  if (wait == WAIT_TIMEOUT) TerminateProcess(child.hProcess, 7);
  CloseHandle(child.hThread);
  CloseHandle(child.hProcess);
  const ULONGLONG elapsed = GetTickCount64() - start;
  if (wait != WAIT_OBJECT_0 || code != 0 || elapsed < 2500) return 8;

  HANDLE dll = CreateFileW(argv[2], GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                           FILE_ATTRIBUTE_NORMAL, nullptr);
  if (dll == INVALID_HANDLE_VALUE) return 9;
  CloseHandle(dll);
  std::cout << "PASS: blocked process exited in " << elapsed
            << "ms; loaded DLL can be opened exclusively for writing\n";
  return 0;
}
