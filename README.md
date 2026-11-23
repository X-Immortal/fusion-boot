# GPT 龙娘融合启动器

为 Windows 上的 Codex Dream Skin 串起两段龙娘开场动画。第一段保留原音轨，在 12.7 秒处渐入第二段。第二段循环播放待机动画，等 Dream Skin 主题就绪后播放收尾动画，将画面交给 Codex 窗口。播放时按 Esc 可以跳过动画。

## 构建和运行

需要 Windows 10/11 x64、Windows PowerShell 5.1、.NET Framework 4.8 和系统媒体组件。日常启动使用当前用户安装的 Codex 桌面端和 [Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin)。请先通过 Dream Skin 应用主题。

在仓库根目录运行：

```powershell
.\init.ps1
.\release-final\Start-Codex-Fusion.exe
```

初始化脚本从上游下载首段视频和社区版 R16 完整包，共约 375 MiB，校验 SHA-256 后提取所需素材并编译。生成的配置使用当前用户的 Dream Skin 安装路径。每次构建需要一个新目录；已有运行目录时，可用 `.\init.ps1 -OutputDirectory .\new-release` 指定其他位置。

- **只看动画**：运行 `.\release-final\Start-Codex-Fusion.exe --preview`。
- **创建桌面入口**：默认目录构建完成后，运行 `.\Create-Fusion-Shortcut.ps1`。
- **查看启动日志**：打开运行目录中的 `output\handoff-latest.log`。

## 来源与许可

| 内容 | 来源与许可说明 |
| --- | --- |
| 首段视频及原音轨 | 取自 [Dragon Codex Boot](https://github.com/yushua0808-cpu/dragon-codex-boot/tree/c63a203e5857e85fb3c8a9891eddb570e7a27b54)。该项目的程序代码使用 [MIT 许可](FIRST-LAUNCHER-LICENSE.txt)。视频、角色、音轨和标志分别适用原提供者的许可，构建产物保留[视频说明](media/MEDIA_NOTICE.md)和[第三方说明](FIRST-LAUNCHER-THIRD-PARTY-NOTICES.md)。 |
| 启动器主体、第二段动画和角色素材 | 原项目为 [mytjxs/codex-startup-animation](https://github.com/mytjxs/codex-startup-animation)。源码基于 [HanwenZhang-George 的社区版](https://github.com/HanwenZhang-George/codex-startup-animation/tree/1f799814af52c14c8a6a000bee60f1fb238e55dc/community-v34)，素材取自 [R16 Release](https://github.com/HanwenZhang-George/codex-startup-animation/releases/tag/community-v34-r5)。上游公开文档未列出允许独立再分发修改版源码、程序和媒体的通用许可证。 |
| 字体和图标 | 霞鹜文楷 TC 使用 [SIL Open Font License 1.1](source/FONT-LICENSE.txt)。启动器使用社区包附带的 Codex 图标，相关标志归各自权利人所有。 |

融合版增加了双段动画过渡、Dream Skin 启动与主题就绪检测、窗口交接和本地构建脚本。源码、测试和打包工具位于 [source/](source/)；社区版的版本沿革见[来源记录](source/SOURCE-PROVENANCE.txt)。
