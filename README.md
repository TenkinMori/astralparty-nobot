# 吉星派对 · NoBot

> 《吉星派对》（Steam：AstralParty）的客户端小补丁：**一个 `hid.dll`**，放进游戏根目录就生效，删掉就失效。
> 开房后点「开始」直接开局，不再弹「是否补充 Bot」。

---

## 特点

| 特点 | 说明 |
|---|---|
| **只用一个 DLL** | 只有一个 `hid.dll`（约 8MB，补丁包内嵌） |
| **不落盘** | 不写游戏目录、不写 Addressables 缓存，退出即清理临时文件 |
| **删除即卸载** | 删掉 `hid.dll` 就完全恢复原版，不需要还原工具 |
| **只影响本机** | 不改服务端、不改窗口标题、不改界面 |

---

## 安装

1. 完全退出游戏（任务管理器确认 `AstralParty_CN.exe` 已结束）
2. 把 `dist\hid.dll` 复制到**游戏根目录**（`AstralParty_CN.exe` 所在目录）
3. 启动游戏 → 创建房间 → 点「开始」→ 直接开局

**卸载**：关闭游戏，删除游戏根目录的 `hid.dll` 即可。

---

## 验证是否生效

看 `%TEMP%\nobot.log`：

- `hook installed` → 挂钩成功
- `redirect __data` → 游戏读取热更包时被重定向到补丁版

如果日志里是 `no payload footer` 或 `hook failed`，说明文件不完整或环境不符。

---

## 原理

1. `UnityPlayer.dll` 静态导入 `HID.DLL`，Windows 按「exe 所在目录优先」解析，所以根目录的 `hid.dll` 会被加载。
2. 本 DLL 把系统 `hid.dll` 的 **47 个导出**全部转发给 `C:\Windows\System32\hid.dll`（自己 `LoadLibrary` 绝对路径，不需要 `hid_orig.dll`）。
3. 启动时把**内嵌的补丁 bundle** 释放到 `%TEMP%\nobot-<pid>\__data`。
4. 用 MinHook 挂钩 `kernel32!CreateFileW`：当游戏**只读**打开 Addressables 里那颗**原版热更 `__data`**（按文件大小 `8,339,710` 识别）时，改成打开临时补丁文件。
5. 进程退出时删除临时文件。

> 因为补丁只在进程内生效，游戏缓存里始终是原版——删 DLL 就彻底失效。

---

## 兼容性

- 面向**官服 3.3.0 原版客户端**（原版热更包 = `8,339,710` 字节）
- 游戏更新后热更包大小会变，需要重新构建（见下）
- 仅 Windows x64

---

## 构建

依赖：

| 组件 | 要求 |
|---|---|
| Visual Studio 2022 | `cl.exe` / `ml64.exe`（C++ 桌面开发） |
| Python | 3.13（跑 `gen.py` 生成导出表/跳转 thunk） |
| MinHook | 已内置 `single/minhook` |

```powershell
powershell -NoProfile -File single\build.ps1 -Test
```

- 产物：`single\hid.dll`（未追加补丁前的 DLL 约 120KB，追加后约 8.4MB）
- `-Test` 会同时编译 `test.exe` 做本地重定向自测
- 默认补丁取自 `dist\hid.dll` 尾部内嵌数据；也可用 `-Payload <hotfix__data>` 指定新补丁

**游戏更新后**：

1. 用新客户端重新打补丁包（PatchManager 或 dllpatch）
2. 改 `single\nobot.c` 里的 `g_targetSize`（新原版热更包大小）
3. 重新构建，覆盖 `dist\hid.dll`

---

## 目录结构

```
astralparty-nobot\
├─ dist\hid.dll      ★ 成品（直接复制到游戏根目录）
└─ single\           源码（nobot.c / thunks.asm / exports.def / gen.py / build.ps1 / minhook）
```

---

## 常见问题

| 现象 | 处理 |
|---|---|
| 装了没效果 | 看 `%TEMP%\nobot.log`；确认游戏是 3.3.0 原版、`hid.dll` 在根目录 |
| 游戏起不来 / 闪退 | 删除 `hid.dll`；确认系统是 x64 |
| 游戏更新后失效 | 热更包大小变了，按「构建」重新生成 |
| 杀毒软件报毒 | 注入类 DLL 常被误报，可加白名单 |
| 和其他 mod 冲突 | 若其他 mod 直接替换热更包文件，本 DLL 的重定向会覆盖它的读取；二选一 |

---

## 免责声明

仅供个人学习与交流，请勿用于商业用途或破坏他人游戏体验。
使用第三方补丁存在账号与稳定性风险，请自行评估。
