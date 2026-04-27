import AppKit
import DelayNoMoreCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    private let store = ConfigStore()
    private var config = AppConfig.default
    private var model = TimerModel(config: .default)
    private var timer: Timer?
    private var reminderController: ReminderWindowController?
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = store.load()
        model = TimerModel(config: config)
        reminderController = ReminderWindowController()

        buildMenu()
        startClock()

        updateMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func buildMenu() {
        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        [startItem, stopItem, settingsItem].forEach {
            $0.target = self
        }
        quitItem.target = NSApp

        stateItem.isEnabled = false
        stopItem.image = Self.menuSymbol("stop.fill")
        settingsItem.image = Self.menuSymbol("gearshape")
        quitItem.image = Self.menuSymbol("xmark.circle")

        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func startClock() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let transition = model.tick()

        switch transition {
        case .enteredRest:
            showReminderOrPromptForMedia()
        case .finishedRest:
            reminderController?.dismiss(animated: true)
        case .none:
            break
        }

        updateMenu()
    }

    @objc private func start() {
        guard validReminder() != nil || chooseMedia() else {
            updateMenu()
            return
        }

        model.start()
        updateMenu()
    }

    @objc private func pause() {
        model.pause()
        updateMenu()
    }

    @objc private func stop() {
        reminderController?.dismiss(animated: false)
        model.reset(started: false)
        updateMenu()
    }

    @objc private func skipBreak() {
        endBreakEarly()
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(config: config) { [weak self] nextConfig in
                self?.applyConfig(nextConfig)
            }
        }

        settingsController?.update(config: config)
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    private func endBreakEarly() {
        if model.skipRest() == .finishedRest {
            reminderController?.dismiss(animated: true)
        }
        updateMenu()
    }

    private func showReminderOrPromptForMedia() {
        guard let reminder = validReminder() else {
            showAlert(
                title: "Choose Reminder Media",
                message: "DelayNoMore needs a valid image or video before it can show break reminders."
            )

            guard chooseMedia(), let reminder = validReminder() else {
                _ = model.skipRest()
                return
            }

            _ = reminderController?.show(media: reminder)
            return
        }

        if reminderController?.show(media: reminder) != true {
            showAlert(
                title: "Reminder Media Could Not Be Loaded",
                message: "Choose another image or video to continue."
            )

            guard chooseMedia(), let reminder = validReminder() else {
                _ = model.skipRest()
                return
            }

            _ = reminderController?.show(media: reminder)
        }
    }

    private func chooseMedia() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose Reminder Media"
        panel.message = "Choose an image or video to show during breaks."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ReminderMediaLibrary.allowedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        guard let reminder = ReminderMediaLibrary.media(for: url) else {
            showAlert(title: "Unsupported Media", message: "Choose an image or video macOS can load.")
            return false
        }

        config.reminder = reminder
        saveConfig()
        settingsController?.update(config: config)
        return true
    }

    private func validReminder() -> ReminderMedia? {
        guard let reminder = config.reminder, ReminderMediaLibrary.isAvailable(reminder) else {
            return nil
        }

        return reminder
    }

    private func saveConfig() {
        do {
            try store.save(config)
        } catch {
            showAlert(title: "Could Not Save Settings", message: error.localizedDescription)
        }
    }

    private func applyConfig(_ nextConfig: AppConfig) {
        do {
            try nextConfig.validate()

            var nextModel = model
            if nextConfig.workMinutes != config.workMinutes {
                try nextModel.setWorkMinutes(nextConfig.workMinutes)
            }
            if nextConfig.breakMinutes != config.breakMinutes {
                try nextModel.setBreakMinutes(nextConfig.breakMinutes)
            }

            config = nextConfig
            model = nextModel
            saveConfig()
        } catch {
            showAlert(title: "Could Not Save Settings", message: error.localizedDescription)
            settingsController?.update(config: config)
        }

        updateMenu()
    }

    private func updateMenu() {
        let status = statusItemPresentation
        stateItem.title = stateTitle
        stateItem.image = Self.menuSymbol(status.symbolName)
        configurePrimaryAction()
        stopItem.isHidden = shouldHideStopItem

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: status.accessibilityDescription)
            image?.isTemplate = true

            button.image = image
            button.title = status.title.isEmpty ? "" : " \(status.title)"
            button.toolTip = status.accessibilityDescription
            button.setAccessibilityLabel(status.accessibilityDescription)
        }
    }

    private var shouldHideStopItem: Bool {
        switch model.phase {
        case .idle, .rest:
            return true
        case .work, .paused:
            return false
        }
    }

    private func configurePrimaryAction() {
        startItem.isEnabled = true

        switch model.phase {
        case .idle:
            startItem.title = "Start"
            startItem.action = #selector(start)
            startItem.image = Self.menuSymbol("play.fill")
        case .work:
            startItem.title = "Pause"
            startItem.action = #selector(pause)
            startItem.image = Self.menuSymbol("pause.fill")
        case .rest:
            startItem.title = "End Break"
            startItem.action = #selector(skipBreak)
            startItem.image = Self.menuSymbol("checkmark")
        case .paused:
            startItem.title = "Resume"
            startItem.action = #selector(start)
            startItem.image = Self.menuSymbol("play.fill")
        }
    }

    private var stateTitle: String {
        switch model.phase {
        case .idle:
            return "Idle"
        case .work(let remainingSeconds):
            return "Working \(formatClock(remainingSeconds))"
        case .rest(let remainingSeconds):
            return "Break \(formatClock(remainingSeconds))"
        case .paused(let previous):
            switch previous {
            case .work(let remainingSeconds):
                return "Paused \(formatClock(remainingSeconds))"
            case .rest(let remainingSeconds):
                return "Paused \(formatClock(remainingSeconds))"
            }
        }
    }

    private var statusItemPresentation: (symbolName: String, title: String, accessibilityDescription: String) {
        switch model.phase {
        case .idle:
            return ("timer", "", "DelayNoMore idle")
        case .work(let remainingSeconds):
            let clock = formatClock(remainingSeconds)
            return ("timer", clock, "DelayNoMore work ends in \(clock)")
        case .rest(let remainingSeconds):
            let clock = formatClock(remainingSeconds)
            return ("pause.circle", clock, "DelayNoMore break ends in \(clock)")
        case .paused(let previous):
            let clock = formatClock(previous.remainingSeconds)
            return ("pause.circle", clock, "DelayNoMore paused with \(clock) remaining")
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
