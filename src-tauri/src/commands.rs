use crate::config::ConfigManager;
use crate::llm::get_fallback_message;
use crate::state_machine::StateMachine;
use crate::stats::{StatsStore, TodayStats};
use crate::timer::{self, TimerState};
use serde::Serialize;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;

pub struct AppState {
    pub timer: Arc<Mutex<TimerState>>,
    pub config: Arc<ConfigManager>,
    pub state_machine: Arc<Mutex<StateMachine>>,
    pub stats: Arc<StatsStore>,
}

#[tauri::command]
pub async fn user_rest(state: State<'_, AppState>, app: AppHandle) -> Result<(), String> {
    timer::handle_user_rest(&state.timer, &state.state_machine, &state.stats).await;

    let sm = state.state_machine.lock().await;
    let mood = sm.mood;
    drop(sm);

    let _ = app.emit(
        "pet:state_update",
        serde_json::json!({"mood": format!("{:?}", mood)}),
    );
    Ok(())
}

#[tauri::command]
pub async fn user_snooze(state: State<'_, AppState>, app: AppHandle) -> Result<(), String> {
    timer::handle_user_snooze(&state.timer, &state.config, &state.state_machine, &state.stats)
        .await;

    let sm = state.state_machine.lock().await;
    let mood = sm.mood;
    drop(sm);

    let _ = app.emit(
        "pet:state_update",
        serde_json::json!({"mood": format!("{:?}", mood)}),
    );
    let _ = app.emit("pet:walk_back", ());
    Ok(())
}

#[tauri::command]
pub async fn set_pet_name(name: String, state: State<'_, AppState>) -> Result<(), String> {
    state.config.update(|c| c.pet_name = name);
    Ok(())
}

#[tauri::command]
pub async fn complete_onboarding(state: State<'_, AppState>) -> Result<(), String> {
    state.config.update(|c| c.onboarding_done = true);
    Ok(())
}

#[tauri::command]
pub async fn get_config(state: State<'_, AppState>) -> Result<crate::config::AppConfig, String> {
    Ok(state.config.get())
}

#[tauri::command]
pub async fn update_pet_position(
    x: f64,
    y: f64,
    state: State<'_, AppState>,
) -> Result<(), String> {
    state.config.update(|c| c.pet_position = (x, y));
    Ok(())
}

#[tauri::command]
pub async fn get_today_stats(state: State<'_, AppState>) -> Result<TodayStats, String> {
    Ok(state.stats.get_today_stats())
}

#[derive(Serialize)]
pub struct TimerStatus {
    pub work_sec: u64,
    pub interval_sec: u64,
    pub is_resting: bool,
}

#[tauri::command]
pub async fn get_timer_status(state: State<'_, AppState>) -> Result<TimerStatus, String> {
    let ts = state.timer.lock().await;
    Ok(TimerStatus {
        work_sec: ts.continuous_work_sec,
        interval_sec: ts.effective_interval_sec,
        is_resting: ts.is_resting,
    })
}

#[tauri::command]
pub async fn set_intervals(
    big_rest_min: u32,
    eye_rest_min: u32,
    state: State<'_, AppState>,
) -> Result<(), String> {
    state.config.update(|c| {
        c.big_rest_interval_min = big_rest_min;
        c.eye_rest_interval_min = eye_rest_min;
    });
    // Also update the live timer's effective interval
    let mut ts = state.timer.lock().await;
    ts.effective_interval_sec = (big_rest_min as u64) * 60;
    Ok(())
}

#[tauri::command]
pub async fn trigger_reminder(state: State<'_, AppState>, app: AppHandle) -> Result<(), String> {
    let sm = state.state_machine.lock().await;
    let mood = sm.mood;
    drop(sm);

    let msg = get_fallback_message(mood);
    let ts = state.timer.lock().await;
    let work_dur = ts.continuous_work_sec;
    drop(ts);

    let _ = app.emit("pet:walk_to_center", ());
    let _ = app.emit(
        "pet:show_bubble",
        serde_json::json!({"message": msg, "workDuration": work_dur / 60}),
    );
    Ok(())
}
