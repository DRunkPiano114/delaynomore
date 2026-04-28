import AppKit
import AVFoundation
import AVKit
import DelayNoMoreCore

final class ReminderWindowController {
    private struct Surface {
        let window: NSWindow
        let countdownLabel: NSTextField
        let player: AVQueuePlayer?
        let playerLooper: AVPlayerLooper?
    }

    private var surfaces: [Surface] = []

    func show(media: ReminderMedia) -> Bool {
        guard let asset = ReminderMediaLibrary.asset(for: media) else {
            return false
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return false
        }

        dismiss(animated: false)

        let naturalSize = Self.naturalSize(for: asset)

        for screen in screens {
            let surface = makeSurface(asset: asset, screen: screen, naturalSize: naturalSize)
            surfaces.append(surface)

            surface.window.orderFrontRegardless()
            surface.player?.play()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                surface.window.animator().alphaValue = 1
            }
        }

        return true
    }

    func updateCountdown(_ remainingSeconds: Int) {
        let text = formatClock(remainingSeconds)
        for surface in surfaces {
            surface.countdownLabel.stringValue = text
        }
    }

    func dismiss(animated: Bool) {
        guard !surfaces.isEmpty else {
            return
        }

        let toDismiss = surfaces
        surfaces = []

        let closeAll = {
            for surface in toDismiss {
                surface.player?.pause()
                surface.window.orderOut(nil)
                surface.window.close()
            }
        }

        guard animated else {
            closeAll()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            for surface in toDismiss {
                surface.window.animator().alphaValue = 0
            }
        } completionHandler: {
            closeAll()
        }
    }

    private func makeSurface(asset: ReminderMediaAsset, screen: NSScreen, naturalSize: NSSize) -> Surface {
        let overlayFrame = screen.visibleFrame
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

        let countdown = NSTextField(labelWithString: "")
        countdown.font = .monospacedDigitSystemFont(ofSize: 48, weight: .medium)
        countdown.textColor = NSColor.white.withAlphaComponent(0.7)
        countdown.alignment = .center
        countdown.frame = NSRect(
            x: 0,
            y: mediaFrame.minY - 72,
            width: overlayFrame.width,
            height: 56
        )
        renderedContent.view.addSubview(countdown)

        return Surface(
            window: window,
            countdownLabel: countdown,
            player: renderedContent.player,
            playerLooper: renderedContent.playerLooper
        )
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
