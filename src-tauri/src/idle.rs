#[cfg(target_os = "macos")]
#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGEventSourceSecondsSinceLastEventType(state_id: u32, event_type: u32) -> f64;
}

/// Returns seconds since last user input event (keyboard/mouse).
/// Uses macOS CGEventSource API — no permissions required.
pub fn get_idle_seconds() -> f64 {
    #[cfg(target_os = "macos")]
    {
        const COMBINED_SESSION_STATE: u32 = 0;
        const ANY_INPUT_EVENT: u32 = 0xFFFFFFFF;
        unsafe { CGEventSourceSecondsSinceLastEventType(COMBINED_SESSION_STATE, ANY_INPUT_EVENT) }
    }
    #[cfg(not(target_os = "macos"))]
    {
        0.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_idle_seconds_returns_non_negative() {
        let idle = get_idle_seconds();
        assert!(idle >= 0.0);
    }
}
