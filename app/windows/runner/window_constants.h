#ifndef RUNNER_WINDOW_CONSTANTS_H_
#define RUNNER_WINDOW_CONSTANTS_H_

// Keep this distinct from the default Flutter runner class so a second launch
// can reliably locate this application's existing top-level window.
inline constexpr wchar_t kKikoetaWindowClassName[] =
    L"KIKOETA_RUNNER_WINDOW_V1";

#endif  // RUNNER_WINDOW_CONSTANTS_H_
