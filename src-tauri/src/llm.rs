use crate::state_machine::Mood;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Debug, Clone, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct CacheKey {
    pub mood: String,
    pub duration_bucket: String,
    pub time_of_day: String,
}

impl CacheKey {
    pub fn new(mood: Mood, work_minutes: u64, hour: u32) -> Self {
        let duration_bucket = match work_minutes {
            0..=30 => "0-30",
            31..=60 => "30-60",
            61..=90 => "60-90",
            _ => "90+",
        }
        .to_string();

        let time_of_day = match hour {
            6..=11 => "morning",
            12..=17 => "afternoon",
            _ => "evening",
        }
        .to_string();

        Self {
            mood: format!("{:?}", mood),
            duration_bucket,
            time_of_day,
        }
    }

    pub fn to_string_key(&self) -> String {
        format!("{}:{}:{}", self.mood, self.duration_bucket, self.time_of_day)
    }
}

pub struct LlmClient {
    client: Client,
    api_key: Option<String>,
    provider: String,
}

impl LlmClient {
    pub fn new(api_key: Option<String>, provider: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_default();
        Self {
            client,
            api_key,
            provider,
        }
    }

    pub async fn generate_message(
        &self,
        persona: &str,
        mood: Mood,
        work_minutes: u64,
        rest_count: u32,
    ) -> String {
        if let Some(ref key) = self.api_key {
            if let Ok(msg) = self
                .call_api(key, persona, mood, work_minutes, rest_count)
                .await
            {
                return msg;
            }
        }
        get_fallback_message(mood)
    }

    async fn call_api(
        &self,
        api_key: &str,
        persona: &str,
        mood: Mood,
        work_minutes: u64,
        rest_count: u32,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let prompt = format!(
            "{}\n\nCurrent status: mood is {}, worked for {} minutes straight, rested {} times today.\nGenerate a reminder under 20 words. Output only the reminder itself.",
            persona,
            mood.text(),
            work_minutes,
            rest_count,
        );

        match self.provider.as_str() {
            "openai" => self.call_openai(api_key, &prompt).await,
            _ => self.call_claude(api_key, &prompt).await,
        }
    }

    async fn call_claude(
        &self,
        api_key: &str,
        prompt: &str,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let body = serde_json::json!({
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 100,
            "messages": [{"role": "user", "content": prompt}]
        });

        let resp = self
            .client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", api_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&body)
            .send()
            .await?;

        let json: serde_json::Value = resp.json().await?;
        let text = json["content"][0]["text"]
            .as_str()
            .ok_or("no text in response")?
            .to_string();
        Ok(text)
    }

    async fn call_openai(
        &self,
        api_key: &str,
        prompt: &str,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let body = serde_json::json!({
            "model": "gpt-5.4-mini-2026-03-17",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 100,
        });

        let resp = self
            .client
            .post("https://api.openai.com/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", api_key))
            .json(&body)
            .send()
            .await?;

        let json: serde_json::Value = resp.json().await?;
        let text = json["choices"][0]["message"]["content"]
            .as_str()
            .ok_or("no text in response")?
            .to_string();
        Ok(text)
    }
}

const HAPPY_MESSAGES: &[&str] = &[
    "Great work! Time to stretch and move around!",
    "Grab some water, you deserve a break~",
    "The code won't run away, take a break first!",
    "Stand up and walk around, inspiration might strike~",
    "You've been so productive today! Rest up and keep going~",
    "Eyes feeling tired? Look out the window for a bit~",
    "Resting helps you code even better!",
    "Coffee? Nah, water is healthier~",
];

const NORMAL_MESSAGES: &[&str] = &[
    "You've been working for a while, time for a break~",
    "Health is wealth, take a short rest!",
    "Sitting too long isn't great for you, move around~",
    "The keyboard can wait, your body can't~",
    "Work matters, but health matters more. Take a break~",
    "Time to move! Stand up and take a walk~",
    "Don't forget to drink water and rest a bit~",
];

const SAD_MESSAGES: &[&str] = &[
    "You've ignored me several times... please rest now",
    "Please take a break, I'm worried about you",
    "I'll be sad if you don't rest...",
    "Your body is sending alarms, please take a break",
    "I know you're busy, but health really matters",
    "Please, just 5 minutes of rest, okay?",
    "You've been working way too long, I'm worried...",
    "If not for yourself, rest for me...",
];

pub fn get_fallback_message(mood: Mood) -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as usize;

    let messages = match mood {
        Mood::Happy => HAPPY_MESSAGES,
        Mood::Normal => NORMAL_MESSAGES,
        Mood::Sad => SAD_MESSAGES,
    };

    messages[seed % messages.len()].to_string()
}

#[cfg(test)]
pub fn total_preset_count() -> usize {
    HAPPY_MESSAGES.len() + NORMAL_MESSAGES.len() + SAD_MESSAGES.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_key_duration_buckets() {
        assert_eq!(CacheKey::new(Mood::Happy, 15, 10).duration_bucket, "0-30");
        assert_eq!(CacheKey::new(Mood::Happy, 45, 10).duration_bucket, "30-60");
        assert_eq!(CacheKey::new(Mood::Happy, 75, 10).duration_bucket, "60-90");
        assert_eq!(CacheKey::new(Mood::Happy, 100, 10).duration_bucket, "90+");
    }

    #[test]
    fn test_cache_key_time_of_day() {
        assert_eq!(CacheKey::new(Mood::Happy, 30, 9).time_of_day, "morning");
        assert_eq!(CacheKey::new(Mood::Happy, 30, 14).time_of_day, "afternoon");
        assert_eq!(CacheKey::new(Mood::Happy, 30, 21).time_of_day, "evening");
    }

    #[test]
    fn test_cache_key_string_format() {
        let key = CacheKey::new(Mood::Happy, 45, 14);
        let s = key.to_string_key();
        assert!(s.contains("Happy"));
        assert!(s.contains("30-60"));
        assert!(s.contains("afternoon"));
    }

    #[test]
    fn test_fallback_messages_not_empty() {
        assert!(!get_fallback_message(Mood::Happy).is_empty());
        assert!(!get_fallback_message(Mood::Normal).is_empty());
        assert!(!get_fallback_message(Mood::Sad).is_empty());
    }

    #[test]
    fn test_preset_messages_at_least_20() {
        assert!(
            total_preset_count() >= 20,
            "Need at least 20 preset messages, got {}",
            total_preset_count()
        );
    }

    #[tokio::test]
    async fn test_generate_without_api_key_uses_fallback() {
        let client = LlmClient::new(None, "claude".to_string());
        let msg = client
            .generate_message("test persona", Mood::Happy, 45, 1)
            .await;
        assert!(!msg.is_empty());
    }
}
