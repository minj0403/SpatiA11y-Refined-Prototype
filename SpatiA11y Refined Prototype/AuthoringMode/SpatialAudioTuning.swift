import CoreGraphics
import Foundation

/// Study-oriented defaults for clearer headphone spatial separation.
enum SpatialAudioTuning {
    /// Maps screen positions farther apart in the PHASE room (stronger L/R and depth).
    static let worldSpreadScale: Float = 1.45

    /// Usable half-extent of the virtual table (meters), before spread scale.
    static let roomWidth: Float = 10.0
    static let roomDepth: Float = 10.0
    static let roomInset: Float = 0.35

    /// Finger must be within this fraction of the shorter screen side to hear a loop.
    static let activationRadiusScreenFraction: CGFloat = 0.34

    /// Hysteresis when leaving a zone (lower = less overlap bleed).
    static let activationReleaseMultiplier: Float = 1.06

    /// PHASE geometric spreading rolloff (higher = quieter at distance).
    static let distanceRolloffFactor: Double = 1.85

    /// Minimum gain at the edge of the activation zone.
    static let proximityGainFloor: Float = 0.06

    static let earlyReflectionsSend: Double = 0.04
    static let lateReverbSend: Double = 0.03
}
