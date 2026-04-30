import AppKit
import AVFoundation
import DelayNoMoreCore
import DelayNoMoreAppResources
import UniformTypeIdentifiers

@MainActor
enum MediaImportCoordinator {
    static func presentChooser(anchor: NSWindow?) async -> ReminderMedia? {
        let panel = NSOpenPanel()
        panel.title = L10n.string("panel.chooseMedia.title")
        panel.message = L10n.string("panel.chooseMedia.message")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ReminderMediaLibrary.allowedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return await runImport(from: url, anchor: anchor)
    }

    static func runImport(from source: URL, anchor: NSWindow?) async -> ReminderMedia? {
        guard let kind = mediaKind(for: source) else {
            showAlert(
                title: L10n.string("alert.unsupportedMedia.title"),
                message: L10n.string("alert.unsupportedMedia.message")
            )
            return nil
        }

        switch kind {
        case .image:
            return importImage(from: source)
        case .video:
            let info = await CustomMediaStore.videoInfo(at: source)
            if CustomMediaStore.videoNeedsWarning(info),
               !confirmOversizedVideo(info: info) {
                return nil
            }
            return await importVideo(from: source, anchor: anchor)
        }
    }

    private enum Kind { case image, video }

    private static func mediaKind(for url: URL) -> Kind? {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        return nil
    }

    private static func importImage(from source: URL) -> ReminderMedia? {
        let directory = CustomMediaStore.defaultStorageDirectory()
        do {
            let outputURL = try CustomMediaStore.importImage(from: source, into: directory)
            CustomMediaStore.reapOrphans(in: directory, keep: outputURL)
            return .customImage(path: outputURL.path)
        } catch {
            showAlert(
                title: L10n.string("alert.importFailed.title"),
                message: L10n.string("alert.importFailed.message")
            )
            return nil
        }
    }

    private static func importVideo(from source: URL, anchor: NSWindow?) async -> ReminderMedia? {
        let directory = CustomMediaStore.defaultStorageDirectory()
        let sheet = ProgressSheet(message: L10n.string("import.progress.message"))
        sheet.present(over: anchor)

        do {
            let outputURL = try await Task.detached(priority: .userInitiated) {
                try CustomMediaStore.importVideo(from: source, into: directory)
            }.value

            CustomMediaStore.reapOrphans(in: directory, keep: outputURL)
            sheet.dismiss()
            return .customVideo(path: outputURL.path)
        } catch {
            sheet.dismiss()
            showAlert(
                title: L10n.string("alert.importFailed.title"),
                message: L10n.string("alert.importFailed.message")
            )
            return nil
        }
    }

    private static func confirmOversizedVideo(info: VideoInfo) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.largeVideo.title")
        alert.informativeText = formatLargeVideoMessage(info: info)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("button.continue"))
        alert.addButton(withTitle: L10n.string("button.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func formatLargeVideoMessage(info: VideoInfo) -> String {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = [.useMB, .useGB]
        byteFormatter.countStyle = .file
        let sizeText = byteFormatter.string(fromByteCount: info.bytes)
        let minutes = max(1, Int((info.durationSeconds / 60).rounded()))
        return L10n.string("alert.largeVideo.message", sizeText, minutes)
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("button.ok"))
        alert.runModal()
    }
}

@MainActor
private final class ProgressSheet {
    private let window: NSWindow
    private weak var anchor: NSWindow?

    init(message: String) {
        let contentSize = NSSize(width: 320, height: 92)
        let contentView = NSView(frame: NSRect(origin: .zero, size: contentSize))

        let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 30, width: 32, height: 32))
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 70, y: 36, width: 230, height: 20)
        contentView.addSubview(label)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        self.window = window
    }

    func present(over parent: NSWindow?) {
        anchor = parent
        if let parent {
            parent.beginSheet(window) { _ in }
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func dismiss() {
        if let anchor {
            anchor.endSheet(window)
        } else {
            window.orderOut(nil)
        }
        anchor = nil
    }
}
