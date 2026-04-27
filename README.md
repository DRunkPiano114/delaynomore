# DelayNoMore

DelayNoMore is a minimal native macOS break reminder. It runs from the menu bar, counts down a work period, then shows a strong centered image reminder for the full break period.

## Development

```bash
swift build
swift test
swift run DelayNoMore
```

To package a local `.app` bundle:

```bash
./scripts/build-app.sh
open .build/app/DelayNoMore.app
```

## Behavior

- Work duration defaults to 25 minutes.
- Break duration defaults to 5 minutes.
- The reminder image window is borderless, focused, always on top, and uses 55% of the active screen's visible width and height.
- The reminder image fades in at the center of the active screen.
- Choose `Skip Break` from the menu bar to end the current break early.
- After each break ends, the app returns to idle instead of starting another work cycle automatically.
