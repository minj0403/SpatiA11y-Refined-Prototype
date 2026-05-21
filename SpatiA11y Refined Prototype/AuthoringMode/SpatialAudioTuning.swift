import CoreGraphics
import Foundation
import simd

/// Study-oriented defaults for clearer headphone spatial separation.
enum SpatialAudioTuning {
    /// Screen left–right → world X (meters along width).
    static let horizontalSpreadScale: Float = 1.45

    /// Screen top–bottom → world Z (depth). Keep close to horizontal so L/R stays primary.
    static let depthSpreadScale: Float = 1.5

    /// When true, top of screen maps toward listener forward (+Z at neutral yaw).
    static let screenTopIsForward: Bool = true

    /// Extra source height from depth (0 = coplanar table; elevation can weaken L/R cues).
    static let sourceElevationFromDepth: Float = 0

    /// Headphone pitch on listener (0 = yaw only, which preserves left–right).
    static let headPitchInfluence: Float = 0

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

    /// Maps normalized screen coords (−1…1) to world XZ; Y adds subtle elevation from depth.
    static func worldPosition(
        nx: Float,
        ny: Float,
        roomCenter: SIMD3<Float>,
        roomWidth: Float,
        roomDepth: Float,
        roomInset: Float,
        roomY: Float
    ) -> SIMD3<Float> {
        let halfW = (roomWidth * 0.5 - roomInset) * horizontalSpreadScale
        let halfD = (roomDepth * 0.5 - roomInset) * depthSpreadScale
        let depthSign: Float = screenTopIsForward ? -1 : 1
        let x = roomCenter.x + nx * halfW
        let z = roomCenter.z + depthSign * ny * halfD
        let y = roomY + depthSign * (-ny) * sourceElevationFromDepth
        return SIMD3<Float>(x, y, z)
    }
}
