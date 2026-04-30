# DelayNoMore

[中文说明](README.zh.md)

A minimal native macOS break reminder. Runs from the menu bar, counts down a work period, then takes over your screen with a looping video or picture reminder for the entire break.

## Why DelayNoMore

- **Native and lightweight** — built in Swift. ~11 MB on disk and ~40 MB of memory at runtime.
- **Video takeover, not a black screen** — It plays a calming video that makes you *want* to take a break.
- **Works out of the box** — several built-in video reminders included. No setup, no configuration required.
- **Bring your own** — drop in any image or video as your reminder. Personal media often pulls you out of work better than stock clips.
- **Simple on purpose** — one job, done well. No micro-breaks, no stats dashboards, no notification spam.

## Install

Download the latest `DelayNoMore.zip` from [Releases](https://github.com/DRunkPiano114/delaynomore/releases), unzip, and drag `DelayNoMore.app` to your Applications folder.

The app is signed with an Apple Developer ID and notarized by Apple, so it opens like any other Mac app — no Terminal commands required. Once installed, DelayNoMore checks for new versions automatically and updates in place.

## Features

- Menu bar app with work/break countdown timer
- 6 built-in video reminders (cats, fireplace, rain, and more)
- Custom image or video reminders
- Hover-to-preview videos in settings
- Configurable work and break durations, with optional auto-repeat
- Automatic in-app updates

## Build from source

Requires macOS 13+ and Swift 5.9+.

```bash
./scripts/build-app.sh
open .build/app/DelayNoMore.app
```

## Development


| Command                  | What it does                                            |
| ------------------------ | ------------------------------------------------------- |
| `swift test`             | Run unit tests                                          |
| `./scripts/dev.sh`       | Kill any running instance, rebuild, and launch the .app |
| `./scripts/check.sh`     | Tests + .app bundle structure check (run before commit) |
| `./scripts/build-app.sh` | Just build the .app bundle                              |


## License

[MIT](LICENSE)