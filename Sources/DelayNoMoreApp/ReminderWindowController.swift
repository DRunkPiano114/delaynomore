import AppKit

final class ReminderWindowController {
    private var window: NSWindow?

    func showImage(at path: String) -> Bool {
        guard let image = NSImage(contentsOfFile: path), let screen = targetScreen() else {
            return false
        }

        dismiss(animated: false)

        let overlayFrame = screen.visibleFrame
        let imageSize = Self.targetSize(
            for: image.size,
            maxSize: NSSize(width: overlayFrame.width * 0.55, height: overlayFrame.height * 0.55)
        )
        let imageFrame = NSRect(
            x: (overlayFrame.width - imageSize.width) / 2,
            y: (overlayFrame.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )

        let contentView = Self.makeContentView(
            size: overlayFrame.size,
            image: image,
            imageFrame: imageFrame
        )

        let window = NSPanel(
            contentRect: overlayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "DelayNoMore Break"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.alphaValue = 0
        window.contentView = contentView

        self.window = window

        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
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

    private static func targetSize(for imageSize: NSSize, maxSize: NSSize) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return maxSize
        }

        let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height)
        return NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private static func makeContentView(
        size: NSSize,
        image: NSImage,
        imageFrame: NSRect
    ) -> NSView {
        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor

        let shadowView = NSView(frame: imageFrame)
        shadowView.wantsLayer = true
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.28
        shadowView.layer?.shadowRadius = 22
        shadowView.layer?.shadowOffset = NSSize(width: 0, height: -8)

        let imageClipView = NSView(frame: shadowView.bounds)
        imageClipView.wantsLayer = true
        imageClipView.layer?.cornerRadius = 18
        imageClipView.layer?.masksToBounds = true

        let imageView = NSImageView(frame: imageClipView.bounds)
        imageView.image = image
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]

        imageClipView.addSubview(imageView)
        shadowView.addSubview(imageClipView)
        contentView.addSubview(shadowView)

        return contentView
    }
}
