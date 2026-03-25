mod commands;
mod config;
mod idle;
mod llm;
mod state_machine;
mod stats;
mod timer;
mod tray;

use commands::AppState;
use config::ConfigManager;
use llm::LlmClient;
use state_machine::StateMachine;
use stats::StatsStore;
use timer::TimerState;

use chrono::Local;
use std::sync::Arc;
use tauri::Manager;
use tokio::sync::Mutex;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let handle = app.handle().clone();

            // Config
            let data_dir = app.path().app_data_dir().expect("no app data dir");
            std::fs::create_dir_all(&data_dir).ok();
            let config = Arc::new(ConfigManager::new(data_dir.join("config.json")));
            let cfg = config.get();

            // Stats (SQLite)
            let stats = Arc::new(StatsStore::new(data_dir.join("stats.db")));

            // State machine
            let first_use = stats
                .get_config_value("first_use_date")
                .and_then(|s| s.parse().ok())
                .unwrap_or_else(|| {
                    let today = Local::now().date_naive();
                    stats.set_config_value("first_use_date", &today.to_string());
                    today
                });
            let state_machine = Arc::new(Mutex::new(StateMachine::new(first_use)));

            // LLM client
            let llm_client = Arc::new(LlmClient::new(
                cfg.llm_api_key.clone(),
                cfg.llm_provider.clone(),
            ));

            // Timer
            let timer = Arc::new(Mutex::new(TimerState::new(cfg.big_rest_interval_min)));

            // System tray
            let tray_icon = tray::setup_tray(&handle, &config, state_machine::Mood::Happy, 0, 0)
                .expect("failed to setup tray");

            tray_icon.on_menu_event(move |app, event| {
                if event.id().as_ref() == "quit" {
                    app.exit(0);
                }
            });

            // Managed state
            app.manage(AppState {
                timer: timer.clone(),
                config: config.clone(),
                state_machine: state_machine.clone(),
                stats: stats.clone(),
            });

            // Start background timer
            timer::start_timer(handle, timer, config, state_machine, stats, llm_client);

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::user_rest,
            commands::user_snooze,
            commands::set_pet_name,
            commands::complete_onboarding,
            commands::get_config,
            commands::update_pet_position,
            commands::get_today_stats,
            commands::get_timer_status,
            commands::set_intervals,
            commands::trigger_reminder,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
