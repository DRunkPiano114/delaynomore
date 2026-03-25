use chrono::{Local, NaiveDate};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum Mood {
    Happy,
    Normal,
    Sad,
}

impl Mood {
    pub fn emoji(&self) -> &str {
        match self {
            Mood::Happy => "\u{1f60a}",
            Mood::Normal => "\u{1f610}",
            Mood::Sad => "\u{1f622}",
        }
    }

    pub fn text(&self) -> &str {
        match self {
            Mood::Happy => "happy",
            Mood::Normal => "normal",
            Mood::Sad => "sad",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum AffinityStage {
    Stranger,
    Acquaintance,
    Friend,
    CloseFriend,
}

pub struct StateMachine {
    pub mood: Mood,
    pub ignore_count: u32,
    pub first_use_date: NaiveDate,
    pub interaction_count: u32,
}

impl StateMachine {
    pub fn new(first_use_date: NaiveDate) -> Self {
        Self {
            mood: Mood::Happy,
            ignore_count: 0,
            first_use_date,
            interaction_count: 0,
        }
    }

    pub fn on_work_duration(&mut self, minutes: u64) {
        if minutes > 30 && self.mood == Mood::Happy {
            self.mood = Mood::Normal;
        }
    }

    pub fn on_reminder_ignored(&mut self) {
        self.ignore_count += 1;
        if self.ignore_count >= 3 {
            self.mood = Mood::Sad;
        }
    }

    pub fn on_rest_completed(&mut self) {
        self.mood = Mood::Happy;
        self.ignore_count = 0;
        self.interaction_count += 1;
    }

    pub fn on_snooze(&mut self) {
        self.on_reminder_ignored();
    }

    pub fn get_affinity_stage(&self) -> AffinityStage {
        let days = (Local::now().date_naive() - self.first_use_date).num_days();
        match days {
            0..=2 => AffinityStage::Stranger,
            3..=6 => AffinityStage::Acquaintance,
            7..=13 => AffinityStage::Friend,
            _ => AffinityStage::CloseFriend,
        }
    }

    pub fn get_persona_prompt(&self, pet_name: &str) -> String {
        match self.get_affinity_stage() {
            AffinityStage::Stranger => format!(
                "You are a desktop cat named {}. You just met the user, so be polite and formal. Use short, warm words to remind them to rest.",
                pet_name
            ),
            AffinityStage::Acquaintance => format!(
                "You are a desktop cat named {}. You're getting to know the user, so be relaxed and playful. Use a lighthearted tone to remind them to rest.",
                pet_name
            ),
            AffinityStage::Friend => format!(
                "You are a desktop cat named {}. You and the user are friends now, so be warm and witty. Use a friendly tone to remind them to rest.",
                pet_name
            ),
            AffinityStage::CloseFriend => format!(
                "You are a desktop cat named {}. You and the user are close friends, so chat like old buddies. Use an intimate but caring tone to remind them to rest.",
                pet_name
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeDelta;

    #[test]
    fn test_happy_to_normal_after_30min() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        assert_eq!(sm.mood, Mood::Happy);
        sm.on_work_duration(31);
        assert_eq!(sm.mood, Mood::Normal);
    }

    #[test]
    fn test_no_transition_under_30min() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        sm.on_work_duration(29);
        assert_eq!(sm.mood, Mood::Happy);
    }

    #[test]
    fn test_normal_to_sad_after_3_ignores() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        sm.mood = Mood::Normal;
        sm.on_reminder_ignored();
        sm.on_reminder_ignored();
        assert_ne!(sm.mood, Mood::Sad);
        sm.on_reminder_ignored();
        assert_eq!(sm.mood, Mood::Sad);
    }

    #[test]
    fn test_rest_resets_to_happy() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        sm.mood = Mood::Sad;
        sm.ignore_count = 5;
        sm.on_rest_completed();
        assert_eq!(sm.mood, Mood::Happy);
        assert_eq!(sm.ignore_count, 0);
    }

    #[test]
    fn test_snooze_counts_as_ignore() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        sm.on_snooze();
        assert_eq!(sm.ignore_count, 1);
    }

    #[test]
    fn test_affinity_stranger() {
        let sm = StateMachine::new(Local::now().date_naive());
        assert_eq!(sm.get_affinity_stage(), AffinityStage::Stranger);
    }

    #[test]
    fn test_affinity_acquaintance() {
        let date = Local::now().date_naive() - TimeDelta::days(4);
        let sm = StateMachine::new(date);
        assert_eq!(sm.get_affinity_stage(), AffinityStage::Acquaintance);
    }

    #[test]
    fn test_affinity_friend() {
        let date = Local::now().date_naive() - TimeDelta::days(10);
        let sm = StateMachine::new(date);
        assert_eq!(sm.get_affinity_stage(), AffinityStage::Friend);
    }

    #[test]
    fn test_affinity_close_friend() {
        let date = Local::now().date_naive() - TimeDelta::days(20);
        let sm = StateMachine::new(date);
        assert_eq!(sm.get_affinity_stage(), AffinityStage::CloseFriend);
    }

    #[test]
    fn test_persona_changes_with_affinity() {
        let sm_new = StateMachine::new(Local::now().date_naive());
        let sm_old = StateMachine::new(Local::now().date_naive() - TimeDelta::days(20));
        let prompt_new = sm_new.get_persona_prompt("Kitty");
        let prompt_old = sm_old.get_persona_prompt("Kitty");
        assert_ne!(prompt_new, prompt_old);
        assert!(prompt_new.contains("polite"));
        assert!(prompt_old.contains("old buddies"));
    }

    #[test]
    fn test_interaction_count_increments() {
        let mut sm = StateMachine::new(Local::now().date_naive());
        assert_eq!(sm.interaction_count, 0);
        sm.on_rest_completed();
        assert_eq!(sm.interaction_count, 1);
        sm.on_rest_completed();
        assert_eq!(sm.interaction_count, 2);
    }
}
