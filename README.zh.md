# DelayNoMore

一个简洁的 macOS 原生休息提醒工具。在菜单栏运行，倒计时工作时间，然后用循环视频或图片霸占你的屏幕，强制你休息。

<video src="https://github.com/DRunkPiano114/delaynomore/raw/main/docs/demo.mp4" controls muted playsinline width="100%"></video>

## 为什么选 DelayNoMore

- **原生轻量** — 纯 Swift 构建。安装后约 11 MB，运行内存约 40 MB。
- **视频霸屏，不是黑屏** — 播放舒缓的视频，让你愿意放下工作。
- **开箱即用** — 内置多个视频提醒，不需要任何配置。
- **自定义提醒** — 任意图片或视频都能用作提醒。
- **只做一件事** — 没有微休息、没有统计面板、没有通知轰炸。简单，好用。

## 安装

从 [Releases](https://github.com/DRunkPiano114/delaynomore/releases) 下载最新的 `DelayNoMore.zip`，解压后将 `DelayNoMore.app` 拖入"应用程序"文件夹。

应用已用 Apple Developer ID 签名并通过 Apple 公证，可以像普通 Mac 应用一样直接打开，无需任何终端命令。安装后会自动检查更新并在后台升级。

## 功能

- 菜单栏应用，显示工作/休息倒计时
- 6 个内置视频提醒（猫咪、壁炉、雨声等）
- 支持自定义图片或视频提醒
- 设置中悬停预览视频
- 可自定义工作和休息时长，可选自动重复
- 应用内自动更新

## 从源码构建

需要 macOS 13+ 和 Swift 5.9+。

```bash
./scripts/build-app.sh
open .build/app/DelayNoMore.app
```

## 开发


| 命令                     | 作用                                    |
| ------------------------ | --------------------------------------- |
| `swift test`             | 跑单元测试                              |
| `./scripts/dev.sh`       | 杀掉运行中的实例，重新构建并启动 .app   |
| `./scripts/check.sh`     | 单元测试 + .app bundle 结构检查（提交前跑） |
| `./scripts/build-app.sh` | 只构建 .app bundle                      |


## 许可证

[MIT](LICENSE)
