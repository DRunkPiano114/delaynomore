use crate::config::ConfigManager;
use crate::idle;
use crate::state_machine::{get_random_message, StateMachine};
use crate::stats::StatsStore;
use crate::tray;
use std::sync::Arc;
use std::time::Instant;
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

pub struct TimerState {
    pub continuous_work_sec: u64,
    pub is_resting: bool,
    pub rest_start_time: Option<Instant>,
    pub ignore_count: u32,
    pub last_eye_rest: Instant,
    pub big_rest_triggered: bool,
    pub effective_interval_sec: u64,
}

impl TimerState {
    pub fn new(interval_min: u32) -> Self {
        Self {
            continuous_work_sec: 0,
            is_resting: false,
            rest_start_time: None,
            ignore_count: 0,
            last_eye_rest: Instant::now(),
            big_rest_triggered: false,
            effective_interval_sec: (interval_min as u64) * 60,
        }
    }
}

pub fn start_timer(
    app: AppHandle,
    timer: Arc<Mutex<TimerState>>,
    config: Arc<ConfigManager>,
    state_machine: Arc<Mutex<StateMachine>>,
    stats: Arc<StatsStore>,
) {
    tauri::async_runtime::spawn(async move {
        loop {
            let ts = timer.lock().await;
            let tick_secs = 1;
            let tray_work_sec = ts.continuous_work_sec;
            let tray_interval_sec = ts.effective_interval_sec;
            let tray_is_resting = ts.is_resting;
            drop(ts);

            // Update tray menu with current state
            {
                let sm = state_machine.lock().await;
                let mood = sm.mood;
                drop(sm);
                let rest_count = stats.get_today_stats().rest_count as u32;
                tray::update_tray(
                    &app,
                    &config,
                    mood,
                    tray_work_sec,
                    tray_interval_sec,
                    tray_is_resting,
                    rest_count,
                );
            }

            sleep(Duration::from_secs(tick_secs)).await;

            let idle_secs = idle::get_idle_seconds();
            let cfg = config.get();
            let mut ts = timer.lock().await;

            // === Resting state ===
            if ts.is_resting {
                let rest_threshold = cfg.rest_duration_min as f64 * 60.0;
                if idle_secs >= rest_threshold {
                    // Rest completed
                    ts.is_resting = false;
                    ts.rest_start_time = None;
                    ts.continuous_work_sec = 0;
                    ts.big_rest_triggered = false;
                    ts.ignore_count = 0;
                    ts.last_eye_rest = Instant::now();
                    drop(ts);

                    let mut sm = state_machine.lock().await;
                    sm.on_rest_completed();
                    let mood = sm.mood;
                    drop(sm);

                    stats.record_rest();

                    let _ = app.emit(
                        "timer:status",
                        serde_json::json!({
                            "workSec": 0,
                            "intervalSec": cfg.big_rest_interval_min as u64 * 60,
                            "isResting": false,
                        }),
                    );
                    let _ = app.emit("pet:welcome_back", ());
                    let _ = app.emit(
                        "pet:state_update",
                        serde_json::json!({"mood": format!("{:?}", mood)}),
                    );
                    let _ = app.emit("pet:walk_back", ());
                }
                continue;
            }

            // === Active state ===
            if idle_secs < 30.0 {
                ts.continuous_work_sec += tick_secs;
            }

            let work_min = ts.continuous_work_sec / 60;
            let work_sec = ts.continuous_work_sec;
            let interval_sec = ts.effective_interval_sec;

            // Emit status every tick so frontend can display progress
            let _ = app.emit(
                "timer:status",
                serde_json::json!({
                    "workSec": work_sec,
                    "intervalSec": interval_sec,
                    "isResting": false,
                }),
            );

            // Update mood
            {
                let mut sm = state_machine.lock().await;
                sm.on_work_duration(work_min);
            }

            // 20-20-20 eye rest
            let eye_interval = (cfg.eye_rest_interval_min as u64) * 60;
            if ts.last_eye_rest.elapsed().as_secs() >= eye_interval {
                ts.last_eye_rest = Instant::now();
                drop(ts);
                let _ = app.emit("pet:eye_rest", ());
                continue;
            }

            // Big rest reminder
            if ts.continuous_work_sec >= ts.effective_interval_sec && !ts.big_rest_triggered {
                ts.big_rest_triggered = true;
                let sm = state_machine.lock().await;
                let mood = sm.mood;
                drop(sm);

                let msg = get_random_message(mood);
                let work_dur = ts.continuous_work_sec;
                drop(ts);

                let _ = app.emit("pet:walk_to_center", ());
                let _ = app.emit(
                    "pet:show_bubble",
                    serde_json::json!({"message": msg, "workDuration": work_dur / 60}),
                );
                let _ = app.emit(
                    "pet:state_update",
                    serde_json::json!({"mood": format!("{:?}", mood)}),
                );

                stats.record_work_session(work_dur);
                continue;
            }

            drop(ts);
        }
    });
}

pub async fn handle_user_rest(
    timer: &Arc<Mutex<TimerState>>,
    state_machine: &Arc<Mutex<StateMachine>>,
    stats: &Arc<StatsStore>,
) {
    let mut ts = timer.lock().await;
    ts.is_resting = true;
    ts.rest_start_time = Some(Instant::now());
    ts.big_rest_triggered = false;
    drop(ts);

    let mut sm = state_machine.lock().await;
    sm.mood = crate::state_machine::Mood::Happy;
    sm.ignore_count = 0;
    drop(sm);

    stats.record_reminder_response(true);
}

pub async fn handle_user_snooze(
    timer: &Arc<Mutex<TimerState>>,
    config: &Arc<ConfigManager>,
    state_machine: &Arc<Mutex<StateMachine>>,
    stats: &Arc<StatsStore>,
) {
    let cfg = config.get();
    let mut ts = timer.lock().await;
    ts.big_rest_triggered = false;
    ts.continuous_work_sec = ts
        .effective_interval_sec
        .saturating_sub(cfg.snooze_duration_min as u64 * 60);
    ts.ignore_count += 1;
    drop(ts);

    let mut sm = state_machine.lock().await;
    sm.on_snooze();
    drop(sm);

    stats.record_reminder_response(false);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initial_state() {
        let ts = TimerState::new(45);
        assert_eq!(ts.continuous_work_sec, 0);
        assert!(!ts.is_resting);
        assert_eq!(ts.ignore_count, 0);
        assert_eq!(ts.effective_interval_sec, 2700);
    }

    #[test]
    fn test_45min_interval() {
        let ts = TimerState::new(45);
        assert_eq!(ts.effective_interval_sec, 2700);
    }

    #[test]
    fn test_eye_rest_initial() {
        let ts = TimerState::new(45);
        assert!(ts.last_eye_rest.elapsed().as_secs() < 1);
    }

    #[test]
    fn test_smart_rule_increase_interval() {
        let mut ts = TimerState::new(45);
        let orig = ts.effective_interval_sec;
        ts.effective_interval_sec = (orig as f64 * 1.5) as u64;
        assert_eq!(ts.effective_interval_sec, 4050); // 67.5 min
    }

    #[test]
    fn test_smart_rule_decrease_interval() {
        let mut ts = TimerState::new(45);
        let orig = ts.effective_interval_sec;
        ts.effective_interval_sec = (orig as f64 * 0.8) as u64;
        assert_eq!(ts.effective_interval_sec, 2160); // 36 min
    }

    #[test]
    fn test_rest_resets_state() {
        let mut ts = TimerState::new(45);
        ts.continuous_work_sec = 3000;
        ts.is_resting = true;
        ts.big_rest_triggered = true;

        // Simulate rest completion
        ts.is_resting = false;
        ts.continuous_work_sec = 0;
        ts.big_rest_triggered = false;

        assert_eq!(ts.continuous_work_sec, 0);
        assert!(!ts.is_resting);
        assert!(!ts.big_rest_triggered);
    }
}
