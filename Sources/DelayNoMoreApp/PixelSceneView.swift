import AppKit
import DelayNoMoreCore

enum PixelSceneAssets {
    static let characterIDs = ["03", "07", "09", "12", "18"]

    static var areAvailable: Bool {
        catURL != nil && randomCharacterURL(pose: .idle) != nil && campfireURL != nil
    }

    static var catURL: URL? {
        Bundle.module.url(forResource: "cast-mochi", withExtension: "gif")
    }

    static func randomCharacterURL(pose: CharacterPose) -> URL? {
        let id = characterIDs.randomElement() ?? "07"
        return Bundle.module.url(forResource: "char-\(id)-\(pose.assetSuffix)", withExtension: "png")
    }

    static var previewCharacterURL: URL? {
        Bundle.module.url(forResource: "char-07-idle", withExtension: "png")
    }

    static var campfireURL: URL? {
        Bundle.module.url(forResource: "prop-campfire", withExtension: "gif")
    }

    static var emoteSleepsURL: URL? {
        Bundle.module.url(forResource: "emote-sleeps", withExtension: "png")
    }

    static var butterflyURLs: [URL] {
        ["atm-butterfly", "atm-butterfly-2"].compactMap {
            Bundle.module.url(forResource: $0, withExtension: "gif")
        }
    }

    static func previewThumbnail() -> NSImage? {
        let size = NSSize(width: 256, height: 160)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        if let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.18, green: 0.13, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.06, blue: 0.16, alpha: 1)
        ]) {
            gradient.draw(in: NSRect(origin: .zero, size: size), angle: -90)
        }

        NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.12, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: size.width, height: 36).fill()

        NSGraphicsContext.current?.imageInterpolation = .none

        if let charURL = previewCharacterURL,
           let charImage = NSImage(contentsOf: charURL) {
            charImage.draw(in: NSRect(x: 38, y: 36, width: 32, height: 64))
        }

        if let camURL = campfireURL,
           let cam = NSImage(contentsOf: camURL) {
            cam.draw(in: NSRect(x: 82, y: 36, width: 32, height: 64))
        }

        if let catURL = catURL,
           let cat = NSImage(contentsOf: catURL) {
            cat.draw(in: NSRect(x: 122, y: 36, width: 96, height: 32))
        }

        return image
    }
}

extension CharacterPose {
    var assetSuffix: String {
        switch self {
        case .idle: return "idle"
        case .phone: return "phone"
        }
    }
}

final class PixelSceneView: NSView {
    private let blurView = NSVisualEffectView()
    private let dimView = NSView()
    private let stageView = NSView()
    private let stageGradientLayer = CAGradientLayer()
    private let groundLayer = CAGradientLayer()

    private let template: SceneTemplate
    private let descriptor: SceneDescriptor

    private var castViews: [PixelImageView] = []
    private var mochiView: PixelImageView?

    private let emoteImageView = PixelImageView()
    private let topTextLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")

    private var emoteTimer: Timer?
    private var typewriterTimer: Timer?
    private var butterflyImageViews: [PixelImageView] = []
    private var fireflyLayers: [CALayer] = []
    private var rainEmitter: CAEmitterLayer?

    init(template: SceneTemplate) {
        self.template = template
        self.descriptor = template.descriptor
        super.init(frame: .zero)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    deinit {
        emoteTimer?.invalidate()
        typewriterTimer?.invalidate()
    }

    func updateCountdown(_ seconds: Int) {
        countdownLabel.stringValue = formatClock(seconds)
    }

    func startIntro() {
        typewriterTimer = SceneAnimations.typewriter(
            topTextLabel,
            text: L10n.string(template.introKey),
            perCharSeconds: 0.04
        )
    }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        blurView.blendingMode = .behindWindow
        blurView.material = .fullScreenUI
        blurView.state = .active
        blurView.appearance = NSAppearance(named: .darkAqua)
        blurView.autoresizingMask = [.width, .height]
        addSubview(blurView)

        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.12).cgColor
        dimView.autoresizingMask = [.width, .height]
        addSubview(dimView)

        let topColor = descriptor.backgroundGradient.top
        let bottomColor = descriptor.backgroundGradient.bottom
        let groundColor = descriptor.groundColor

        stageView.wantsLayer = true
        stageView.layer?.backgroundColor = bottomColor.cgColor
        stageView.layer?.cornerRadius = 18
        stageView.layer?.masksToBounds = true
        stageView.layer?.borderWidth = 1
        stageView.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        addSubview(stageView)

        stageGradientLayer.colors = [topColor.cgColor, bottomColor.cgColor]
        stageGradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        stageGradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        stageView.layer?.addSublayer(stageGradientLayer)

        groundLayer.colors = [groundColor.cgColor, bottomColor.cgColor]
        groundLayer.startPoint = CGPoint(x: 0.5, y: 0)
        groundLayer.endPoint = CGPoint(x: 0.5, y: 1)
        stageView.layer?.addSublayer(groundLayer)

        configureCast()
        configureEmote()
        configureLabels()
        configureAtmosphere()

        castViews.forEach { stageView.addSubview($0) }
        if mochiView != nil {
            stageView.addSubview(emoteImageView)
        }
        butterflyImageViews.forEach { stageView.addSubview($0) }

        addSubview(topTextLabel)
        addSubview(countdownLabel)

        if mochiView != nil {
            startEmoteCycle()
        }
    }

    private func configureCast() {
        for spec in descriptor.cast {
            let view = PixelImageView()
            view.imageScaling = .scaleAxesIndependently
            switch spec.kind {
            case .character(let pose):
                if let url = PixelSceneAssets.randomCharacterURL(pose: pose),
                   let img = NSImage(contentsOf: url) {
                    view.image = img
                }
            case .asset(let name, let ext, let animates):
                if let url = Bundle.module.url(forResource: name, withExtension: ext),
                   let img = NSImage(contentsOf: url) {
                    view.image = img
                    view.animates = animates
                }
                if name == "cast-mochi" {
                    mochiView = view
                }
            }
            castViews.append(view)
        }
    }

    private func configureEmote() {
        guard let url = PixelSceneAssets.emoteSleepsURL,
              let img = NSImage(contentsOf: url) else { return }
        emoteImageView.image = img
        emoteImageView.imageScaling = .scaleAxesIndependently
        emoteImageView.alphaValue = 0
    }

    private func configureLabels() {
        topTextLabel.font = NSFont(name: "Toriko", size: 36)
            ?? .systemFont(ofSize: 36, weight: .semibold)
        topTextLabel.textColor = NSColor.white.withAlphaComponent(0.88)
        topTextLabel.alignment = .center
        topTextLabel.maximumNumberOfLines = 2
        topTextLabel.lineBreakMode = .byWordWrapping

        countdownLabel.font = NSFont(name: "Toriko", size: 42)
            ?? .monospacedDigitSystemFont(ofSize: 42, weight: .medium)
        countdownLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        countdownLabel.alignment = .center
    }

    private func configureAtmosphere() {
        switch descriptor.atmosphere {
        case .fireflies(let count):
            for i in 0..<count {
                let layer = CALayer()
                let isBright = (i % 2 == 0)
                layer.backgroundColor = NSColor(
                    calibratedRed: 1.0,
                    green: isBright ? 0.95 : 0.86,
                    blue: 0.45,
                    alpha: 1
                ).cgColor
                layer.magnificationFilter = .nearest
                layer.minificationFilter = .nearest
                stageView.layer?.addSublayer(layer)
                fireflyLayers.append(layer)
            }
        case .butterflies(let count):
            let urls = PixelSceneAssets.butterflyURLs
            guard !urls.isEmpty else { return }
            for i in 0..<count {
                let view = PixelImageView()
                guard let img = NSImage(contentsOf: urls[i % urls.count]) else { continue }
                view.image = img
                view.animates = true
                view.imageScaling = .scaleAxesIndependently
                butterflyImageViews.append(view)
            }
        case .rain:
            let emitter = CAEmitterLayer()
            emitter.emitterShape = .line
            emitter.magnificationFilter = .nearest
            emitter.minificationFilter = .nearest
            stageView.layer?.addSublayer(emitter)
            rainEmitter = emitter
        case .none:
            break
        }
    }

    private static let rainParticleImage: CGImage? = {
        let width = 2
        let height = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(NSColor(calibratedWhite: 0.92, alpha: 0.65).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }()

    private static func pickStageScale(stageHeight: CGFloat) -> CGFloat {
        if stageHeight >= 900 { return 6 }
        if stageHeight >= 700 { return 5 }
        if stageHeight >= 500 { return 4 }
        return 3
    }

    private func startEmoteCycle() {
        emoteTimer = Timer.scheduledTimer(withTimeInterval: 6.5, repeats: true) { [weak self] _ in
            self?.flashEmote()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.flashEmote()
        }
    }

    private func flashEmote() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.6
            emoteImageView.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.8
                    self.emoteImageView.animator().alphaValue = 0
                }
            }
        })
    }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        blurView.frame = bounds
        dimView.frame = bounds

        let maxStageWidth = bounds.width * 0.55
        let maxStageHeight = bounds.height * 0.55
        let aspect: CGFloat = 16.0 / 9.0
        var stageW = maxStageWidth
        var stageH = stageW / aspect
        if stageH > maxStageHeight {
            stageH = maxStageHeight
            stageW = stageH * aspect
        }
        let stageFrame = CGRect(
            x: (bounds.width - stageW) / 2,
            y: (bounds.height - stageH) / 2,
            width: stageW,
            height: stageH
        )
        stageView.frame = stageFrame

        let stageBounds = CGRect(origin: .zero, size: stageFrame.size)
        stageGradientLayer.frame = stageBounds

        let s = Self.pickStageScale(stageHeight: stageH)
        let groundY = max(stageBounds.height * 0.38, 64)
        let spriteFootBuffer = max(s * 1.5, 6)

        groundLayer.frame = CGRect(x: 0, y: 0, width: stageBounds.width, height: groundY)

        for (i, spec) in descriptor.cast.enumerated() where i < castViews.count {
            let view = castViews[i]
            let size = CGSize(width: spec.pixelSize.width * s, height: spec.pixelSize.height * s)
            let centerX = floor(stageBounds.width * spec.anchorX)
            let originX = floor(centerX - size.width / 2)
            let originY: CGFloat
            switch spec.anchorY {
            case .ground:
                originY = floor(groundY + spriteFootBuffer)
            case .floating(let yRatio):
                originY = floor(stageBounds.height * yRatio - size.height / 2)
            }
            view.frame = CGRect(x: originX, y: originY, width: size.width, height: size.height)
        }

        if let mochi = mochiView {
            let emoteSize: CGFloat = 4 * s
            emoteImageView.frame = CGRect(
                x: mochi.frame.midX - emoteSize / 2,
                y: mochi.frame.maxY + 8,
                width: emoteSize,
                height: emoteSize
            )
        }

        topTextLabel.frame = CGRect(
            x: 56,
            y: min(stageFrame.maxY + 26, bounds.height - 88),
            width: max(0, bounds.width - 112),
            height: 60
        )

        countdownLabel.frame = CGRect(
            x: 0,
            y: max(28, stageFrame.minY - 70),
            width: bounds.width,
            height: 52
        )

        layoutAtmosphere(stageBounds: stageBounds, groundY: groundY, scale: s)

        CATransaction.commit()
    }

    private func layoutAtmosphere(stageBounds: CGRect, groundY: CGFloat, scale s: CGFloat) {
        let skyTop = stageBounds.height - 8 * s
        let skyBottom = groundY + 12 * s
        guard skyTop > skyBottom else { return }

        switch descriptor.atmosphere {
        case .fireflies:
            for (i, layer) in fireflyLayers.enumerated() {
                let size: CGFloat = (i % 2 == 0 ? 3 : 2) * s
                let baseX = floor(stageBounds.width * CGFloat([0.18, 0.42, 0.66, 0.86][i % 4]))
                let baseY = floor(skyBottom + (skyTop - skyBottom) * CGFloat([0.30, 0.60, 0.45, 0.75][i % 4]))
                layer.frame = CGRect(x: baseX, y: baseY, width: size, height: size)
                layer.removeAllAnimations()
                SceneAnimations.twinkle(layer, period: 2.4 + Double(i) * 0.4)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: baseX + size / 2, y: baseY + size / 2))
                path.addCurve(
                    to: CGPoint(x: baseX + size / 2 + 18 * s, y: baseY + size / 2 + 12 * s),
                    control1: CGPoint(x: baseX + 6 * s, y: baseY - 6 * s),
                    control2: CGPoint(x: baseX + 14 * s, y: baseY + 18 * s)
                )
                path.addCurve(
                    to: CGPoint(x: baseX + size / 2, y: baseY + size / 2),
                    control1: CGPoint(x: baseX + 22 * s, y: baseY + 4 * s),
                    control2: CGPoint(x: baseX - 4 * s, y: baseY + 8 * s)
                )
                SceneAnimations.driftAlongPath(layer, path: path, duration: 9 + Double(i) * 1.5)
            }
        case .butterflies:
            for (i, view) in butterflyImageViews.enumerated() {
                let size: CGFloat = 16 * s
                let startX = floor(stageBounds.width * CGFloat(i == 0 ? 0.20 : 0.70))
                let baseY = floor(skyBottom + (skyTop - skyBottom) * CGFloat(i == 0 ? 0.55 : 0.30))
                view.frame = CGRect(x: startX, y: baseY, width: size, height: size)
                view.layer?.removeAllAnimations()
                let path = CGMutablePath()
                let endX = floor(stageBounds.width * CGFloat(i == 0 ? 0.78 : 0.22))
                path.move(to: CGPoint(x: startX + size / 2, y: baseY + size / 2))
                path.addCurve(
                    to: CGPoint(x: endX + size / 2, y: baseY + size / 2 + (i == 0 ? 18 : -18) * s),
                    control1: CGPoint(x: stageBounds.width * 0.5, y: baseY + 30 * s),
                    control2: CGPoint(x: stageBounds.width * 0.5, y: baseY - 20 * s)
                )
                path.addCurve(
                    to: CGPoint(x: startX + size / 2, y: baseY + size / 2),
                    control1: CGPoint(x: stageBounds.width * 0.5, y: baseY - 10 * s),
                    control2: CGPoint(x: stageBounds.width * 0.5, y: baseY + 40 * s)
                )
                if let layer = view.layer {
                    SceneAnimations.driftAlongPath(layer, path: path, duration: 14 + Double(i) * 3)
                }
            }
        case .rain:
            guard let emitter = rainEmitter else { break }
            emitter.frame = CGRect(origin: .zero, size: stageBounds.size)
            emitter.emitterPosition = CGPoint(x: stageBounds.width / 2, y: stageBounds.height + 8)
            emitter.emitterSize = CGSize(width: stageBounds.width, height: 1)
            if SceneAnimations.reduceMotion {
                emitter.birthRate = 0
            } else if let particle = Self.rainParticleImage {
                let cell = CAEmitterCell()
                cell.contents = particle
                cell.birthRate = 32
                cell.lifetime = Float(stageBounds.height / max(120, 60 * s) + 0.4)
                cell.velocity = -160 * s
                cell.velocityRange = 30
                cell.emissionLongitude = -.pi / 2
                cell.emissionRange = 0.05
                cell.scale = max(s * 0.6, 1.0)
                cell.scaleRange = 0.2
                cell.alphaSpeed = -0.15
                cell.magnificationFilter = "nearest"
                cell.minificationFilter = "nearest"
                emitter.emitterCells = [cell]
                emitter.birthRate = 1
            }
        case .none:
            break
        }
    }
}

private final class PixelImageView: NSImageView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.masksToBounds = true
    }
}
