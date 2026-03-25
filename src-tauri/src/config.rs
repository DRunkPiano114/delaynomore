use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub pet_name: String,
    pub big_rest_interval_min: u32,
    pub eye_rest_interval_min: u32,
    pub rest_duration_min: u32,
    pub snooze_duration_min: u32,
    pub pet_position: (f64, f64),
    pub onboarding_done: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            pet_name: "Kitty".to_string(),
            big_rest_interval_min: 45,
            eye_rest_interval_min: 20,
            rest_duration_min: 5,
            snooze_duration_min: 15,
            pet_position: (0.0, 0.0),
            onboarding_done: false,
        }
    }
}

pub struct ConfigManager {
    config: Mutex<AppConfig>,
    config_path: PathBuf,
}

impl ConfigManager {
    pub fn new(config_path: PathBuf) -> Self {
        let config = std::fs::read_to_string(&config_path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();
        Self {
            config: Mutex::new(config),
            config_path,
        }
    }

    pub fn get(&self) -> AppConfig {
        self.config.lock().unwrap().clone()
    }

    pub fn update<F: FnOnce(&mut AppConfig)>(&self, f: F) {
        let mut config = self.config.lock().unwrap();
        f(&mut config);
        if let Ok(data) = serde_json::to_string_pretty(&*config) {
            let _ = std::fs::write(&self.config_path, data);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let cfg = AppConfig::default();
        assert_eq!(cfg.pet_name, "Kitty");
        assert_eq!(cfg.big_rest_interval_min, 45);
        assert_eq!(cfg.eye_rest_interval_min, 20);
        assert_eq!(cfg.rest_duration_min, 5);
        assert_eq!(cfg.snooze_duration_min, 15);
        assert!(!cfg.onboarding_done);
    }

    #[test]
    fn test_config_manager_update() {
        let tmp = std::env::temp_dir().join("delaynomore_test_config.json");
        let mgr = ConfigManager::new(tmp.clone());
        mgr.update(|c| c.pet_name = "TestCat".to_string());
        assert_eq!(mgr.get().pet_name, "TestCat");
        let _ = std::fs::remove_file(tmp);
    }
}
