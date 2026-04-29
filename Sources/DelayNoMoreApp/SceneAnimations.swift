import AppKit
import QuartzCore

enum SceneAnimations {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func haloFlash(on layer: CAGradientLayer) {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0, 0.92, 0.22, 0]
        animation.keyTimes = [0, 0.28, 0.74, 1]
        animation.duration = 0.9
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeIn)
        ]
        layer.add(animation, forKey: "introHaloOpacity")
    }

    static func scaleIn(_ view: NSView) {
        guard let layer = view.layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.94
        animation.toValue = 1
        animation.duration = 0.75
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer.transform = CATransform3DIdentity
        layer.add(animation, forKey: "introScale")
    }

    static func scaleOut(_ view: NSView, duration: TimeInterval) {
        guard let layer = view.layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = (layer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.doubleValue ?? 1
        animation.toValue = 0.98
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        layer.transform = CATransform3DMakeScale(0.98, 0.98, 1)
        layer.add(animation, forKey: "exitScale")
    }

    static func driftAlongPath(_ layer: CALayer, path: CGPath, duration: TimeInterval) {
        guard !reduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.path = path
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.calculationMode = .paced
        animation.timingFunctions = [CAMediaTimingFunction(name: .linear)]
        layer.add(animation, forKey: "drift")
    }

    static func twinkle(_ layer: CALayer, period: TimeInterval) {
        guard !reduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0.4, 1.0, 0.7, 0.4]
        animation.keyTimes = [0, 0.4, 0.7, 1.0]
        animation.duration = period
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        layer.add(animation, forKey: "twinkle")
    }

    static func typewriter(
        _ label: NSTextField,
        text: String,
        perCharSeconds: TimeInterval
    ) -> Timer? {
        if reduceMotion {
            label.stringValue = text
            return nil
        }
        label.stringValue = ""
        let chars = Array(text)
        var index = 0
        let timer = Timer.scheduledTimer(withTimeInterval: perCharSeconds, repeats: true) { timer in
            guard index < chars.count else {
                timer.invalidate()
                return
            }
            label.stringValue.append(chars[index])
            index += 1
        }
        return timer
    }
}
