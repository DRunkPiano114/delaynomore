import AppKit

final class ReminderWindowController {
    private var window: ReminderWindow?
    private let onUserClose: () -> Void

    init(onUserClose: @escaping () -> Void) {
        self.onUserClose = onUserClose
    }

    func showImage(at path: String) -> Bool {
        guard let image = NSImage(contentsOfFile: path), let screen = targetScreen() else {
            return false
        }

        dismiss(animated: false)

        let targetFrame = Self.targetFrame(for: screen)
        let startFrame = targetFrame.offsetBy(dx: 0, dy: -(targetFrame.height + 32))
        let imageView = ReminderImageView(frame: NSRect(origin: .zero, size: targetFrame.size))
        imageView.image = image
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.onClick = { [weak self] in
            self?.onUserClose()
        }

        let window = ReminderWindow(
            contentRect: startFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "DelayNoMore Break"
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.contentView = imageView
        window.onEscape = { [weak self] in
            self?.onUserClose()
        }

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(targetFrame, display: true)
        }

        return true
    }

    func dismiss(animated: Bool) {
        guard let window else {
            return
        }

        let closeWindow = { [weak self] in
            window.orderOut(nil)
            window.close()
            if self?.window === window {
                self?.window = nil
            }
        }

        guard animated else {
            closeWindow()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        } completionHandler: {
            closeWindow()
        }
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation

        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func targetFrame(for screen: NSScreen) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let width = visibleFrame.width * 0.55
        let height = visibleFrame.height * 0.55

        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private final class ReminderWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }
}

private final class ReminderImageView: NSImageView {
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
}
