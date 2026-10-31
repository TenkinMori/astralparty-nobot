# TenkinMori - NoBot

开房间不补 Bot，点「开始」直接开局。

## 安装

双击 `安装.bat`，选 `1. 安装`。

装完启动游戏 -> 创建房间 -> 点「开始」-> 直接开局。

## 还原

双击 `安装.bat`，选 `2. 还原`。

## 内容

| 文件 | 说明 |
|---|---|
| hid.dll | 注入代理 |
| hid_orig.dll | 原版 hid.dll 副本 |
| AstralPartyExtra\hotfix__data | 打好的补丁包 |

注：AstralPartyExtra 这个文件夹名是 hid.dll 固定要找的路径，请不要改名。

## 原理

把游戏补丁包里的两处常量从 true 改成 false：

```
UI.RoomWaitPanel.<RequsetStart>b__16_0   ldc.i4.1 -> ldc.i4.0
UI.RoomWaitPanel.<RequsetStart>b__16_1   ldc.i4.1 -> ldc.i4.0
```

这两个是「补 Bot 开局」和「不补 Bot 开局」两个按钮的处理函数。
改成 false 后都走「不补 Bot」分支。

不改窗口标题、不改界面、不影响其他功能。

## 已知限制

- 游戏大版本更新后，补丁包可能失效，需等作者更新
- 不要和其他修改补丁包的插件同时使用