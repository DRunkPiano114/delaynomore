import AppKit
import AVFoundation
import AVKit
import DelayNoMoreCore

final class ReminderWindowController {
    private var window: NSWindow?
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    func show(media: ReminderMedia) -> Bool {
        guard let asset = ReminderMediaLibrary.asset(for: media), let screen = targetScreen() else {
            return false
        }

        dismiss(animated: false)

        let overlayFrame = screen.visibleFrame
        let naturalSize = Self.naturalSize(for: asset)
        let mediaSize = Self.targetSize(
            for: naturalSize,
            maxSize: NSSize(width: overlayFrame.width * 0.55, height: overlayFrame.height * 0.55)
        )
        let mediaFrame = NSRect(
            x: (overlayFrame.width - mediaSize.width) / 2,
            y: (overlayFrame.height - mediaSize.height) / 2,
            width: mediaSize.width,
            height: mediaSize.height
        )

        let renderedContent = Self.makeContentView(
            size: overlayFrame.size,
            asset: asset,
            mediaFrame: mediaFrame
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
        window.contentView = renderedContent.view

        self.window = window
        player = renderedContent.player
        playerLooper = renderedContent.playerLooper

        window.orderFrontRegardless()
        player?.play()

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
            self?.player?.pause()
            self?.player = nil
            self?.playerLooper = nil
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

    private static func targetSize(for mediaSize: NSSize, maxSize: NSSize) -> NSSize {
        guard mediaSize.width > 0, mediaSize.height > 0 else {
            return maxSize
        }

        let scale = min(maxSize.width / mediaSize.width, maxSize.height / mediaSize.height)
        return NSSize(width: mediaSize.width * scale, height: mediaSize.height * scale)
    }

    private static func naturalSize(for asset: ReminderMediaAsset) -> NSSize {
        switch asset {
        case .image(let image):
            return image.size
        case .video(let url):
            return videoSize(for: url) ?? NSSize(width: 16, height: 9)
        }
    }

    private static func videoSize(for url: URL) -> NSSize? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }

        return NSSize(width: image.width, height: image.height)
    }

    private static func makeContentView(
        size: NSSize,
        asset: ReminderMediaAsset,
        mediaFrame: NSRect
    ) -> (view: NSView, player: AVQueuePlayer?, playerLooper: AVPlayerLooper?) {
        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor

        let shadowView = NSView(frame: mediaFrame)
        shadowView.wantsLayer = true
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.28
        shadowView.layer?.shadowRadius = 22
        shadowView.layer?.shadowOffset = NSSize(width: 0, height: -8)

        let mediaClipView = NSView(frame: shadowView.bounds)
        mediaClipView.wantsLayer = true
        mediaClipView.layer?.cornerRadius = 18
        mediaClipView.layer?.masksToBounds = true

        var player: AVQueuePlayer?
        var playerLooper: AVPlayerLooper?

        switch asset {
        case .image(let image):
            let imageView = NSImageView(frame: mediaClipView.bounds)
            imageView.image = image
            imageView.imageAlignment = .alignCenter
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.autoresizingMask = [.width, .height]
            mediaClipView.addSubview(imageView)
        case .video(let url):
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true

            let playerView = AVPlayerView(frame: mediaClipView.bounds)
            playerView.autoresizingMask = [.width, .height]
            playerView.controlsStyle = .none
            playerView.videoGravity = .resizeAspectFill
            playerView.player = queuePlayer

            let item = AVPlayerItem(url: url)
            player = queuePlayer
            playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            mediaClipView.addSubview(playerView)
        }

        shadowView.addSubview(mediaClipView)
        contentView.addSubview(shadowView)

        return (contentView, player, playerLooper)
    }
}
