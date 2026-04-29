import AppKit
import AVFoundation
import AVKit
import DelayNoMoreCore
import QuartzCore

final class ReminderWindowController {
    private final class Surface {
        let window: NSWindow
        let content: Content
        var isClosing = false

        enum Content {
            case media(MediaContent)
            case pixelScene(PixelSceneView)
        }

        final class MediaContent {
            let backdropView: NSView
            let dimView: NSView
            let haloLayer: CAGradientLayer
            let mediaContainer: NSView
            let promptLabel: NSTextField
            let countdownLabel: NSTextField
            let player: AVQueuePlayer?
            let playerLooper: AVPlayerLooper?

            init(
                backdropView: NSView,
                dimView: NSView,
                haloLayer: CAGradientLayer,
                mediaContainer: NSView,
                promptLabel: NSTextField,
                countdownLabel: NSTextField,
                player: AVQueuePlayer?,
                playerLooper: AVPlayerLooper?
            ) {
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

        init(window: NSWindow, content: Content) {
            self.window = window
            self.content = content
        }
    }

    private struct RenderedMedia {
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

    var onSkipRequested: (() -> Void)?

    func show(media: ReminderMedia) -> Bool {
        guard let asset = ReminderMediaLibrary.asset(for: media) else {
            return false
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return false
        }

        dismiss(animated: false)

        switch asset {
        case .pixelScene:
            for screen in screens {
                let surface = makePixelSurface(screen: screen)
                surfaces.append(surface)
                surface.window.orderFrontRegardless()
                animatePixelIntro(surface)
            }
        case .image, .video:
            let naturalSize = Self.naturalSize(for: asset)
            let prompt = Self.randomBreakPrompt()

            for screen in screens {
                let surface = makeMediaSurface(asset: asset, screen: screen, naturalSize: naturalSize, prompt: prompt)
                surfaces.append(surface)
                surface.window.orderFrontRegardless()
                if case .media(let media) = surface.content {
                    media.player?.play()
                }
                animateMediaIntro(surface)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        surfaces.first?.window.makeKeyAndOrderFront(nil)

        return true
    }

    func updateCountdown(_ remainingSeconds: Int) {
        let text = formatClock(remainingSeconds)
        for surface in surfaces {
            switch surface.content {
            case .media(let media):
                media.countdownLabel.stringValue = text
            case .pixelScene(let scene):
                scene.updateCountdown(remainingSeconds)
            }
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
                if case .media(let media) = surface.content {
                    media.player?.pause()
                }
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

        let mediaSurfaces = toDismiss.compactMap { surface -> (Surface, Surface.MediaContent)? in
            if case .media(let m) = surface.content { return (surface, m) }
            return nil
        }
        let pixelSurfaces = toDismiss.compactMap { surface -> (Surface, PixelSceneView)? in
            if case .pixelScene(let p) = surface.content { return (surface, p) }
            return nil
        }

        if !pixelSurfaces.isEmpty {
            let duration = fast ? 0.20 : 0.45
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                for (surface, _) in pixelSurfaces {
                    surface.window.animator().alphaValue = 0
                }
            } completionHandler: {
                for (surface, _) in pixelSurfaces {
                    surface.window.orderOut(nil)
                    surface.window.close()
                }
            }
        }

        if mediaSurfaces.isEmpty {
            return
        }

        let mediaDuration = fast ? 0.14 : 0.18
        let backdropDelay: TimeInterval = fast ? 0.06 : 0.12
        let backdropDuration = fast ? 0.19 : 0.33
        let closeDelay = backdropDelay + backdropDuration + 0.03

        for (_, media) in mediaSurfaces {
            media.haloLayer.removeAllAnimations()
            media.haloLayer.opacity = 0
            SceneAnimations.scaleOut(media.mediaContainer, duration: mediaDuration)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = mediaDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for (_, media) in mediaSurfaces {
                media.mediaContainer.animator().alphaValue = 0
                media.promptLabel.animator().alphaValue = 0
                media.countdownLabel.animator().alphaValue = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + backdropDelay) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = backdropDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for (_, media) in mediaSurfaces {
                    media.backdropView.animator().alphaValue = 0
                    media.dimView.animator().alphaValue = 0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay) {
            for (surface, media) in mediaSurfaces {
                media.player?.pause()
                surface.window.orderOut(nil)
                surface.window.close()
            }
        }
    }

    private func makePixelSurface(screen: NSScreen) -> Surface {
        let overlayFrame = screen.visibleFrame
        let template = SceneTemplate.random(for: TimeOfDay.current())
        let scene = PixelSceneView(template: template)
        scene.frame = NSRect(origin: .zero, size: overlayFrame.size)
        scene.autoresizingMask = [.width, .height]

        let window = makeOverlayWindow(frame: overlayFrame)
        window.contentView = scene

        return Surface(window: window, content: .pixelScene(scene))
    }

    private func makeMediaSurface(asset: ReminderMediaAsset, screen: NSScreen, naturalSize: NSSize, prompt: String) -> Surface {
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

        let rendered = Self.makeMediaContentView(
            size: overlayFrame.size,
            asset: asset,
            mediaFrame: mediaFrame,
            prompt: prompt
        )

        let window = makeOverlayWindow(frame: overlayFrame)
        window.contentView = rendered.view

        let media = Surface.MediaContent(
            backdropView: rendered.backdropView,
            dimView: rendered.dimView,
            haloLayer: rendered.haloLayer,
            mediaContainer: rendered.mediaContainer,
            promptLabel: rendered.promptLabel,
            countdownLabel: rendered.countdownLabel,
            player: rendered.player,
            playerLooper: rendered.playerLooper
        )
        return Surface(window: window, content: .media(media))
    }

    private func makeOverlayWindow(frame: NSRect) -> NSPanel {
        let window = KeyableReminderPanel(
            contentRect: frame,
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
        window.onSkipKey = { [weak self] in
            self?.onSkipRequested?()
        }
        return window
    }

    private func animatePixelIntro(_ surface: Surface) {
        guard case .pixelScene(let scene) = surface.content else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            surface.window.alphaValue = 1
            scene.startIntro()
            return
        }

        surface.window.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.7
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            surface.window.animator().alphaValue = 1
        }, completionHandler: {
            scene.startIntro()
        })
    }

    private func animateMediaIntro(_ surface: Surface) {
        guard case .media(let media) = surface.content else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if reduceMotion {
            media.backdropView.alphaValue = 1
            media.dimView.alphaValue = 1
            media.haloLayer.opacity = 0
            media.mediaContainer.alphaValue = 1
            media.mediaContainer.layer?.transform = CATransform3DIdentity
            media.promptLabel.alphaValue = 1
            media.countdownLabel.alphaValue = 0.58
            return
        }

        media.backdropView.alphaValue = 0
        media.dimView.alphaValue = 0
        media.haloLayer.opacity = 0
        media.mediaContainer.alphaValue = 0
        media.mediaContainer.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1)
        media.promptLabel.alphaValue = 0
        media.countdownLabel.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            media.backdropView.animator().alphaValue = 1
            media.dimView.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard surface.window.isVisible, !surface.isClosing else { return }
            SceneAnimations.haloFlash(on: media.haloLayer)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard surface.window.isVisible, !surface.isClosing else { return }
            SceneAnimations.scaleIn(media.mediaContainer)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.75
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                media.mediaContainer.animator().alphaValue = 1
                media.promptLabel.animator().alphaValue = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard surface.window.isVisible, !surface.isClosing else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                media.countdownLabel.animator().alphaValue = 0.58
            }
        }
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
        case .pixelScene:
            return NSSize(width: 16, height: 9)
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

    private static func makeMediaContentView(
        size: NSSize,
        asset: ReminderMediaAsset,
        mediaFrame: NSRect,
        prompt: String
    ) -> RenderedMedia {
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
        case .pixelScene:
            break
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

        return RenderedMedia(
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

private final class KeyableReminderPanel: NSPanel {
    var onSkipKey: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        let escapeKeyCode: UInt16 = 53
        let spaceKeyCode: UInt16 = 49
        if event.keyCode == escapeKeyCode || event.keyCode == spaceKeyCode {
            onSkipKey?()
        }
    }
}
