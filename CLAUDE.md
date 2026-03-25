# DelayNoMore — Smart Desktop Pet

A macOS desktop pet app that keeps you company while coding and reminds you to take breaks.

## Tech Stack

- **Framework**: Tauri v2 (Rust backend + Web frontend)
- **Frontend**: Vanilla HTML/CSS/JS, SVG cat with CSS animations
- **Backend**: Rust — timer engine, state machine, LLM client, SQLite stats
- **Package Manager**: pnpm

## Project Structure

```
src/                    # Web frontend
├── main.js             # Entry + Tauri event routing
├── pet.js              # SVG cat rendering + drag + animation
├── bubble.js           # Reminder bubble + eye rest
├── onboarding.js       # First-run naming flow
└── style.css           # All styles + CSS animations

src-tauri/src/          # Rust backend
├── lib.rs              # App setup, plugin registration
├── timer.rs            # Timer engine (core orchestrator)
├── state_machine.rs    # Mood (Happy/Normal/Sad) + affinity stages
├── llm.rs              # Claude/OpenAI API + cache + fallback messages
├── stats.rs            # SQLite stats store + LLM cache
├── config.rs           # JSON config persistence
├── tray.rs             # System tray menu
├── commands.rs         # Tauri invoke command handlers
└── idle.rs             # macOS CGEventSource idle detection
```

## Development

```bash
pnpm install
pnpm tauri dev          # Run in dev mode
cd src-tauri && cargo test  # Run Rust unit tests
```

## Architecture

- **Timer** is the central orchestrator — ticks every 10s (3s during rest)
- **Rust → Web**: events via `app.emit("pet:*")` → frontend `listen()`
- **Web → Rust**: commands via `invoke("command_name")`
- **Idle detection**: `CGEventSourceSecondsSinceLastEventType()` — no permissions needed
- **LLM**: prefetched at 40min, displayed at 45min; falls back to 23 preset messages
