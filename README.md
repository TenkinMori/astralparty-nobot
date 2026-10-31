# 吉星派对 · NoBot（开房不补 Bot）

> 《吉星派对》（Steam：AstralParty）的**独立小插件**。
> 创建房间后点「开始」直接开局，不再弹「是否补充 Bot」。
>
> 只改本机补丁包里的两处常量：不碰服务端、不改界面、不改窗口标题。

---

## 功能

| 功能 | 说明 |
|---|---|
| 跳过补 Bot 确认 | 点「开始」直接进入对局，不再询问是否补机器人 |
| 两个开局按钮统一 | 「补 Bot 开局」和「不补 Bot 开局」都走不补 Bot 分支 |
| 可随时还原 | 安装脚本自带还原，恢复游戏原样 |

---

## 版本与下载

| 版本 | 日期 | 说明 |
|---|---|---|
| v1.0 | 2026-10-30 | 首个独立版（hid.dll 代理 + 补丁包） |

- 成品：本仓库 `dist/` 目录，或 **GitHub Releases** 里的 `NoBot-v1.0.zip`
- 适用：官服客户端 3.3.0（2026-10-30 构建）

---

## 安装

**准备工作**：完全退出游戏（任务管理器里确认 `AstralParty_CN.exe` 已结束）。

1. 解压 `NoBot-v1.0.zip`（或本仓库 `dist/`）到**游戏根目录**，即 `AstralParty_CN.exe` 所在目录。
   解压后应得到：

   ```
   游戏根目录\
   ├─ AstralParty_CN.exe
   ├─ hid.dll
   ├─ hid_orig.dll
   ├─ 安装.bat
   ├─ install.ps1
   └─ AstralPartyExtra\
      └─ hotfix__data
   ```

2. 双击 **`安装.bat`** → 输入 **`1`** 回车（安装）。
3. 启动游戏 → 创建房间 → 点「开始」→ 直接开局。

> `AstralPartyExtra` 文件夹名是 `hid.dll` 固定要找的路径，**不要改名**。

**验证是否生效**：

- 安装脚本会打印「原版 / 补丁版」的大小和 SHA256
- 也可以看 `AstralPartyExtra\hotfix__data` 的大小是否变成补丁版（约 7.9MB）

---

## 还原

双击 `安装.bat` → 输入 **`2`** 回车（还原）。

还原会：

1. 把补丁包换回原版（备份在 `__data.apa-orig`）
2. 移除 `hid.dll`（保留 `hid_orig.dll`）

> 只删 `hid.dll` 不够——安装时补丁已写进游戏缓存，必须用还原功能一起处理。

---

## 原理

只改补丁包里的两个常量：

```
UI.RoomWaitPanel.<RequsetStart>b__16_0   ldc.i4.1 → ldc.i4.0
UI.RoomWaitPanel.<RequsetStart>b__16_1   ldc.i4.1 → ldc.i4.0
```

这两个分别是「补 Bot 开局」和「不补 Bot 开局」两个按钮的处理函数。
把 `true` 改成 `false` 后，两个按钮都走「不补 Bot」分支。

**加载方式**：`hid.dll` 是代理 DLL，`UnityPlayer.dll` 会优先加载它。
它在启动时把 `AstralPartyExtra\hotfix__data` 写进游戏的 Addressables 缓存，
其余 HID 导出原样转发给 `hid_orig.dll`，所以不影响手柄/键鼠。

---

## 目录结构

```
astralparty-nobot\
├─ src\      探针源码（Probe.cs：扫描程序集定位两处调用点）
├─ build\    构建与安装脚本（build.py / pack_bundle.py / install-nobot.ps1 / 启动.bat）
└─ dist\     ★ 可直接分发的成品（hid.dll / hid_orig.dll / hotfix__data / 安装.bat / install.ps1）
```

---

## 从源码构建

**依赖**

| 组件 | 要求 |
|---|---|
| 系统 | Windows 10 / 11 x64 |
| .NET SDK | 9.0（编译探针 Probe） |
| Python | 3.13 |
| 参考 DLL | `AstralParty.Runtime.dll`（从游戏客户端取，或用现成的 `work\live_refs`） |
| 打补丁工具 | `dllpatch`（见 `build\build.py` 顶部路径常量） |

**步骤**

```powershell
# 1) 探针扫描参考 DLL，定位 RequestStartGameC2S 的调用点
python build\build.py

# 2) 打补丁包（内部调用 dllpatch）
python build\build.py --out dist\AstralPartyExtra\hotfix__data
```

> 游戏更新后必须重新执行：常量位置可能变化，旧补丁包会失效。

---

## 常见问题

| 现象 | 处理 |
|---|---|
| 装了没效果，还是弹「补充 Bot」 | ① 确认游戏完全退出后再装；② 装完看 `hotfix__data` 大小是否变化；③ 菜单选 3 查看状态 |
| 游戏起不来 / 闪退 | 双击 `安装.bat` 选 2 还原；确认 `hid_orig.dll` 和 `hid.dll` 在同一目录 |
| 游戏更新后失效 | 补丁包会失效，需要重新构建（见上一节） |
| 和其他插件冲突 | 不要同时装两个都改补丁包的插件；要合并请用统一的补丁管理器 |
| 杀毒软件报毒 | `hid.dll` 是代理注入类文件，可能被误报；可加白名单 |
| 想确认装的是哪版 | 看 `AstralPartyExtra\hotfix__data` 大小 / SHA256，或运行安装脚本看状态 |

---

## 兼容性

- 只支持 Windows 官服客户端（Steam / 官方启动器）
- 当前补丁基于 **3.3.0** 客户端构建，其他版本可能无效
- 只影响本机表现，服务端与房间逻辑不变

---

## 更新日志

| 日期 | 版本 | 内容 |
|---|---|---|
| 2026-10-30 | v1.0 | 首个独立版：hid.dll 代理 + 补丁包 + 安装/还原脚本 |

---

## 免责声明

仅供个人学习与交流，请勿用于商业用途或破坏他人游戏体验。
使用第三方补丁存在账号与稳定性风险，请自行评估。
