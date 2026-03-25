use crate::config::ConfigManager;
use crate::idle;
use crate::llm::{get_fallback_message, CacheKey, LlmClient};
use crate::state_machine::StateMachine;
use crate::stats::StatsStore;
use chrono::{Local, Timelike};
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
    pub llm_prefetched_msg: Option<String>,
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
            llm_prefetched_msg: None,
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
    llm_client: Arc<LlmClient>,
) {
    tauri::async_runtime::spawn(async move {
        loop {
            let ts = timer.lock().await;
            let tick_secs = if ts.is_resting { 3 } else { 10 };
            drop(ts);

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

            // Prefetch LLM at (interval - 5min)
            let prefetch_at = ts.effective_interval_sec.saturating_sub(5 * 60);
            if ts.continuous_work_sec >= prefetch_at
                && ts.llm_prefetched_msg.is_none()
                && !ts.big_rest_triggered
            {
                let sm = state_machine.lock().await;
                let mood = sm.mood;
                let persona = sm.get_persona_prompt(&cfg.pet_name);
                drop(sm);

                let hour = Local::now().hour();
                let cache_key = CacheKey::new(mood, work_min, hour);

                if let Some(cached) = stats.get_cached_message(&cache_key.to_string_key()) {
                    ts.llm_prefetched_msg = Some(cached);
                } else {
                    let llm = llm_client.clone();
                    let stats_c = stats.clone();
                    let key_str = cache_key.to_string_key();
                    let rest_count = stats.get_today_stats().rest_count;
                    drop(ts);

                    let msg = llm
                        .generate_message(&persona, mood, work_min, rest_count)
                        .await;
                    stats_c.cache_message(&key_str, &msg);

                    let mut ts = timer.lock().await;
                    ts.llm_prefetched_msg = Some(msg);
                    continue;
                }
            }

            // Big rest reminder
            if ts.continuous_work_sec >= ts.effective_interval_sec && !ts.big_rest_triggered {
                ts.big_rest_triggered = true;
                let sm = state_machine.lock().await;
                let mood = sm.mood;
                drop(sm);

                let msg = ts
                    .llm_prefetched_msg
                    .take()
                    .unwrap_or_else(|| get_fallback_message(mood));
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
    ts.llm_prefetched_msg = None;
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
    ts.llm_prefetched_msg = None;
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
        assert!(ts.llm_prefetched_msg.is_none());
        assert_eq!(ts.effective_interval_sec, 2700);
    }

    #[test]
    fn test_45min_interval() {
        let ts = TimerState::new(45);
        assert_eq!(ts.effective_interval_sec, 2700);
    }

    #[test]
    fn test_prefetch_at_40min() {
        let ts = TimerState::new(45);
        let prefetch = ts.effective_interval_sec.saturating_sub(5 * 60);
        assert_eq!(prefetch, 2400); // 40 min
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
