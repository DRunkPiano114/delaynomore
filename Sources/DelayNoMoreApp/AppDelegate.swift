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
            reminderController?.dismiss(animated: true, fast: true)
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
            if nextConfig.workSeconds != config.workSeconds {
                try nextModel.setWorkSeconds(nextConfig.workSeconds)
            }
            if nextConfig.breakSeconds != config.breakSeconds {
                try nextModel.setBreakSeconds(nextConfig.breakSeconds)
            }
            if nextConfig.repeats != config.repeats {
                nextModel.setRepeats(nextConfig.repeats)
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
        let presentation = MenuPresentation(
            phase: model.phase,
            workSeconds: model.workSeconds,
            breakSeconds: model.breakSeconds
        )

        stateItem.title = stateTitle(for: presentation.state)
        configurePrimaryAction(for: presentation.primaryAction)
        stopItem.isHidden = !presentation.stopVisible

        guard let button = statusItem.button else { return }

        switch presentation.state {
        case .idle:
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: L10n.string("tooltip.app"))
            image?.isTemplate = true
            button.image = image
            button.toolTip = L10n.string("tooltip.app")
            stateItem.image = Self.menuSymbol("timer")

        case .working(let remaining):
            button.image = Self.makeRingImage(progress: CGFloat(presentation.progress))
            button.toolTip = L10n.string("tooltip.work", formatClock(remaining))
            stateItem.image = Self.menuSymbol("timer")

        case .onBreak(let remaining):
            button.image = Self.makeRingImage(progress: CGFloat(presentation.progress))
            button.toolTip = L10n.string("tooltip.break", formatClock(remaining))
            stateItem.image = Self.menuSymbol("pause.circle")

        case .paused(let remaining):
            button.image = Self.makeRingImage(progress: CGFloat(presentation.progress))
            button.toolTip = L10n.string("tooltip.paused", formatClock(remaining))
            stateItem.image = Self.menuSymbol("pause.circle")
        }

        button.setAccessibilityLabel(button.toolTip)
    }

    private func configurePrimaryAction(for action: MenuPrimaryAction) {
        startItem.isEnabled = true
        startItem.title = L10n.string(action.localizationKey)
        startItem.image = Self.menuSymbol(action.symbolName)

        switch action {
        case .start, .resume:
            startItem.action = #selector(start)
        case .pause:
            startItem.action = #selector(pause)
        case .endBreak:
            startItem.action = #selector(skipBreak)
        }
    }

    private func stateTitle(for state: MenuStateKind) -> String {
        switch state {
        case .idle:
            return L10n.string("menu.idle")
        case .working(let remaining):
            return L10n.string("state.working", formatClock(remaining))
        case .onBreak(let remaining):
            return L10n.string("state.break", formatClock(remaining))
        case .paused(let remaining):
            return L10n.string("state.paused", formatClock(remaining))
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
