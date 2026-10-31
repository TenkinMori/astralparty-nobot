// 本地自测：验证 CreateFileW 重定向是否生效
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>

static void make_dir(const wchar_t* path)
{
    wchar_t tmp[1024];
    wcscpy_s(tmp, 1024, path);
    for (wchar_t* p = tmp + 3; *p; ++p) {
        if (*p == L'\\') { *p = 0; CreateDirectoryW(tmp, NULL); *p = L'\\'; }
    }
    CreateDirectoryW(tmp, NULL);
}

int main(void)
{
    wchar_t dll[MAX_PATH];
    GetCurrentDirectoryW(MAX_PATH, dll);
    wcscat_s(dll, MAX_PATH, L"\\hid.dll");

    SetEnvironmentVariableW(L"NOBOT_TARGET_SIZE", L"4096");
    HMODULE h = LoadLibraryW(dll);
    printf("LoadLibrary: %p\n", (void*)h);
    Sleep(1500);

    wchar_t tmp[MAX_PATH];
    GetTempPathW(MAX_PATH, tmp);
    wchar_t dir[MAX_PATH];

    // 1) 命中：路径含 com.unity.addressables，size == 4096
    wsprintfW(dir, L"%snbottest\\com.unity.addressables\\AssetBundles\\a\\b", tmp);
    make_dir(dir);
    wchar_t hit[MAX_PATH];
    wsprintfW(hit, L"%s\\__data", dir);
    HANDLE hw = CreateFileW(hit, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    char vanilla[4096];
    memset(vanilla, 'V', sizeof(vanilla));
    DWORD w = 0;
    WriteFile(hw, vanilla, sizeof(vanilla), &w, NULL);
    CloseHandle(hw);

    HANDLE hr = CreateFileW(hit, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    char head[8] = { 0 };
    DWORD r = 0;
    ReadFile(hr, head, 7, &r, NULL);
    printf("hit  first7 = '%s'  (expect 'UnityFS')  %s\n", head,
           (r == 7 && memcmp(head, "UnityFS", 7) == 0) ? "PASS" : "FAIL");
    CloseHandle(hr);

    // 2) 不命中：size != 4096
    wchar_t miss[MAX_PATH];
    wsprintfW(miss, L"%s\\__data2", dir);
    HANDLE hm = CreateFileW(miss, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    char small[64];
    memset(small, 'O', sizeof(small));
    WriteFile(hm, small, sizeof(small), &w, NULL);
    CloseHandle(hm);
    HANDLE hr2 = CreateFileW(miss, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    ReadFile(hr2, head, 7, &r, NULL);
    printf("miss first7 = '%s'  (expect 'OOOOOOO')  %s\n", head,
           (r == 7 && memcmp(head, "OOOOOOO", 7) == 0) ? "PASS" : "FAIL");
    CloseHandle(hr2);

    return 0;
}
