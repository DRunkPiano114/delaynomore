import AppKit
import DelayNoMoreCore
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let onChange: (AppConfig) -> Void
    private var config: AppConfig

    private let imageNameField = NSTextField(labelWithString: "")
    private let imagePreviewView = NSImageView()
    private let workField = NSTextField()
    private let breakField = NSTextField()
    private let workStepper = NSStepper()
    private let breakStepper = NSStepper()

    init(config: AppConfig, onChange: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onChange = onChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 318),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSView()

        super.init(window: window)

        buildContent()
        update(config: config)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(config: AppConfig) {
        self.config = config

        imageNameField.stringValue = imageTitle(for: config.imagePath)
        imageNameField.textColor = validImagePath(config.imagePath) == nil ? .tertiaryLabelColor : .secondaryLabelColor
        updateImagePreview(path: config.imagePath)

        workField.integerValue = config.workMinutes
        workStepper.integerValue = config.workMinutes
        breakField.integerValue = config.breakMinutes
        breakStepper.integerValue = config.breakMinutes
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let title = NSTextField(labelWithString: "Settings")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(makeImageSection())
        stack.addArrangedSubview(makeDurationsSection())

        let doneButton = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"

        let footer = NSStackView(views: [NSView(), doneButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 0
        footer.widthAnchor.constraint(equalToConstant: 374).isActive = true
        stack.addArrangedSubview(footer)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    private func makeImageSection() -> NSView {
        imagePreviewView.imageAlignment = .alignCenter
        imagePreviewView.imageScaling = .scaleProportionallyUpOrDown
        imagePreviewView.wantsLayer = true
        imagePreviewView.layer?.cornerRadius = 10
        imagePreviewView.layer?.masksToBounds = true
        imagePreviewView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        imagePreviewView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        imagePreviewView.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let label = NSTextField(labelWithString: "Reminder Image")
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)

        imageNameField.lineBreakMode = .byTruncatingMiddle
        imageNameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageNameField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let textStack = NSStackView(views: [label, imageNameField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chooseButton = NSButton(title: "Choose...", target: self, action: #selector(chooseImage))
        chooseButton.bezelStyle = .rounded
        chooseButton.image = Self.symbol("photo")
        chooseButton.imagePosition = .imageLeading

        let row = NSStackView(views: [imagePreviewView, textStack, chooseButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14

        return makeBox(containing: row, height: 74)
    }

    private func makeDurationsSection() -> NSView {
        let workRow = makeDurationRow(
            title: "Work",
            symbolName: "timer",
            field: workField,
            stepper: workStepper,
            range: AppConfig.workMinuteRange
        )
        let breakRow = makeDurationRow(
            title: "Break",
            symbolName: "pause.circle",
            field: breakField,
            stepper: breakStepper,
            range: AppConfig.breakMinuteRange
        )
        let separator = makeSeparator()

        let stack = NSStackView(views: [workRow, separator, breakRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        return makeBox(containing: stack, height: 106)
    }

    private func makeDurationRow(
        title: String,
        symbolName: String,
        field: NSTextField,
        stepper: NSStepper,
        range: ClosedRange<Int>
    ) -> NSView {
        field.alignment = .right
        field.bezelStyle = .roundedBezel
        field.delegate = self
        field.target = self
        field.action = #selector(durationFieldChanged)
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let minuteLabel = NSTextField(labelWithString: "min")
        minuteLabel.textColor = .secondaryLabelColor

        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(stepperChanged)

        let icon = NSImageView(image: Self.symbol(symbolName) ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.widthAnchor.constraint(equalToConstant: 178).isActive = true

        let labelStack = NSStackView(views: [icon, label])
        labelStack.orientation = .horizontal
        labelStack.alignment = .centerY
        labelStack.spacing = 9

        let control = NSStackView(views: [field, minuteLabel, stepper])
        control.orientation = .horizontal
        control.alignment = .centerY
        control.spacing = 8

        let row = NSStackView(views: [labelStack, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 342).isActive = true
        return row
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.widthAnchor.constraint(equalToConstant: 342).isActive = true
        return separator
    }

    private func makeBox(containing view: NSView, height: CGFloat) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor
        box.cornerRadius = 12
        box.contentViewMargins = NSSize(width: 16, height: 12)
        box.widthAnchor.constraint(equalToConstant: 374).isActive = true
        box.heightAnchor.constraint(equalToConstant: height).isActive = true

        guard let contentView = box.contentView else {
            return box
        }

        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        return box
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Reminder Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard let window else {
            runImagePanel(panel)
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            self?.applyImage(url)
        }
    }

    private func runImagePanel(_ panel: NSOpenPanel) {
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        applyImage(url)
    }

    private func applyImage(_ url: URL) {
        guard NSImage(contentsOf: url) != nil else {
            showAlert(title: "Unsupported Image", message: "Choose a file macOS can load as an image.")
            return
        }

        var nextConfig = config
        nextConfig.imagePath = url.path
        apply(nextConfig)
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        if sender === workStepper {
            applyWorkMinutes(sender.integerValue)
        } else if sender === breakStepper {
            applyBreakMinutes(sender.integerValue)
        }
    }

    @objc private func durationFieldChanged(_ sender: NSTextField) {
        applyDurationField(sender)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else {
            return
        }

        applyDurationField(field)
    }

    private func applyDurationField(_ field: NSTextField) {
        if field === workField {
            applyWorkMinutes(clamped(field.integerValue, to: AppConfig.workMinuteRange))
        } else if field === breakField {
            applyBreakMinutes(clamped(field.integerValue, to: AppConfig.breakMinuteRange))
        }
    }

    private func applyWorkMinutes(_ minutes: Int) {
        var nextConfig = config
        nextConfig.workMinutes = clamped(minutes, to: AppConfig.workMinuteRange)
        apply(nextConfig)
    }

    private func applyBreakMinutes(_ minutes: Int) {
        var nextConfig = config
        nextConfig.breakMinutes = clamped(minutes, to: AppConfig.breakMinuteRange)
        apply(nextConfig)
    }

    private func apply(_ nextConfig: AppConfig) {
        config = nextConfig
        update(config: nextConfig)
        onChange(nextConfig)
    }

    private func imageTitle(for path: String?) -> String {
        guard let path, validImagePath(path) != nil else {
            return "None"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func updateImagePreview(path: String?) {
        if let path, let image = NSImage(contentsOfFile: path) {
            imagePreviewView.image = image
            imagePreviewView.contentTintColor = nil
        } else {
            imagePreviewView.image = Self.symbol("photo")
            imagePreviewView.contentTintColor = .tertiaryLabelColor
        }
    }

    private func validImagePath(_ path: String?) -> String? {
        guard let path, NSImage(contentsOfFile: path) != nil else {
            return nil
        }

        return path
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
