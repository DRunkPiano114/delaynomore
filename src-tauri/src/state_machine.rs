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

pub struct StateMachine {
    pub mood: Mood,
    pub ignore_count: u32,
}

impl StateMachine {
    pub fn new() -> Self {
        Self {
            mood: Mood::Happy,
            ignore_count: 0,
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
    }

    pub fn on_snooze(&mut self) {
        self.on_reminder_ignored();
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

pub fn get_random_message(mood: Mood) -> String {
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
mod tests {
    use super::*;

    #[test]
    fn test_happy_to_normal_after_30min() {
        let mut sm = StateMachine::new();
        assert_eq!(sm.mood, Mood::Happy);
        sm.on_work_duration(31);
        assert_eq!(sm.mood, Mood::Normal);
    }

    #[test]
    fn test_no_transition_under_30min() {
        let mut sm = StateMachine::new();
        sm.on_work_duration(29);
        assert_eq!(sm.mood, Mood::Happy);
    }

    #[test]
    fn test_normal_to_sad_after_3_ignores() {
        let mut sm = StateMachine::new();
        sm.mood = Mood::Normal;
        sm.on_reminder_ignored();
        sm.on_reminder_ignored();
        assert_ne!(sm.mood, Mood::Sad);
        sm.on_reminder_ignored();
        assert_eq!(sm.mood, Mood::Sad);
    }

    #[test]
    fn test_rest_resets_to_happy() {
        let mut sm = StateMachine::new();
        sm.mood = Mood::Sad;
        sm.ignore_count = 5;
        sm.on_rest_completed();
        assert_eq!(sm.mood, Mood::Happy);
        assert_eq!(sm.ignore_count, 0);
    }

    #[test]
    fn test_snooze_counts_as_ignore() {
        let mut sm = StateMachine::new();
        sm.on_snooze();
        assert_eq!(sm.ignore_count, 1);
    }

    #[test]
    fn test_random_messages_not_empty() {
        assert!(!get_random_message(Mood::Happy).is_empty());
        assert!(!get_random_message(Mood::Normal).is_empty());
        assert!(!get_random_message(Mood::Sad).is_empty());
    }
}
