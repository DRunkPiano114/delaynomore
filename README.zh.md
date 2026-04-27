# DelayNoMore

一个简洁的 macOS 原生休息提醒工具。在菜单栏运行，倒计时工作时间，然后全屏播放媒体提醒你休息。

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
