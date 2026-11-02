// ============================================================================
//  NoBot 多版本版  ——  hid.dll
//
//  工作原理（与单版本版一致，只是支持多份 payload）：
//    1. UnityPlayer.dll 静态导入 HID.DLL，Windows 按「exe 所在目录优先」解析；
//    2. 本 DLL 把系统 hid.dll 的 47 个导出全部转发；
//    3. 启动后解析文件尾部 footer：
//         NBP1: magic + off + len                       （单 payload，兼容旧版）
//         NBP2: magic + count + (size, off, len)*count  （多 payload）
//       把每个 payload 释放到 %TEMP%\nobot-<pid>\<size>；
//    4. MinHook 挂钩 kernel32!CreateFileW，游戏只读打开
//       "com.unity.addressables\...\__data" 时，按文件大小匹配目标表，
//       命中就改成打开对应 payload 的临时文件；
//    5. 进程退出时删除临时文件。
//
//  构建：build.ps1（cl + ml64 + MinHook），产物尾部用 tools/make_nobot.py 追加 payload。
// ============================================================================
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>
#include "minhook/include/MinHook.h"

#define EXPORT_COUNT 47
#define MAX_TARGETS 8

void* g_targets[EXPORT_COUNT] = { 0 };

static const char* g_names[EXPORT_COUNT] = {
    "HidD_FlushQueue", "HidD_FreePreparsedData", "HidD_GetAttributes", "HidD_GetConfiguration",
    "HidD_GetFeature", "HidD_GetHidGuid", "HidD_GetIndexedString", "HidD_GetInputReport",
    "HidD_GetManufacturerString", "HidD_GetMsGenreDescriptor", "HidD_GetNumInputBuffers",
    "HidD_GetPhysicalDescriptor", "HidD_GetPreparsedData", "HidD_GetProductString",
    "HidD_GetSerialNumberString", "HidD_Hello", "HidD_SetConfiguration", "HidD_SetFeature",
    "HidD_SetNumInputBuffers", "HidD_SetOutputReport", "HidP_GetButtonArray", "HidP_GetButtonCaps",
    "HidP_GetCaps", "HidP_GetData", "HidP_GetExtendedAttributes", "HidP_GetLinkCollectionNodes",
    "HidP_GetScaledUsageValue", "HidP_GetSpecificButtonCaps", "HidP_GetSpecificValueCaps",
    "HidP_GetUsages", "HidP_GetUsagesEx", "HidP_GetUsageValue", "HidP_GetUsageValueArray",
    "HidP_GetValueCaps", "HidP_GetVersionInternal", "HidP_InitializeReportForID",
    "HidP_MaxDataListLength", "HidP_MaxUsageListLength", "HidP_SetButtonArray", "HidP_SetData",
    "HidP_SetScaledUsageValue", "HidP_SetUsages", "HidP_SetUsageValue", "HidP_SetUsageValueArray",
    "HidP_TranslateUsagesToI8042ScanCodes", "HidP_UnsetUsages", "HidP_UsageListDifference",
};

typedef struct {
    unsigned long long size;
    wchar_t path[MAX_PATH * 2];
} TargetEntry;

static TargetEntry g_tbl[MAX_TARGETS];
static int g_tblCount = 0;

static unsigned long long g_targetSize = 0;   // 兼容旧环境变量 NOBOT_TARGET_SIZE
static HMODULE  g_self = NULL;
static wchar_t  g_tempDir[MAX_PATH * 2] = { 0 };
static char     g_logPath[MAX_PATH * 2] = { 0 };
static volatile LONG g_hooked = 0;
static volatile LONG g_off = 0;

typedef HANDLE (WINAPI *PFN_CreateFileW)(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
static PFN_CreateFileW g_realCreateFileW = NULL;

// ------------------------------------------------------------------ 小工具
static void logmsg(const char* s)
{
    if (!g_logPath[0]) return;
    HANDLE h = CreateFileA(g_logPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return;
    DWORD n = (DWORD)strlen(s);
    DWORD w = 0;
    WriteFile(h, s, n, &w, NULL);
    WriteFile(h, "\r\n", 2, &w, NULL);
    CloseHandle(h);
}

static int is_digit(wchar_t c) { return c >= L'0' && c <= L'9'; }

static int contains_ci(const wchar_t* hay, const wchar_t* needle)
{
    if (!hay || !needle) return 0;
    size_t n = wcslen(needle);
    for (const wchar_t* p = hay; *p; ++p) {
        size_t i = 0;
        while (i < n && p[i] && towlower(p[i]) == towlower(needle[i])) i++;
        if (i == n) return 1;
    }
    return 0;
}

static int starts_with_ci(const wchar_t* s, const wchar_t* prefix)
{
    if (!s || !prefix) return 0;
    size_t n = wcslen(prefix);
    for (size_t i = 0; i < n; ++i) {
        if (!s[i] || towlower(s[i]) != towlower(prefix[i])) return 0;
    }
    return 1;
}

// ------------------------------------------------------------------ 路径
static void init_paths(void)
{
    wchar_t tmp[MAX_PATH * 2];
    DWORD m = GetTempPathW(MAX_PATH * 2, tmp);
    if (!m || m >= MAX_PATH * 2) return;
    wchar_t logW[MAX_PATH * 2];
    wsprintfW(logW, L"%snobot.log", tmp);
    WideCharToMultiByte(CP_UTF8, 0, logW, -1, g_logPath, sizeof(g_logPath), NULL, NULL);
}

static int build_temp_dir(void)
{
    wchar_t tmp[MAX_PATH * 2];
    DWORD m = GetTempPathW(MAX_PATH * 2, tmp);
    if (m == 0) return 0;
    wsprintfW(g_tempDir, L"%snobot-%lu", tmp, (unsigned long)GetCurrentProcessId());
    CreateDirectoryW(g_tempDir, NULL);
    return 1;
}

static void entry_path(int i, unsigned long long size)
{
    wsprintfW(g_tbl[i].path, L"%s\\%I64u.__data", g_tempDir, size);
    g_tbl[i].size = size;
}

// ------------------------------------------------------------------ 释放内嵌 payload
static int copy_range(HANDLE in, HANDLE out, unsigned long long off, unsigned long long len)
{
    LARGE_INTEGER pos;
    pos.QuadPart = (LONGLONG)off;
    if (!SetFilePointerEx(in, pos, NULL, FILE_BEGIN)) return 0;

    static unsigned char buf[1 << 20];
    unsigned long long left = len;
    while (left > 0) {
        DWORD want = (left > sizeof(buf)) ? (DWORD)sizeof(buf) : (DWORD)left;
        DWORD got = 0, wrote = 0;
        if (!ReadFile(in, buf, want, &got, NULL) || got == 0) return 0;
        if (!WriteFile(out, buf, got, &wrote, NULL) || wrote != got) return 0;
        left -= got;
    }
    return 1;
}

static int extract_one(HANDLE in, unsigned long long size, unsigned long long off, unsigned long long len)
{
    if (g_tblCount >= MAX_TARGETS) return 0;
    int i = g_tblCount;
    entry_path(i, size);
    HANDLE out = CreateFileW(g_tbl[i].path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (out == INVALID_HANDLE_VALUE) return 0;
    int ok = copy_range(in, out, off, len);
    CloseHandle(out);
    if (!ok) return 0;
    g_tblCount++;
    return 1;
}

static int extract_payloads(void)
{
    wchar_t self[MAX_PATH * 2];
    DWORD n = GetModuleFileNameW(g_self, self, MAX_PATH * 2);
    if (n == 0) return 0;

    HANDLE in = CreateFileW(self, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (in == INVALID_HANDLE_VALUE) { logmsg("open self failed"); return 0; }

    LARGE_INTEGER sz;
    if (!GetFileSizeEx(in, &sz) || sz.QuadPart < 32) { CloseHandle(in); logmsg("self too small"); return 0; }

    if (!build_temp_dir()) { CloseHandle(in); return 0; }

    unsigned char footer[20];
    LARGE_INTEGER pos;
    pos.QuadPart = sz.QuadPart - 20;
    if (!SetFilePointerEx(in, pos, NULL, FILE_BEGIN)) { CloseHandle(in); return 0; }
    DWORD rd = 0;
    if (!ReadFile(in, footer, 20, &rd, NULL) || rd != 20) { CloseHandle(in); return 0; }

    if (memcmp(footer, "NBP1", 4) == 0) {
        unsigned long long off = 0, len = 0;
        memcpy(&off, footer + 4, 8);
        memcpy(&len, footer + 12, 8);
        if (off < 20 || len == 0 || off + len > (unsigned long long)sz.QuadPart) {
            CloseHandle(in); logmsg("bad payload range"); return 0;
        }
        unsigned long long size = g_targetSize ? g_targetSize : 8339710ULL;
        if (!extract_one(in, size, off, len)) { CloseHandle(in); logmsg("payload copy failed"); return 0; }
        CloseHandle(in);
        logmsg("payload extracted (NBP1)");
        return 1;
    }

    if (memcmp(footer, "NBP2", 4) == 0) {
        // footer 尾部 20 字节: "NBP2" + count + off + len（表在 len 处）
        unsigned int count = 0;
        unsigned long long tblOff = 0, tblLen = 0;
        memcpy(&count, footer + 4, 4);
        memcpy(&tblOff, footer + 8, 8);
        memcpy(&tblLen, footer + 16, 4);
        if (count == 0 || count > MAX_TARGETS || tblLen != count * 24ULL
            || tblOff + tblLen > (unsigned long long)sz.QuadPart) {
            CloseHandle(in); logmsg("bad NBP2 table"); return 0;
        }
        unsigned char tbl[24 * MAX_TARGETS];
        pos.QuadPart = (LONGLONG)tblOff;
        if (!SetFilePointerEx(in, pos, NULL, FILE_BEGIN)) { CloseHandle(in); return 0; }
        if (!ReadFile(in, tbl, (DWORD)tblLen, &rd, NULL) || rd != (DWORD)tblLen) { CloseHandle(in); return 0; }

        int okAll = 0;
        for (unsigned int k = 0; k < count; ++k) {
            unsigned long long size = 0, off = 0, len = 0;
            memcpy(&size, tbl + k * 24, 8);
            memcpy(&off, tbl + k * 24 + 8, 8);
            memcpy(&len, tbl + k * 24 + 16, 8);
            if (len == 0 || off + len > (unsigned long long)sz.QuadPart) continue;
            if (extract_one(in, size, off, len)) okAll++;
        }
        CloseHandle(in);
        char msg[64];
        wsprintfA(msg, "payload extracted (NBP2): %d", okAll);
        logmsg(msg);
        return okAll > 0;
    }

    CloseHandle(in);
    logmsg("no payload footer");
    return 0;
}

// ------------------------------------------------------------------ 系统 hid.dll 转发
static void load_system_hid(void)
{
    wchar_t sys[MAX_PATH];
    UINT n = GetSystemDirectoryW(sys, MAX_PATH);
    if (!n || n >= MAX_PATH) { logmsg("GetSystemDirectory failed"); return; }
    wcscat_s(sys, MAX_PATH, L"\\hid.dll");
    HMODULE h = LoadLibraryW(sys);
    if (!h) { logmsg("LoadLibrary system hid failed"); return; }
    int ok = 0;
    for (int i = 0; i < EXPORT_COUNT; ++i) {
        g_targets[i] = (void*)GetProcAddress(h, g_names[i]);
        if (g_targets[i]) ok++;
    }
    char msg[64];
    wsprintfA(msg, "system hid targets: %d/%d", ok, EXPORT_COUNT);
    logmsg(msg);
}

// ------------------------------------------------------------------ 拦截
static const wchar_t* match_target(unsigned long long size)
{
    for (int i = 0; i < g_tblCount; ++i) {
        if (g_tbl[i].size == size) return g_tbl[i].path;
    }
    return NULL;
}

static const wchar_t* should_redirect(LPCWSTR path, DWORD access, DWORD disp)
{
    if (!path || !path[0] || g_tblCount == 0) return NULL;
    if (access & (GENERIC_WRITE | GENERIC_ALL)) return NULL;
    if (disp != OPEN_EXISTING) return NULL;
    if (starts_with_ci(path, g_tempDir)) return NULL;
    if (!contains_ci(path, L"com.unity.addressables")) return NULL;
    if (!contains_ci(path, L"__data")) return NULL;

    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (!GetFileAttributesExW(path, GetFileExInfoStandard, &fad)) return NULL;
    unsigned long long size = ((unsigned long long)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
    return match_target(size);
}

static HANDLE WINAPI hook_CreateFileW(LPCWSTR path, DWORD access, DWORD share,
                                      LPSECURITY_ATTRIBUTES sa, DWORD disp,
                                      DWORD flags, HANDLE tmpl)
{
    if (g_hooked) {
        const wchar_t* repl = should_redirect(path, access, disp);
        if (repl) {
            logmsg("redirect __data");
            return g_realCreateFileW(repl, access, share, sa, disp, flags, tmpl);
        }
    }
    return g_realCreateFileW(path, access, share, sa, disp, flags, tmpl);
}

static DWORD WINAPI init_thread(LPVOID param)
{
    (void)param;
    if (InterlockedCompareExchange(&g_off, 1, 0) == 0) {
        char env[32];
        DWORD n = GetEnvironmentVariableA("NOBOT_OFF", env, sizeof(env));
        if (n > 0 && !(n == 1 && env[0] == '0')) {
            logmsg("NOBOT_OFF set, skip");
            return 0;
        }
        n = GetEnvironmentVariableA("NOBOT_TARGET_SIZE", env, sizeof(env));
        if (n > 0) {
            unsigned long long v = 0;
            for (DWORD i = 0; i < n && is_digit((wchar_t)env[i]); ++i) v = v * 10 + (env[i] - '0');
            if (v > 0) g_targetSize = v;
        }
    }

    if (!extract_payloads()) { logmsg("init: extract failed"); return 0; }

    if (MH_Initialize() != MH_OK) { logmsg("MinHook init failed"); return 0; }
    HMODULE k32 = GetModuleHandleW(L"kernel32.dll");
    void* target = (void*)GetProcAddress(k32, "CreateFileW");
    if (!target) { logmsg("CreateFileW not found"); return 0; }
    if (MH_CreateHook(target, (void*)&hook_CreateFileW, (void**)&g_realCreateFileW) != MH_OK) {
        logmsg("MH_CreateHook failed"); return 0;
    }
    if (MH_EnableHook(target) != MH_OK) { logmsg("MH_EnableHook failed"); return 0; }

    InterlockedExchange(&g_hooked, 1);
    logmsg("hook installed");
    return 0;
}

// ------------------------------------------------------------------ DllMain
BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = inst;
        DisableThreadLibraryCalls(inst);
        init_paths();
        load_system_hid();
        HANDLE t = CreateThread(NULL, 0, init_thread, NULL, 0, NULL);
        if (t) CloseHandle(t);
    } else if (reason == DLL_PROCESS_DETACH) {
        if (g_hooked) {
            MH_DisableHook(MH_ALL_HOOKS);
            MH_Uninitialize();
        }
        for (int i = 0; i < g_tblCount; ++i) {
            if (g_tbl[i].path[0]) DeleteFileW(g_tbl[i].path);
        }
        if (g_tempDir[0]) RemoveDirectoryW(g_tempDir);
    }
    return TRUE;
}
