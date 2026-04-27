import AppKit
import DelayNoMoreCore
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: #selector(pause), keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "Reset", action: #selector(reset), keyEquivalent: "")
    private let setImageItem = NSMenuItem(title: "Set Image...", action: #selector(setImage), keyEquivalent: "")
    private let setWorkDurationItem = NSMenuItem(title: "Set Work Duration...", action: #selector(setWorkDuration), keyEquivalent: "")
    private let setBreakDurationItem = NSMenuItem(title: "Set Break Duration...", action: #selector(setBreakDuration), keyEquivalent: "")
    private let skipBreakItem = NSMenuItem(title: "Skip Break", action: #selector(skipBreak), keyEquivalent: "")

    private let store = ConfigStore()
    private var config = AppConfig.default
    private var model = TimerModel(config: .default)
    private var timer: Timer?
    private var reminderController: ReminderWindowController?

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

        [startItem, pauseItem, resetItem, setImageItem, setWorkDurationItem, setBreakDurationItem, skipBreakItem].forEach {
            $0.target = self
        }

        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(startItem)
        menu.addItem(pauseItem)
        menu.addItem(resetItem)
        menu.addItem(skipBreakItem)
        menu.addItem(.separator())
        menu.addItem(setImageItem)
        menu.addItem(setWorkDurationItem)
        menu.addItem(setBreakDurationItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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
            showReminderOrPromptForImage()
        case .finishedRest:
            reminderController?.dismiss(animated: true)
        case .none:
            break
        }

        updateMenu()
    }

    @objc private func start() {
        guard validImagePath() != nil || chooseImage() else {
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

    @objc private func reset() {
        reminderController?.dismiss(animated: false)
        model.reset(started: validImagePath() != nil)
        updateMenu()
    }

    @objc private func setImage() {
        _ = chooseImage()
        updateMenu()
    }

    @objc private func setWorkDuration() {
        guard let minutes = promptForMinutes(
            title: "Set Work Duration",
            message: "Enter a work duration from 1 to 240 minutes.",
            currentValue: config.workMinutes,
            range: AppConfig.workMinuteRange
        ) else {
            return
        }

        do {
            var nextConfig = config
            var nextModel = model
            try nextConfig.setWorkMinutes(minutes)
            try nextModel.setWorkMinutes(minutes)
            config = nextConfig
            model = nextModel
            saveConfig()
        } catch {
            showAlert(title: "Invalid Duration", message: error.localizedDescription)
        }

        updateMenu()
    }

    @objc private func setBreakDuration() {
        guard let minutes = promptForMinutes(
            title: "Set Break Duration",
            message: "Enter a break duration from 1 to 60 minutes.",
            currentValue: config.breakMinutes,
            range: AppConfig.breakMinuteRange
        ) else {
            return
        }

        do {
            var nextConfig = config
            var nextModel = model
            try nextConfig.setBreakMinutes(minutes)
            try nextModel.setBreakMinutes(minutes)
            config = nextConfig
            model = nextModel
            saveConfig()
        } catch {
            showAlert(title: "Invalid Duration", message: error.localizedDescription)
        }

        updateMenu()
    }

    @objc private func skipBreak() {
        endBreakEarly()
    }

    private func endBreakEarly() {
        if model.skipRest() == .finishedRest {
            reminderController?.dismiss(animated: true)
        }
        updateMenu()
    }

    private func showReminderOrPromptForImage() {
        guard let imagePath = validImagePath() else {
            showAlert(
                title: "Choose a Reminder Image",
                message: "DelayNoMore needs a valid image before it can show break reminders."
            )

            guard chooseImage(), let imagePath = validImagePath() else {
                _ = model.skipRest()
                return
            }

            _ = reminderController?.showImage(at: imagePath)
            return
        }

        if reminderController?.showImage(at: imagePath) != true {
            showAlert(
                title: "Image Could Not Be Loaded",
                message: "Choose another reminder image to continue."
            )

            guard chooseImage(), let imagePath = validImagePath() else {
                _ = model.skipRest()
                return
            }

            _ = reminderController?.showImage(at: imagePath)
        }
    }

    private func chooseImage() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose Reminder Image"
        panel.message = "Choose an image to show during breaks."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        guard NSImage(contentsOf: url) != nil else {
            showAlert(title: "Unsupported Image", message: "Choose a file macOS can load as an image.")
            return false
        }

        config.imagePath = url.path
        saveConfig()
        return true
    }

    private func validImagePath() -> String? {
        guard let path = config.imagePath, NSImage(contentsOfFile: path) != nil else {
            return nil
        }

        return path
    }

    private func saveConfig() {
        do {
            try store.save(config)
        } catch {
            showAlert(title: "Could Not Save Settings", message: error.localizedDescription)
        }
    }

    private func promptForMinutes(title: String, message: String, currentValue: Int, range: ClosedRange<Int>) -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = String(currentValue)
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), range.contains(minutes) else {
            showAlert(
                title: "Invalid Duration",
                message: "Enter a whole number from \(range.lowerBound) to \(range.upperBound)."
            )
            return nil
        }

        return minutes
    }

    private func updateMenu() {
        stateItem.title = stateTitle
        startItem.title = model.phase.isPaused ? "Resume" : "Start"
        startItem.isEnabled = !model.phase.isRunning
        pauseItem.isEnabled = model.phase.isRunning
        skipBreakItem.isEnabled = model.phase.isRestLike

        if let button = statusItem.button {
            let status = statusItemPresentation
            let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: status.accessibilityDescription)
            image?.isTemplate = true

            button.image = image
            button.title = status.title.isEmpty ? "" : " \(status.title)"
            button.toolTip = status.accessibilityDescription
            button.setAccessibilityLabel(status.accessibilityDescription)
        }
    }

    private var stateTitle: String {
        switch model.phase {
        case .idle:
            return "Idle"
        case .work(let remainingSeconds):
            return "Work \(formatClock(remainingSeconds))"
        case .rest(let remainingSeconds):
            return "Break \(formatClock(remainingSeconds))"
        case .paused(let previous):
            switch previous {
            case .work(let remainingSeconds):
                return "Paused Work \(formatClock(remainingSeconds))"
            case .rest(let remainingSeconds):
                return "Paused Break \(formatClock(remainingSeconds))"
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
}
