# 交接说明（STATUS）

> 给下一次对话/接手的人：先读 `README.md`，再读本文件。

## 项目一句话

**NoBot 独立版**：开房间不补 Bot，点「开始」直接开局。
`dist/` 是可直接分发的成品；`src/` + `build/` 是构建链。

## 仓库与本地

| 仓库路径 | 本地原目录 |
|---|---|
| `src/` | `<本地项目目录>\NoBotStarter\src` |
| `build/` | `...\AstralPartyAdditional\NoBotStarter`（build.py、pack_bundle.py、install-nobot.ps1 等） |
| `dist/` | `...\AstralPartyAdditional\NoBotStarter_hid` |

> 本仓库是整理后的**源码快照 + 成品**，只保留最新 v1.0。

## 当前状态（2026-10-31）

- ✅ 独立版可用：`dist\安装.bat` 选 1 安装、选 2 还原
- ✅ 补丁包已打好（`dist\AstralPartyExtra\hotfix__data`，7.94MB）
- ✅ 探针源码（`src\Probe.cs`）可重新定位调用点（游戏更新后用）
- ⚠️ 构建依赖旧 Extra 的 `dllpatch`（路径写死在 `build\build.py`）

## 安装 / 还原

1. 关游戏
2. 把 `dist\` 内容复制到游戏根目录
3. 双击 `安装.bat` → 1 安装 / 2 还原

## 重新构建（游戏更新后）

1. 更新参考 DLL（`work\live_refs\AstralParty.Runtime.dll`）
2. `python build\build.py` 重新定位并打补丁
3. 覆盖 `dist\AstralPartyExtra\hotfix__data`

## 已知问题 / 待办

- [ ] `build.py` 里的 `dllpatch`/参考 DLL 路径写死，换机器要改
- [ ] 游戏更新后需重新构建（补丁常量位置可能变）
- [ ] 与 PatchManager 版 NoBot（APA 仓库 `src/nobot`）二选一，别同时装

## 给新会话的流程

1. 读 `README.md` → 本文件
2. 要发玩家：直接把 `dist\` 打包
3. 要改功能：改 `src\` / `build\`，重新构建后同步
