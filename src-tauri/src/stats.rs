use chrono::Local;
use rusqlite::{params, Connection};
use serde::Serialize;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Default)]
pub struct TodayStats {
    pub work_duration_min: u32,
    pub rest_count: u32,
    pub reminders_accepted: u32,
    pub reminders_ignored: u32,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Default)]
pub struct WeekStats {
    pub total_work_min: u32,
    pub total_rest_count: u32,
    pub avg_work_min_per_day: u32,
    pub acceptance_rate: f64,
}

pub struct StatsStore {
    conn: Mutex<Option<Connection>>,
    memory_buffer: Mutex<Vec<MemEvent>>,
}

#[allow(dead_code)]
enum MemEvent {
    Work { date: String, duration_sec: u64 },
    Rest { date: String },
    Accepted { date: String },
    Ignored { date: String },
}

const SCHEMA: &str = "
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL UNIQUE,
    work_duration_sec INTEGER NOT NULL DEFAULT 0,
    rest_count INTEGER NOT NULL DEFAULT 0,
    reminders_accepted INTEGER NOT NULL DEFAULT 0,
    reminders_ignored INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS llm_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT NOT NULL UNIQUE,
    message TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);";

impl StatsStore {
    pub fn new(db_path: PathBuf) -> Self {
        let conn = Connection::open(&db_path).ok();
        if let Some(ref c) = conn {
            let _ = c.execute_batch(SCHEMA);
        }
        Self {
            conn: Mutex::new(conn),
            memory_buffer: Mutex::new(Vec::new()),
        }
    }

    #[cfg(test)]
    pub fn in_memory() -> Self {
        let conn = Connection::open_in_memory().ok();
        if let Some(ref c) = conn {
            let _ = c.execute_batch(SCHEMA);
        }
        Self {
            conn: Mutex::new(conn),
            memory_buffer: Mutex::new(Vec::new()),
        }
    }

    fn today() -> String {
        Local::now().format("%Y-%m-%d").to_string()
    }

    fn ensure_row(conn: &Connection, date: &str) {
        let _ = conn.execute(
            "INSERT OR IGNORE INTO sessions (date) VALUES (?1)",
            params![date],
        );
    }

    pub fn record_work_session(&self, duration_sec: u64) {
        let date = Self::today();
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            Self::ensure_row(conn, &date);
            let _ = conn.execute(
                "UPDATE sessions SET work_duration_sec = work_duration_sec + ?1 WHERE date = ?2",
                params![duration_sec as i64, date],
            );
        } else {
            drop(guard);
            self.memory_buffer
                .lock()
                .unwrap()
                .push(MemEvent::Work { date, duration_sec });
        }
    }

    pub fn record_rest(&self) {
        let date = Self::today();
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            Self::ensure_row(conn, &date);
            let _ = conn.execute(
                "UPDATE sessions SET rest_count = rest_count + 1 WHERE date = ?1",
                params![date],
            );
        } else {
            drop(guard);
            self.memory_buffer
                .lock()
                .unwrap()
                .push(MemEvent::Rest { date });
        }
    }

    pub fn record_reminder_response(&self, accepted: bool) {
        let date = Self::today();
        let field = if accepted {
            "reminders_accepted"
        } else {
            "reminders_ignored"
        };
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            Self::ensure_row(conn, &date);
            let _ = conn.execute(
                &format!(
                    "UPDATE sessions SET {f} = {f} + 1 WHERE date = ?1",
                    f = field
                ),
                params![date],
            );
        } else {
            drop(guard);
            let event = if accepted {
                MemEvent::Accepted { date }
            } else {
                MemEvent::Ignored { date }
            };
            self.memory_buffer.lock().unwrap().push(event);
        }
    }

    pub fn get_today_stats(&self) -> TodayStats {
        let date = Self::today();
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            conn.query_row(
                "SELECT work_duration_sec, rest_count, reminders_accepted, reminders_ignored FROM sessions WHERE date = ?1",
                params![date],
                |row| {
                    let work_sec: i64 = row.get(0)?;
                    Ok(TodayStats {
                        work_duration_min: (work_sec / 60) as u32,
                        rest_count: row.get(1)?,
                        reminders_accepted: row.get(2)?,
                        reminders_ignored: row.get(3)?,
                    })
                },
            )
            .unwrap_or_default()
        } else {
            TodayStats::default()
        }
    }

    #[allow(dead_code)]
    pub fn get_week_stats(&self) -> WeekStats {
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            let week_ago = (Local::now().date_naive() - chrono::TimeDelta::days(7))
                .format("%Y-%m-%d")
                .to_string();
            conn.query_row(
                "SELECT COALESCE(SUM(work_duration_sec),0), COALESCE(SUM(rest_count),0), \
                 COALESCE(SUM(reminders_accepted),0), COALESCE(SUM(reminders_ignored),0), \
                 MAX(COUNT(DISTINCT date),1) FROM sessions WHERE date >= ?1",
                params![week_ago],
                |row| {
                    let total_sec: i64 = row.get(0)?;
                    let rest: u32 = row.get(1)?;
                    let accepted: u32 = row.get(2)?;
                    let ignored: u32 = row.get(3)?;
                    let days: u32 = row.get::<_, u32>(4)?.max(1);
                    let total = accepted + ignored;
                    Ok(WeekStats {
                        total_work_min: (total_sec / 60) as u32,
                        total_rest_count: rest,
                        avg_work_min_per_day: (total_sec / 60) as u32 / days,
                        acceptance_rate: if total > 0 {
                            accepted as f64 / total as f64
                        } else {
                            0.0
                        },
                    })
                },
            )
            .unwrap_or_default()
        } else {
            WeekStats::default()
        }
    }

    // LLM cache
    pub fn get_cached_message(&self, cache_key: &str) -> Option<String> {
        let guard = self.conn.lock().unwrap();
        let conn = guard.as_ref()?;
        conn.query_row(
            "SELECT message FROM llm_cache WHERE cache_key = ?1 AND datetime(created_at) > datetime('now', '-7 days')",
            params![cache_key],
            |row| row.get(0),
        )
        .ok()
    }

    pub fn cache_message(&self, cache_key: &str, message: &str) {
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            let now = Local::now().to_rfc3339();
            let _ = conn.execute(
                "INSERT OR REPLACE INTO llm_cache (cache_key, message, created_at) VALUES (?1, ?2, ?3)",
                params![cache_key, message, now],
            );
        }
    }

    // Key-value config storage (for first_use_date etc.)
    pub fn get_config_value(&self, key: &str) -> Option<String> {
        let guard = self.conn.lock().unwrap();
        let conn = guard.as_ref()?;
        conn.query_row(
            "SELECT value FROM config WHERE key = ?1",
            params![key],
            |row| row.get(0),
        )
        .ok()
    }

    pub fn set_config_value(&self, key: &str, value: &str) {
        let guard = self.conn.lock().unwrap();
        if let Some(ref conn) = *guard {
            let _ = conn.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?1, ?2)",
                params![key, value],
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_record_work_duration() {
        let store = StatsStore::in_memory();
        store.record_work_session(2700); // 45 min
        let stats = store.get_today_stats();
        assert_eq!(stats.work_duration_min, 45);
    }

    #[test]
    fn test_record_rest_count() {
        let store = StatsStore::in_memory();
        store.record_rest();
        store.record_rest();
        assert_eq!(store.get_today_stats().rest_count, 2);
    }

    #[test]
    fn test_record_reminder_accepted_and_ignored() {
        let store = StatsStore::in_memory();
        store.record_reminder_response(true);
        store.record_reminder_response(true);
        store.record_reminder_response(false);
        let stats = store.get_today_stats();
        assert_eq!(stats.reminders_accepted, 2);
        assert_eq!(stats.reminders_ignored, 1);
    }

    #[test]
    fn test_today_stats_combined() {
        let store = StatsStore::in_memory();
        store.record_work_session(3600);
        store.record_rest();
        store.record_reminder_response(true);
        let stats = store.get_today_stats();
        assert_eq!(stats.work_duration_min, 60);
        assert_eq!(stats.rest_count, 1);
        assert_eq!(stats.reminders_accepted, 1);
    }

    #[test]
    fn test_week_stats() {
        let store = StatsStore::in_memory();
        store.record_work_session(7200);
        store.record_rest();
        let week = store.get_week_stats();
        assert_eq!(week.total_work_min, 120);
        assert_eq!(week.total_rest_count, 1);
    }

    #[test]
    fn test_empty_stats_defaults() {
        let store = StatsStore::in_memory();
        let stats = store.get_today_stats();
        assert_eq!(stats.work_duration_min, 0);
        assert_eq!(stats.rest_count, 0);
        assert_eq!(stats.reminders_accepted, 0);
        assert_eq!(stats.reminders_ignored, 0);
    }

    #[test]
    fn test_llm_cache() {
        let store = StatsStore::in_memory();
        store.cache_message("Happy:30-60:afternoon", "Time for a break");
        let cached = store.get_cached_message("Happy:30-60:afternoon");
        assert_eq!(cached, Some("Time for a break".to_string()));
    }

    #[test]
    fn test_llm_cache_miss() {
        let store = StatsStore::in_memory();
        assert_eq!(store.get_cached_message("nonexistent"), None);
    }

    #[test]
    fn test_config_kv() {
        let store = StatsStore::in_memory();
        store.set_config_value("first_use_date", "2026-01-01");
        assert_eq!(
            store.get_config_value("first_use_date"),
            Some("2026-01-01".to_string())
        );
    }
}
