import AppKit
import DelayNoMoreCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: L10n.string("menu.idle"), action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: L10n.string("menu.start"), action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: L10n.string("menu.stop"), action: #selector(stop), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: L10n.string("menu.settings"), action: #selector(showSettings), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: L10n.string("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

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
        store.flush()
    }

    private func buildMenu() {
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
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

        if case .rest(let remaining) = model.phase {
            reminderController?.updateCountdown(remaining)
        }
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
                title: L10n.string("alert.chooseMedia.title"),
                message: L10n.string("alert.chooseMedia.message")
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
                title: L10n.string("alert.mediaCouldNotLoad.title"),
                message: L10n.string("alert.mediaCouldNotLoad.message")
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
        panel.title = L10n.string("panel.chooseMedia.title")
        panel.message = L10n.string("panel.chooseMedia.message")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ReminderMediaLibrary.allowedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        guard let reminder = ReminderMediaLibrary.media(for: url) else {
            showAlert(
                title: L10n.string("alert.unsupportedMedia.title"),
                message: L10n.string("alert.unsupportedMedia.message")
            )
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
        store.scheduleSave(config)
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
            showAlert(
                title: L10n.string("alert.couldNotSave.title"),
                message: error.localizedDescription
            )
            settingsController?.update(config: config)
        }

        updateMenu()
    }

    private func updateMenu() {
        stateItem.title = stateTitle
        configurePrimaryAction()
        stopItem.isHidden = shouldHideStopItem

        guard let button = statusItem.button else { return }

        switch model.phase {
        case .idle:
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: L10n.string("tooltip.app"))
            image?.isTemplate = true
            button.image = image
            button.toolTip = L10n.string("tooltip.app")
            stateItem.image = Self.menuSymbol("timer")

        case .work(let remaining):
            let progress = CGFloat(remaining) / CGFloat(model.workSeconds)
            button.image = Self.makeRingImage(progress: progress)
            button.toolTip = L10n.string("tooltip.work", formatClock(remaining))
            stateItem.image = Self.menuSymbol("timer")

        case .rest(let remaining):
            let progress = CGFloat(remaining) / CGFloat(model.breakSeconds)
            button.image = Self.makeRingImage(progress: progress)
            button.toolTip = L10n.string("tooltip.break", formatClock(remaining))
            stateItem.image = Self.menuSymbol("pause.circle")

        case .paused(let previous):
            let total: Int
            switch previous {
            case .work: total = model.workSeconds
            case .rest: total = model.breakSeconds
            }
            let progress = CGFloat(previous.remainingSeconds) / CGFloat(total)
            button.image = Self.makeRingImage(progress: progress)
            button.toolTip = L10n.string("tooltip.paused", formatClock(previous.remainingSeconds))
            stateItem.image = Self.menuSymbol("pause.circle")
        }

        button.setAccessibilityLabel(button.toolTip)
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
            startItem.title = L10n.string("menu.start")
            startItem.action = #selector(start)
            startItem.image = Self.menuSymbol("play.fill")
        case .work:
            startItem.title = L10n.string("menu.pause")
            startItem.action = #selector(pause)
            startItem.image = Self.menuSymbol("pause.fill")
        case .rest:
            startItem.title = L10n.string("menu.endBreak")
            startItem.action = #selector(skipBreak)
            startItem.image = Self.menuSymbol("checkmark")
        case .paused:
            startItem.title = L10n.string("menu.resume")
            startItem.action = #selector(start)
            startItem.image = Self.menuSymbol("play.fill")
        }
    }

    private var stateTitle: String {
        switch model.phase {
        case .idle:
            return L10n.string("menu.idle")
        case .work(let remainingSeconds):
            return L10n.string("state.working", formatClock(remainingSeconds))
        case .rest(let remainingSeconds):
            return L10n.string("state.break", formatClock(remainingSeconds))
        case .paused(let previous):
            return L10n.string("state.paused", formatClock(previous.remainingSeconds))
        }
    }

    private static func makeRingImage(progress: CGFloat) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let lineWidth: CGFloat = 1.8
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = (size - lineWidth) / 2

            let trackPath = NSBezierPath()
            trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            NSColor(white: 0, alpha: 0.15).setStroke()
            trackPath.lineWidth = lineWidth
            trackPath.stroke()

            guard progress > 0.005 else { return true }
            let startAngle: CGFloat = 90
            let endAngle = startAngle - progress * 360
            let arcPath = NSBezierPath()
            arcPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            NSColor(white: 0, alpha: 1.0).setStroke()
            arcPath.lineWidth = lineWidth
            arcPath.lineCapStyle = .round
            arcPath.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("button.ok"))
        alert.runModal()
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
