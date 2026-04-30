import AppKit
import SwiftUI
import Sparkle
import DelayNoMoreCore

final class SettingsWindowController: NSWindowController {
    private let onChange: (AppConfig) -> Void
    private let store: SettingsStore
    private let updater: SPUUpdater

    init(config: AppConfig, updater: SPUUpdater, onChange: @escaping (AppConfig) -> Void) {
        self.onChange = onChange
        self.store = SettingsStore(config: config)
        self.updater = updater

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.string("settings.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = CozyPalette.paperNS
        window.appearance = NSAppearance(named: .aqua)

        super.init(window: window)

        let view = SettingsView(
            store: store,
            onChange: onChange,
            onDismiss: { [weak self] in self?.window?.close() },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() }
        )
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(config: AppConfig) {
        store.config = config
    }

    private func checkForUpdates() {
        updater.checkForUpdates()
    }
}
