import AppKit

enum TimeOfDay {
    case day
    case night
    case any

    static func current(at date: Date = Date()) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        return (hour < 6 || hour >= 18) ? .night : .day
    }
}

enum CharacterPose {
    case idle
    case phone
}

enum AtmosphereKind {
    case fireflies(count: Int)
    case butterflies(count: Int)
    case rain
    case none
}

enum AnchorY {
    case ground
    case floating(yRatio: CGFloat)
}

enum SpriteKind {
    case character(pose: CharacterPose)
    case asset(name: String, fileExtension: String, animates: Bool)
}

struct SpriteSpec {
    let kind: SpriteKind
    let pixelSize: CGSize
    let anchorX: CGFloat
    let anchorY: AnchorY
}

struct SceneBackdrop {
    let imageName: String
    let nativePixelSize: CGSize
}

struct SceneDescriptor {
    let backgroundGradient: (top: NSColor, bottom: NSColor)
    let groundColor: NSColor
    let backdrop: SceneBackdrop?
    let cast: [SpriteSpec]
    let atmosphere: AtmosphereKind
}

enum SceneTemplate: CaseIterable {
    case nightCamp
    case morningBalcony
    case rainyWindow
    case cozyJapaneseRoom
    case morningHome
    case rainyCafe

    var allowsTimeOfDay: TimeOfDay {
        switch self {
        case .nightCamp: return .night
        case .morningBalcony: return .day
        case .rainyWindow: return .any
        case .cozyJapaneseRoom: return .any
        case .morningHome: return .day
        case .rainyCafe: return .any
        }
    }

    var introKey: String {
        switch self {
        case .nightCamp: return "pixel.scene.intro.nightCamp"
        case .morningBalcony: return "pixel.scene.intro.morningBalcony"
        case .rainyWindow: return "pixel.scene.intro.rainyWindow"
        case .cozyJapaneseRoom: return "pixel.scene.intro.cozyJapaneseRoom"
        case .morningHome: return "pixel.scene.intro.morningHome"
        case .rainyCafe: return "pixel.scene.intro.rainyCafe"
        }
    }

    var descriptor: SceneDescriptor {
        switch self {
        case .nightCamp:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.28, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.06, green: 0.05, blue: 0.14, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.18, alpha: 1),
                backdrop: nil,
                cast: [
                    SpriteSpec(
                        kind: .character(pose: .idle),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.22,
                        anchorY: .ground
                    ),
                    SpriteSpec(
                        kind: .asset(name: "prop-campfire", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.38,
                        anchorY: .ground
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.68,
                        anchorY: .ground
                    )
                ],
                atmosphere: .fireflies(count: 4)
            )
        case .morningBalcony:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.65, green: 0.78, blue: 0.92, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.97, green: 0.85, blue: 0.72, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.58, alpha: 1),
                backdrop: nil,
                cast: [
                    SpriteSpec(
                        kind: .asset(name: "prop-plant", fileExtension: "png", animates: false),
                        pixelSize: CGSize(width: 64, height: 64),
                        anchorX: 0.18,
                        anchorY: .ground
                    ),
                    SpriteSpec(
                        kind: .character(pose: .phone),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.42,
                        anchorY: .ground
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.74,
                        anchorY: .ground
                    )
                ],
                atmosphere: .butterflies(count: 2)
            )
        case .rainyWindow:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.32, green: 0.40, blue: 0.50, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.34, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.26, alpha: 1),
                backdrop: nil,
                cast: [
                    SpriteSpec(
                        kind: .character(pose: .idle),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.30,
                        anchorY: .ground
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.66,
                        anchorY: .ground
                    )
                ],
                atmosphere: .rain
            )
        case .cozyJapaneseRoom:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.16, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.06, green: 0.05, blue: 0.10, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.06, green: 0.05, blue: 0.10, alpha: 1),
                backdrop: SceneBackdrop(
                    imageName: "scene-japanese-home",
                    nativePixelSize: CGSize(width: 608, height: 428)
                ),
                cast: [
                    SpriteSpec(
                        kind: .character(pose: .idle),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.40,
                        anchorY: .floating(yRatio: 0.50)
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.83,
                        anchorY: .floating(yRatio: 0.78)
                    )
                ],
                atmosphere: .fireflies(count: 4)
            )
        case .morningHome:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.78, green: 0.85, blue: 0.94, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.92, green: 0.86, blue: 0.78, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.86, green: 0.78, blue: 0.68, alpha: 1),
                backdrop: SceneBackdrop(
                    imageName: "scene-generic-home",
                    nativePixelSize: CGSize(width: 448, height: 428)
                ),
                cast: [
                    SpriteSpec(
                        kind: .character(pose: .phone),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.50,
                        anchorY: .floating(yRatio: 0.55)
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.22,
                        anchorY: .floating(yRatio: 0.30)
                    )
                ],
                atmosphere: .butterflies(count: 2)
            )
        case .rainyCafe:
            return SceneDescriptor(
                backgroundGradient: (
                    top: NSColor(calibratedRed: 0.40, green: 0.46, blue: 0.56, alpha: 1),
                    bottom: NSColor(calibratedRed: 0.24, green: 0.28, blue: 0.36, alpha: 1)
                ),
                groundColor: NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.32, alpha: 1),
                backdrop: SceneBackdrop(
                    imageName: "scene-ice-cream-shop",
                    nativePixelSize: CGSize(width: 384, height: 320)
                ),
                cast: [
                    SpriteSpec(
                        kind: .character(pose: .phone),
                        pixelSize: CGSize(width: 32, height: 64),
                        anchorX: 0.78,
                        anchorY: .floating(yRatio: 0.55)
                    ),
                    SpriteSpec(
                        kind: .asset(name: "cast-mochi", fileExtension: "gif", animates: true),
                        pixelSize: CGSize(width: 96, height: 32),
                        anchorX: 0.22,
                        anchorY: .floating(yRatio: 0.55)
                    )
                ],
                atmosphere: .none
            )
        }
    }

    private static var lastShown: SceneTemplate?

    static func random(for timeOfDay: TimeOfDay) -> SceneTemplate {
        let candidates = Self.allCases.filter {
            ($0.allowsTimeOfDay == timeOfDay || $0.allowsTimeOfDay == .any)
                && $0 != lastShown
        }
        let pool = candidates.isEmpty
            ? Self.allCases.filter { $0.allowsTimeOfDay == timeOfDay || $0.allowsTimeOfDay == .any }
            : candidates
        let pick = pool.randomElement() ?? .nightCamp
        lastShown = pick
        return pick
    }
}
