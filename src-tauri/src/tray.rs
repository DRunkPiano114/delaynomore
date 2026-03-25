use crate::config::ConfigManager;
use crate::state_machine::Mood;
use tauri::menu::{MenuBuilder, MenuItemBuilder};
use tauri::tray::{TrayIcon, TrayIconBuilder};
use tauri::AppHandle;

pub fn setup_tray(
    app: &AppHandle,
    config: &ConfigManager,
    mood: Mood,
    work_min: u32,
    rest_count: u32,
) -> Result<TrayIcon, Box<dyn std::error::Error>> {
    let menu = build_menu(app, config, mood, work_min, rest_count)?;
    let icon_rgba = make_orange_icon();
    let icon = tauri::image::Image::new_owned(icon_rgba, 16, 16);

    let tray = TrayIconBuilder::new()
        .icon(icon)
        .menu(&menu)
        .show_menu_on_left_click(true)
        .tooltip("DelayNoMore")
        .build(app)?;

    Ok(tray)
}

pub fn build_menu(
    app: &AppHandle,
    config: &ConfigManager,
    mood: Mood,
    work_min: u32,
    rest_count: u32,
) -> Result<tauri::menu::Menu<tauri::Wry>, Box<dyn std::error::Error>> {
    let cfg = config.get();

    let work_display = if work_min >= 60 {
        format!("\u{23f1} Worked {}h {}m", work_min / 60, work_min % 60)
    } else {
        format!("\u{23f1} Worked {}m", work_min)
    };

    let status = MenuItemBuilder::with_id(
        "pet_status",
        format!(
            "\u{1f431} {} \u{00b7} {} {}",
            cfg.pet_name,
            mood.emoji(),
            mood.text()
        ),
    )
    .enabled(false)
    .build(app)?;

    let work_item = MenuItemBuilder::with_id("work_time", &work_display)
        .enabled(false)
        .build(app)?;

    let rest_item = MenuItemBuilder::with_id(
        "rest_count",
        format!("\u{1f6b6} Rested {} times today", rest_count),
    )
    .enabled(false)
    .build(app)?;

    let eye_item = MenuItemBuilder::with_id("eye_rest", "\u{1f440} Eye Care \u{00b7} On")
        .enabled(false)
        .build(app)?;

    let settings = MenuItemBuilder::with_id("settings", "\u{2699}\u{fe0f} Settings...").build(app)?;
    let weekly =
        MenuItemBuilder::with_id("weekly_stats", "\u{1f4ca} Weekly Stats...").build(app)?;
    let quit = MenuItemBuilder::with_id("quit", "Quit DelayNoMore").build(app)?;

    let menu = MenuBuilder::new(app)
        .item(&status)
        .separator()
        .item(&work_item)
        .item(&rest_item)
        .item(&eye_item)
        .separator()
        .item(&settings)
        .item(&weekly)
        .separator()
        .item(&quit)
        .build()?;

    Ok(menu)
}

fn make_orange_icon() -> Vec<u8> {
    let size = 16usize;
    let mut rgba = vec![0u8; size * size * 4];
    let center = size as f64 / 2.0;
    let radius = center - 1.0;
    for y in 0..size {
        for x in 0..size {
            let dx = x as f64 - center;
            let dy = y as f64 - center;
            let i = (y * size + x) * 4;
            if dx * dx + dy * dy <= radius * radius {
                rgba[i] = 0xFB;
                rgba[i + 1] = 0xBF;
                rgba[i + 2] = 0x24;
                rgba[i + 3] = 0xFF;
            }
        }
    }
    rgba
}
