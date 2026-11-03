#ifndef RUNNER_PROCESS_SHUTDOWN_H_
#define RUNNER_PROCESS_SHUTDOWN_H_

#include <windows.h>

#include <atomic>

// Window/engine destruction can block the platform thread and Dart timers.
// Arm this before cleanup, on an independent native thread.
class ProcessShutdown {
 public:
  static bool Begin() {
    if (requested_.exchange(true)) return true;
    HANDLE thread = CreateThread(nullptr, 0, Watchdog, nullptr, 0, nullptr);
    if (thread == nullptr) {
      requested_ = false;
      return false;
    }
    CloseHandle(thread);
    return true;
  }

  static bool Requested() { return requested_.load(); }

  static void Terminate() {
    // Unlike ExitProcess, this cannot wait on a plugin's DLL detach routine.
    TerminateProcess(GetCurrentProcess(), EXIT_SUCCESS);
  }

 private:
  static DWORD WINAPI Watchdog(void*) {
    Sleep(3000);
    Terminate();
    return 0;
  }

  inline static std::atomic<bool> requested_{false};
};

#endif  // RUNNER_PROCESS_SHUTDOWN_H_
