import AppKit
import DelayNoMoreCore

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let onChange: (AppConfig) -> Void
    private var config: AppConfig

    private var reminderTiles: [ReminderTile] = []
    private let workField = NSTextField()
    private let breakField = NSTextField()
    private let workStepper = NSStepper()
    private let breakStepper = NSStepper()

    init(config: AppConfig, onChange: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onChange = onChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
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

        refreshReminderTiles()

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
        stack.addArrangedSubview(makeMediaSection())
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

    private func makeMediaSection() -> NSView {
        let label = NSTextField(labelWithString: "Reminder Media")
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)

        reminderTiles = makeReminderTiles()
        let grid = makeReminderGrid(tiles: reminderTiles)

        let stack = NSStackView(views: [label, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        let gridHeight = Self.reminderGridHeight(forTileCount: reminderTiles.count)
        return makeBox(containing: stack, height: Self.reminderMediaLabelHeight + Self.reminderMediaSpacing + gridHeight)
    }

    private func makeReminderTiles() -> [ReminderTile] {
        var tiles: [ReminderTile] = []

        for builtIn in ReminderMediaLibrary.builtIns {
            let media = ReminderMedia.builtIn(id: builtIn.id)
            guard ReminderMediaLibrary.isAvailable(media) else {
                continue
            }

            let tile = ReminderTile(kind: .builtIn(builtIn.id), title: builtIn.title)
            tile.image = ReminderMediaLibrary.previewImage(for: media)
            tile.onClick = { [weak self] in self?.selectBuiltIn(id: builtIn.id) }
            tiles.append(tile)
        }

        let customTile = ReminderTile(kind: .custom, title: "Custom...")
        customTile.onClick = { [weak self] in self?.chooseMedia() }
        tiles.append(customTile)

        return tiles
    }

    private func makeReminderGrid(tiles: [ReminderTile]) -> NSView {
        let rows = Self.reminderGridRowCount(forTileCount: tiles.count)

        var rowStacks: [NSStackView] = []
        for rowIndex in 0..<rows {
            let start = rowIndex * Self.reminderGridColumns
            let end = min(start + Self.reminderGridColumns, tiles.count)
            let rowTiles = Array(tiles[start..<end])

            var rowViews: [NSView] = rowTiles
            while rowViews.count < Self.reminderGridColumns {
                rowViews.append(NSView())
            }

            let rowStack = NSStackView(views: rowViews)
            rowStack.orientation = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = Self.reminderGridSpacing
            rowStack.widthAnchor.constraint(equalToConstant: Self.reminderGridWidth).isActive = true
            rowStack.heightAnchor.constraint(equalToConstant: Self.reminderTileHeight).isActive = true
            rowStacks.append(rowStack)
        }

        let grid = NSStackView(views: rowStacks)
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = Self.reminderGridSpacing
        grid.widthAnchor.constraint(equalToConstant: Self.reminderGridWidth).isActive = true
        grid.heightAnchor.constraint(equalToConstant: Self.reminderGridHeight(forTileCount: tiles.count)).isActive = true
        return grid
    }

    private func refreshReminderTiles() {
        for tile in reminderTiles {
            tile.isSelected = isCurrentSelection(tile.tileKind)
            if case .custom = tile.tileKind {
                updateCustomTile(tile)
            }
        }
    }

    private func updateCustomTile(_ tile: ReminderTile) {
        let isCustom = config.reminder?.kind == .customImage || config.reminder?.kind == .customVideo

        if isCustom, let media = config.reminder, let preview = ReminderMediaLibrary.previewImage(for: media) {
            tile.image = preview
            tile.title = ReminderMediaLibrary.title(for: media)
        } else {
            tile.image = nil
            tile.title = "Custom..."
        }
    }

    private func isCurrentSelection(_ identifier: ReminderTile.Kind) -> Bool {
        switch identifier {
        case .builtIn(let id):
            guard let reminder = config.reminder, reminder.kind == .builtIn else {
                return false
            }
            return reminder.identifier == id
        case .custom:
            return config.reminder?.kind == .customImage || config.reminder?.kind == .customVideo
        }
    }

    private func selectBuiltIn(id: String) {
        var nextConfig = config
        nextConfig.reminder = .builtIn(id: id)
        apply(nextConfig)
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

    private func chooseMedia() {
        let panel = NSOpenPanel()
        panel.title = "Choose Reminder Media"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ReminderMediaLibrary.allowedContentTypes

        guard let window else {
            runMediaPanel(panel)
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            self?.applyMedia(url)
        }
    }

    private func runMediaPanel(_ panel: NSOpenPanel) {
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        applyMedia(url)
    }

    private func applyMedia(_ url: URL) {
        guard let reminder = ReminderMediaLibrary.media(for: url) else {
            showAlert(title: "Unsupported Media", message: "Choose an image or video macOS can load.")
            return
        }

        var nextConfig = config
        nextConfig.reminder = reminder
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

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static let reminderGridColumns = 3
    private static let reminderGridWidth: CGFloat = 342
    private static let reminderGridSpacing: CGFloat = 8
    private static let reminderMediaLabelHeight: CGFloat = 18
    private static let reminderMediaSpacing: CGFloat = 10

    private static var reminderTileWidth: CGFloat {
        let totalSpacing = reminderGridSpacing * CGFloat(reminderGridColumns - 1)
        return (reminderGridWidth - totalSpacing) / CGFloat(reminderGridColumns)
    }

    private static var reminderTileHeight: CGFloat {
        ReminderTile.preferredHeight(forWidth: reminderTileWidth)
    }

    private static func reminderGridRowCount(forTileCount tileCount: Int) -> Int {
        max(1, (tileCount + reminderGridColumns - 1) / reminderGridColumns)
    }

    private static func reminderGridHeight(forTileCount tileCount: Int) -> CGFloat {
        let rows = reminderGridRowCount(forTileCount: tileCount)
        let totalSpacing = reminderGridSpacing * CGFloat(max(0, rows - 1))
        return reminderTileHeight * CGFloat(rows) + totalSpacing
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

final class ReminderTile: NSView {
    enum Kind: Equatable {
        case builtIn(String)
        case custom
    }

    let tileKind: Kind
    var onClick: (() -> Void)?

    var image: NSImage? {
        didSet { imageView.image = image; updatePlaceholder() }
    }

    var title: String {
        didSet { titleLabel.stringValue = title }
    }

    var isSelected: Bool = false {
        didSet { updateSelectionAppearance() }
    }

    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let placeholderView = NSImageView()
    private let imageContainer = NSView()

    private static let titleSpacing: CGFloat = 4
    private static let titleHeight: CGFloat = 16

    static func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        width * 9.0 / 16.0 + titleSpacing + titleHeight
    }

    init(kind: Kind, title: String) {
        self.tileKind = kind
        self.title = title
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        imageContainer.wantsLayer = true
        imageContainer.layer?.cornerRadius = 8
        imageContainer.layer?.masksToBounds = true
        imageContainer.layer?.borderWidth = 2
        imageContainer.layer?.borderColor = NSColor.clear.cgColor
        imageContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        imageContainer.translatesAutoresizingMaskIntoConstraints = false

        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        placeholderView.image = NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: nil)
        placeholderView.contentTintColor = .tertiaryLabelColor
        placeholderView.imageScaling = .scaleProportionallyDown
        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        imageContainer.addSubview(imageView)
        imageContainer.addSubview(placeholderView)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageContainer)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: 9.0 / 16.0),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            placeholderView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            placeholderView.widthAnchor.constraint(equalToConstant: 22),
            placeholderView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: Self.titleSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: Self.titleHeight),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updatePlaceholder()
        updateSelectionAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, bounds.contains(point) else {
            return nil
        }

        return self
    }

    override func updateLayer() {
        super.updateLayer()
        updateSelectionAppearance()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func updatePlaceholder() {
        placeholderView.isHidden = image != nil
        imageView.isHidden = image == nil
    }

    private func updateSelectionAppearance() {
        let borderColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        imageContainer.layer?.borderColor = borderColor
        imageContainer.layer?.borderWidth = isSelected ? 2.5 : 1
    }
}
