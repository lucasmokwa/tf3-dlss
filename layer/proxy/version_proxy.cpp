// version.dll stand-in for the drop-in install: placed next to TransportFever3.exe, Windows loads it
// instead of System32\version.dll (the application folder comes first in the DLL search order).
//
//   * At process start (DllMain) it points the Vulkan loader at our layer for this process only:
//     VK_ADD_LAYER_PATH = <game folder>\TF3-DLSS\bin, and enables VK_LAYER_TF3_dlss through
//     VK_INSTANCE_LAYERS / VK_LOADER_LAYERS_ENABLE, the same variables scripts\run_tf3.ps1 sets.
//   * Every version.dll function is passed on to the real System32\version.dll, loaded on first use.
//
// No registry, nothing outside the game folder: deleting version.dll and TF3-DLSS\ uninstalls.
// TF3_DLSS_DISABLE=1 makes it a plain pass-through.
#include <windows.h>

#include <cstdint>
#include <cwchar>

namespace {

bool EnvContains(const wchar_t* name, const wchar_t* value) {
    wchar_t cur[4096] = {};
    DWORD n = GetEnvironmentVariableW(name, cur, 4096);
    return n && n < 4096 && wcsstr(cur, value);
}

// Appends `value` to a ';'-separated environment variable unless it's already in it.
void AppendEnv(const wchar_t* name, const wchar_t* value) {
    wchar_t cur[4096] = {};
    DWORD n = GetEnvironmentVariableW(name, cur, 4096);
    if (n >= 4096) return;  // unexpectedly long; leave it alone
    if (n && wcsstr(cur, value)) return;
    wchar_t buf[4096 + 512] = {};
    if (n) {
        lstrcpynW(buf, cur, 4096);
        lstrcatW(buf, L";");
    }
    lstrcatW(buf, value);
    SetEnvironmentVariableW(name, buf);
}

bool IsGame() {
    wchar_t exe[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exe, MAX_PATH);
    const wchar_t* name = wcsrchr(exe, L'\\');
    return lstrcmpiW(name ? name + 1 : exe, L"TransportFever3.exe") == 0;
}

void EnableLayer(HMODULE self) {
    wchar_t dis[8] = {};
    if (GetEnvironmentVariableW(L"TF3_DLSS_DISABLE", dis, 8) && dis[0] == L'1') return;
    if (!IsGame()) return;
    // Already enabled for this launch (scripts\run_tf3.ps1 with a development build): that one wins.
    if (EnvContains(L"VK_INSTANCE_LAYERS", L"VK_LAYER_TF3_dlss") ||
        EnvContains(L"VK_LOADER_LAYERS_ENABLE", L"VK_LAYER_TF3_dlss"))
        return;
    wchar_t dir[MAX_PATH] = {};
    DWORD n = GetModuleFileNameW(self, dir, MAX_PATH);
    if (!n || n >= MAX_PATH) return;
    wchar_t* slash = wcsrchr(dir, L'\\');
    if (!slash) return;
    *slash = 0;
    wchar_t bin[MAX_PATH + 32] = {};
    lstrcpynW(bin, dir, MAX_PATH);
    lstrcatW(bin, L"\\TF3-DLSS\\bin");
    if (GetFileAttributesW(bin) == INVALID_FILE_ATTRIBUTES) return;  // mod folder missing: do nothing
    AppendEnv(L"VK_ADD_LAYER_PATH", bin);
    AppendEnv(L"VK_INSTANCE_LAYERS", L"VK_LAYER_TF3_dlss");       // older loaders
    AppendEnv(L"VK_LOADER_LAYERS_ENABLE", L"VK_LAYER_TF3_dlss");  // newer loaders
}

// ---- Pass-through to System32\version.dll -------------------------------------------------------
HMODULE RealVersion() {
    static HMODULE real = nullptr;
    if (!real) {
        wchar_t path[MAX_PATH + 16] = {};
        UINT n = GetSystemDirectoryW(path, MAX_PATH);
        if (!n || n >= MAX_PATH) return nullptr;
        lstrcatW(path, L"\\version.dll");
        real = LoadLibraryW(path);  // a full path loads the system copy, not this one again
    }
    return real;
}

FARPROC Real(const char* name) {
    HMODULE m = RealVersion();
    return m ? GetProcAddress(m, name) : nullptr;
}

}  // namespace

// x64 passes the first four integer/pointer arguments in registers and the rest on the stack, the
// same way for every function, and no version.dll function takes floating-point arguments. So each
// export forwards eight pointer-sized arguments: the real function uses as many as it declares.
using Fn8 = uintptr_t(WINAPI*)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t);

#define FORWARD(name)                                                                              \
    extern "C" uintptr_t WINAPI proxy_##name(uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d,   \
                                             uintptr_t e, uintptr_t f, uintptr_t g, uintptr_t h) { \
        static Fn8 fn = nullptr;                                                                   \
        if (!fn) fn = reinterpret_cast<Fn8>(Real(#name));                                          \
        if (!fn) {                                                                                 \
            SetLastError(ERROR_PROC_NOT_FOUND);                                                    \
            return 0;                                                                              \
        }                                                                                          \
        return fn(a, b, c, d, e, f, g, h);                                                         \
    }

FORWARD(GetFileVersionInfoA)
FORWARD(GetFileVersionInfoByHandle)
FORWARD(GetFileVersionInfoExA)
FORWARD(GetFileVersionInfoExW)
FORWARD(GetFileVersionInfoSizeA)
FORWARD(GetFileVersionInfoSizeExA)
FORWARD(GetFileVersionInfoSizeExW)
FORWARD(GetFileVersionInfoSizeW)
FORWARD(GetFileVersionInfoW)
FORWARD(VerFindFileA)
FORWARD(VerFindFileW)
FORWARD(VerInstallFileA)
FORWARD(VerInstallFileW)
FORWARD(VerLanguageNameA)
FORWARD(VerLanguageNameW)
FORWARD(VerQueryValueA)
FORWARD(VerQueryValueW)

BOOL WINAPI DllMain(HINSTANCE self, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(self);
        EnableLayer(self);  // kernel32 calls only: safe under the loader lock
    }
    return TRUE;
}
