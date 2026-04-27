# DelayNoMore

一个简洁的 macOS 原生休息提醒工具。在菜单栏运行，倒计时工作时间，然后用循环视频霸占你的屏幕，强制你休息。

大多数休息提醒弹个通知，你一秒就关掉了。DelayNoMore 不给你这个机会——直接全屏，让你真的去休息。

## 为什么选 DelayNoMore

- **原生轻量** — 纯 Swift 构建，不是 Electron。内存占用远低于 Stretchly（~150MB）等同类工具。
- **视频霸屏，不是黑屏** — 不只是把屏幕变暗或显示文字，而是播放舒缓的视频，让你愿意放下工作。
- **开箱即用** — 内置 7 个视频提醒，不需要任何配置。
- **只做一件事** — 没有微休息、没有统计面板、没有通知轰炸。简单，好用。

## 安装

从 [Releases](https://github.com/DRunkPiano114/delaynomore/releases) 下载最新的 `DelayNoMore.zip`，解压后将 `DelayNoMore.app` 拖入"应用程序"文件夹。

由于应用未经 Apple 开发者签名，macOS 会在首次启动时阻止打开。

如果看到 **"DelayNoMore 已损坏，无法打开"**，在终端中运行：

```bash
xattr -d com.apple.quarantine /Applications/DelayNoMore.app
```

这条命令会移除 macOS 给从网上下载的文件添加的隔离标记，不会修改应用本身。

之后正常打开即可，只需执行一次。

## 功能

- 菜单栏应用，显示工作/休息倒计时
- 7 个内置视频提醒（猫咪、壁炉、雨声等）
- 支持自定义图片或视频提醒
- 设置中悬停预览视频
- 可自定义工作和休息时长

## 从源码构建

需要 macOS 13+ 和 Swift 5.9+。

```bash
./scripts/build-app.sh
open .build/app/DelayNoMore.app
```

或直接运行（不打包）：

```bash
swift run DelayNoMore
```

## 许可证

[MIT](LICENSE)
