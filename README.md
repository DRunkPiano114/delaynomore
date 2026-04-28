# DelayNoMore

[中文说明](README.zh.md)

A minimal native macOS break reminder. Runs from the menu bar, counts down a work period, then takes over your screen with a looping video reminder for the entire break.

Most break reminders show a notification you dismiss in one second. DelayNoMore doesn't let you do that — it fills your screen so you actually rest.

## Why DelayNoMore

- **Native and lightweight** — built in Swift, not Electron. Uses barely any memory compared to alternatives like Stretchly (~150MB) or Break Timer.
- **Video takeover, not a black screen** — instead of dimming your display or showing text, it plays a calming video that makes you *want* to take a break.
- **Works out of the box** — 7 built-in video reminders included. No setup, no configuration required.
- **Simple on purpose** — one job, done well. No micro-breaks, no stats dashboards, no notification spam.

## Install

Download the latest `DelayNoMore.zip` from [Releases](https://github.com/DRunkPiano114/delaynomore/releases), unzip, and drag `DelayNoMore.app` to your Applications folder.

Since the app is not signed with an Apple Developer ID, macOS will block it on first launch.

If you see **"DelayNoMore is damaged and can't be opened"**, run this in Terminal:

```bash
xattr -d com.apple.quarantine /Applications/DelayNoMore.app
```

This removes the macOS quarantine attribute that gets added to files downloaded from the internet. It does not modify the app itself.

Then open the app normally. You only need to do this once.

## Features

- Menu bar app with work/break countdown timer
- 7 built-in video reminders (cats, fireplace, rain, and more)
- Custom image or video reminders
- Hover-to-preview videos in settings
- Configurable work and break durations

## Build from source

Requires macOS 13+ and Swift 5.9+.

```bash
./scripts/build-app.sh
open .build/app/DelayNoMore.app
```

Or run directly without packaging:

```bash
swift run DelayNoMore
```

## Development

| Command | What it does |
|---|---|
| `swift test` | Run unit tests |
| `./scripts/dev.sh` | Kill any running instance, rebuild, and launch the .app |
| `./scripts/check.sh` | Tests + .app bundle structure check (run before commit) |
| `./scripts/build-app.sh` | Just build the .app bundle |

## License

[MIT](LICENSE)
