import AppKit
import SwiftUI
import DelayNoMoreCore

private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

final class SettingsWindowController: NSWindowController {
    private let onChange: (AppConfig) -> Void
    private let store: SettingsStore

    init(config: AppConfig, onChange: @escaping (AppConfig) -> Void) {
        self.onChange = onChange
        self.store = SettingsStore(config: config)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

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
        store.isCheckingForUpdates = true

        let url = URL(string: "https://api.github.com/repos/DRunkPiano114/delaynomore/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.store.isCheckingForUpdates = false

                guard let data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    self?.showAlert(title: "Update Check Failed", message: "Could not reach GitHub. Try again later.")
                    return
                }

                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if remoteVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "A new version (\(remoteVersion)) is available. You are running \(currentVersion)."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")

                    if let window = self?.window {
                        alert.beginSheetModal(for: window) { response in
                            if response == .alertFirstButtonReturn, let url = URL(string: htmlURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                } else {
                    self?.showAlert(title: "You're Up to Date", message: "DelayNoMore \(currentVersion) is the latest version.")
                }
            }
        }.resume()
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
}
