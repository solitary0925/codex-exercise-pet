# 伸展兔 · Codex Exercise Pet

A Windows desktop pet that appears while a Codex shell command is still running and offers a 30-second stretch.

当 Codex 的命令持续约 20 秒，伸展兔会从桌面角落弹出。按住兔子或卡片标题即可拖动。点击「开始」查看肩背伸展动作和 30 秒倒计时，命令会继续运行。

## 安装

需要 Windows、Windows PowerShell 5.1 和带本地插件及 Hook 支持的 Codex 桌面端。使用本机 Windows 会话。

在 PowerShell 中添加插件来源：

```powershell
codex plugin marketplace add solitary0925/codex-exercise-pet
```

1. 重启 Codex，从「插件」的「本地运动提醒」来源安装「伸展兔」。
2. 打开「设置 → Hooks」，审核并信任伸展兔的四个 Hook。
3. 新开一个本地 Codex 会话。要暂停后续提醒，可在「插件 → 已安装 → 伸展兔」关闭插件。

也可以将此仓库克隆到本机，再把上述命令中的 GitHub 仓库名换成该目录的绝对路径。

## 试用

让 Codex 在本地运行 `Start-Sleep -Seconds 35` 并等命令结束。宠物应在约 20 秒时弹出。短命令结束后，Hook 会清除对应的计时标记。Codex 分段返回命令输出时，也可能要等到下一次轮询才上报结束。

宠物在后台运行时，可右键 Windows 通知区域图标选择「预览提醒」或退出。从源码独立预览可在仓库根目录执行：

```powershell
.\Start-Pet.cmd -Preview
```

独立预览使用仓库内的 `.runtime`，安装版使用 Codex 分配给插件的本地数据目录。

## 设置和本地数据

默认等待阈值为 20 秒，提醒间隔为 10 分钟。源码默认值在 `plugins/codex-exercise-pet/settings.json`。要覆盖安装版设置，请将该 JSON 复制到插件数据目录（Hook 环境中的 `PLUGIN_DATA`），修改 `longCommandSeconds` 或 `cooldownSeconds`，再从通知区域退出宠物。下一次命令会按新设置启动。

提醒代码只在本地保存由会话、轮次和工具调用标识生成的计时标记。脚本没有联网功能，也不会写入命令正文。
