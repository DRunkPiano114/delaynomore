import AppKit
import AVFoundation
import AVKit
import DelayNoMoreCore
import QuartzCore

final class ReminderWindowController {
    private final class Surface {
        let window: NSWindow
        let backdropView: NSView
        let dimView: NSView
        let haloLayer: CAGradientLayer
        let mediaContainer: NSView
        let promptLabel: NSTextField
        let countdownLabel: NSTextField
        let player: AVQueuePlayer?
        let playerLooper: AVPlayerLooper?
        var isClosing = false

        init(
            window: NSWindow,
            backdropView: NSView,
            dimView: NSView,
            haloLayer: CAGradientLayer,
            mediaContainer: NSView,
            promptLabel: NSTextField,
            countdownLabel: NSTextField,
            player: AVQueuePlayer?,
            playerLooper: AVPlayerLooper?
        ) {
            self.window = window
            self.backdropView = backdropView
            self.dimView = dimView
            self.haloLayer = haloLayer
            self.mediaContainer = mediaContainer
            self.promptLabel = promptLabel
            self.countdownLabel = countdownLabel
            self.player = player
            self.playerLooper = playerLooper
        }
    }

    private struct RenderedContent {
        let view: NSView
        let backdropView: NSView
        let dimView: NSView
        let haloLayer: CAGradientLayer
        let mediaContainer: NSView
        let promptLabel: NSTextField
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
        let prompt = Self.randomBreakPrompt()

        for screen in screens {
            let surface = makeSurface(asset: asset, screen: screen, naturalSize: naturalSize, prompt: prompt)
            surfaces.append(surface)

            surface.window.orderFrontRegardless()
            surface.player?.play()
            animateIntro(surface)
        }

        return true
    }

    func updateCountdown(_ remainingSeconds: Int) {
        let text = formatClock(remainingSeconds)
        for surface in surfaces {
            surface.countdownLabel.stringValue = text
        }
    }

    func dismiss(animated: Bool, fast: Bool = false) {
        guard !surfaces.isEmpty else {
            return
        }

        let toDismiss = surfaces
        surfaces = []
        toDismiss.forEach { $0.isClosing = true }

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

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                for surface in toDismiss {
                    surface.window.animator().alphaValue = 0
                }
            } completionHandler: {
                closeAll()
            }
            return
        }

        let mediaDuration = fast ? 0.14 : 0.18
        let backdropDelay: TimeInterval = fast ? 0.06 : 0.12
        let backdropDuration = fast ? 0.19 : 0.33
        let closeDelay = backdropDelay + backdropDuration + 0.03

        for surface in toDismiss {
            surface.haloLayer.removeAllAnimations()
            surface.haloLayer.opacity = 0
            Self.animateScaleOut(surface.mediaContainer, duration: mediaDuration)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = mediaDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for surface in toDismiss {
                surface.mediaContainer.animator().alphaValue = 0
                surface.promptLabel.animator().alphaValue = 0
                surface.countdownLabel.animator().alphaValue = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + backdropDelay) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = backdropDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for surface in toDismiss {
                    surface.backdropView.animator().alphaValue = 0
                    surface.dimView.animator().alphaValue = 0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay) {
            closeAll()
        }
    }

    private func makeSurface(asset: ReminderMediaAsset, screen: NSScreen, naturalSize: NSSize, prompt: String) -> Surface {
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
            mediaFrame: mediaFrame,
            prompt: prompt
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
        window.alphaValue = 1
        window.contentView = renderedContent.view

        return Surface(
            window: window,
            backdropView: renderedContent.backdropView,
            dimView: renderedContent.dimView,
            haloLayer: renderedContent.haloLayer,
            mediaContainer: renderedContent.mediaContainer,
            promptLabel: renderedContent.promptLabel,
            countdownLabel: renderedContent.countdownLabel,
            player: renderedContent.player,
            playerLooper: renderedContent.playerLooper
        )
    }

    private func animateIntro(_ surface: Surface) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if reduceMotion {
            surface.backdropView.alphaValue = 1
            surface.dimView.alphaValue = 1
            surface.haloLayer.opacity = 0
            surface.mediaContainer.alphaValue = 1
            surface.mediaContainer.layer?.transform = CATransform3DIdentity
            surface.promptLabel.alphaValue = 1
            surface.countdownLabel.alphaValue = 0.58
            return
        }

        surface.backdropView.alphaValue = 0
        surface.dimView.alphaValue = 0
        surface.haloLayer.opacity = 0
        surface.mediaContainer.alphaValue = 0
        surface.mediaContainer.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1)
        surface.promptLabel.alphaValue = 0
        surface.countdownLabel.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            surface.backdropView.animator().alphaValue = 1
            surface.dimView.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard surface.window.isVisible, !surface.isClosing else { return }
            Self.animateHalo(surface.haloLayer)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard surface.window.isVisible, !surface.isClosing else { return }
            Self.animateScaleIn(surface.mediaContainer)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.75
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                surface.mediaContainer.animator().alphaValue = 1
                surface.promptLabel.animator().alphaValue = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard surface.window.isVisible, !surface.isClosing else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                surface.countdownLabel.animator().alphaValue = 0.58
            }
        }
    }

    private static func animateHalo(_ haloLayer: CAGradientLayer) {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0, 0.92, 0.22, 0]
        animation.keyTimes = [0, 0.28, 0.74, 1]
        animation.duration = 0.9
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeIn)
        ]
        haloLayer.add(animation, forKey: "introHaloOpacity")
    }

    private static func animateScaleIn(_ view: NSView) {
        guard let layer = view.layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.94
        animation.toValue = 1
        animation.duration = 0.75
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer.transform = CATransform3DIdentity
        layer.add(animation, forKey: "introScale")
    }

    private static func animateScaleOut(_ view: NSView, duration: TimeInterval) {
        guard let layer = view.layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = (layer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.doubleValue ?? 1
        animation.toValue = 0.98
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        layer.transform = CATransform3DMakeScale(0.98, 0.98, 1)
        layer.add(animation, forKey: "exitScale")
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
        mediaFrame: NSRect,
        prompt: String
    ) -> RenderedContent {
        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        let backdropView = NSVisualEffectView(frame: contentView.bounds)
        backdropView.autoresizingMask = [.width, .height]
        backdropView.blendingMode = .behindWindow
        backdropView.material = .hudWindow
        backdropView.state = .active
        backdropView.alphaValue = 0
        contentView.addSubview(backdropView)

        let dimView = NSView(frame: contentView.bounds)
        dimView.autoresizingMask = [.width, .height]
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.34).cgColor
        dimView.alphaValue = 0
        contentView.addSubview(dimView)

        let haloLayer = CAGradientLayer()
        haloLayer.type = .radial
        haloLayer.colors = [
            NSColor.white.withAlphaComponent(0.24).cgColor,
            NSColor.systemOrange.withAlphaComponent(0.12).cgColor,
            NSColor.clear.cgColor
        ]
        haloLayer.locations = [0, 0.42, 1]
        haloLayer.opacity = 0
        let haloDiameter = max(mediaFrame.width, mediaFrame.height) * 1.9
        haloLayer.frame = CGRect(
            x: mediaFrame.midX - haloDiameter / 2,
            y: mediaFrame.midY - haloDiameter / 2,
            width: haloDiameter,
            height: haloDiameter
        )
        contentView.layer?.addSublayer(haloLayer)

        let promptLabel = NSTextField(labelWithString: L10n.string("break.intro.format", prompt))
        promptLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        promptLabel.textColor = NSColor.white.withAlphaComponent(0.88)
        promptLabel.alignment = .center
        promptLabel.lineBreakMode = .byWordWrapping
        promptLabel.maximumNumberOfLines = 2
        promptLabel.alphaValue = 0
        promptLabel.frame = NSRect(
            x: 56,
            y: min(mediaFrame.maxY + 26, size.height - 88),
            width: max(0, size.width - 112),
            height: 60
        )
        contentView.addSubview(promptLabel)

        let mediaContainer = NSView(frame: mediaFrame)
        mediaContainer.wantsLayer = true
        mediaContainer.layer?.shadowColor = NSColor.black.cgColor
        mediaContainer.layer?.shadowOpacity = 0.32
        mediaContainer.layer?.shadowRadius = 24
        mediaContainer.layer?.shadowOffset = NSSize(width: 0, height: -8)
        mediaContainer.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1)
        mediaContainer.alphaValue = 0

        let mediaClipView = NSView(frame: mediaContainer.bounds)
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

        mediaContainer.addSubview(mediaClipView)
        contentView.addSubview(mediaContainer)

        let countdown = NSTextField(labelWithString: "")
        countdown.font = .monospacedDigitSystemFont(ofSize: 42, weight: .medium)
        countdown.textColor = NSColor.white.withAlphaComponent(0.7)
        countdown.alignment = .center
        countdown.alphaValue = 0
        countdown.frame = NSRect(
            x: 0,
            y: max(28, mediaFrame.minY - 70),
            width: size.width,
            height: 52
        )
        contentView.addSubview(countdown)

        return RenderedContent(
            view: contentView,
            backdropView: backdropView,
            dimView: dimView,
            haloLayer: haloLayer,
            mediaContainer: mediaContainer,
            promptLabel: promptLabel,
            countdownLabel: countdown,
            player: player,
            playerLooper: playerLooper
        )
    }

    private static func randomBreakPrompt() -> String {
        let key = [
            "break.prompt.lookAway",
            "break.prompt.shoulders",
            "break.prompt.breathe",
            "break.prompt.stand",
            "break.prompt.water"
        ].randomElement() ?? "break.prompt.breathe"

        return L10n.string(key)
    }
}
