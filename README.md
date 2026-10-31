# 吉星派对 · NoBot（开房不补 Bot）

> 《吉星派对》（Steam：AstralParty）的**独立小插件**：创建房间后点「开始」直接开局，不再弹「是否补充 Bot」。
>
> 只改客户端补丁包里的两处常量，不改界面、不改窗口标题、不碰服务端。

---

## 两种形态

| 形态 | 位置 | 说明 |
|---|---|---|
| **独立版**（本仓库 `dist/`） | 丢 `hid.dll` 进游戏目录 | 不依赖 PatchManager / CesiumLoader，装完即用 |
| CesiumLoader mod 版 | —（暂时不可用） | 已在 2026-10-31 从 APA 仓库移除，等加载器可用再恢复 |

两者**不要同时装**，装一个即可。

---

## 安装

1. 完全退出游戏
2. 把 `dist/` 里的文件复制到游戏根目录（`AstralParty_CN.exe` 所在目录）：
   ```
   hid.dll
   hid_orig.dll
   AstralPartyExtra\hotfix__data
   安装.bat
   install.ps1
   ```
3. 双击 **`安装.bat`** → 选 **`1. 安装`**
4. 启动游戏 → 创建房间 → 点「开始」→ 直接开局

**还原**：双击 `安装.bat` → 选 `2. 还原`（会还原补丁包并移除 hid.dll）。

> `AstralPartyExtra` 这个文件夹名是 hid.dll 固定要找的路径，**不要改名**。

---

## 原理

只改补丁包里的两个常量：

```
UI.RoomWaitPanel.<RequsetStart>b__16_0   ldc.i4.1 → ldc.i4.0
UI.RoomWaitPanel.<RequsetStart>b__16_1   ldc.i4.1 → ldc.i4.0
```

这两个分别是「补 Bot 开局」和「不补 Bot 开局」两个按钮的处理函数，改成 false 后都走「不补 Bot」分支。

---

## 目录结构

```
astralparty-nobot\
├─ src\         探针源码（Probe.cs，扫描程序集定位调用点）
├─ build\       构建与安装脚本（build.py / pack_bundle.py / install-nobot.ps1 / 启动.bat）
├─ dist\        ★ 可直接分发的成品（hid.dll / hid_orig.dll / hotfix__data / 安装.bat）
├─ README.md
└─ STATUS.md
```

---

## 构建（开发者）

```powershell
# 1) 探针会扫描参考 DLL，定位 RequestStartGameC2S 的调用点
python build\build.py

# 2) 打补丁包（内部调用 dllpatch）
python build\build.py --out dist\AstralPartyExtra\hotfix__data
```

> 构建依赖旧 Extra 工具链的 `dllpatch`（见 `build\build.py` 顶部路径常量）；
> 也可以直接用 `dist\` 里的现成产物。

---

## 已知限制

- 游戏大版本更新后补丁包会失效，需要重新构建
- **不要和其他修改补丁包的插件同时使用**（会互相覆盖）；要合并请用 PatchManager
- 只影响本机，服务端行为不变

---

## 版本

| 版本 | 日期 | 说明 |
|---|---|---|
| v1.0 | 2026-10-30 | 独立版首个版本（hid.dll 代理） |

---

## 免责声明

仅供个人学习与交流，请勿用于商业用途或破坏他人游戏体验。

---

*最后更新：2026-10-31*
