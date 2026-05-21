import CoreGraphics
import Foundation
import simd

/// Study-oriented defaults for clearer headphone spatial separation.
enum SpatialAudioTuning {
    /// Screen left–right → world X (meters along width).
    static let horizontalSpreadScale: Float = 1.45

    /// Screen top–bottom → world Z (depth / front–back). Larger = stronger in-front vs behind.
    static let depthSpreadScale: Float = 1.9

    /// When true, top of screen (lower ny) maps toward listener forward (+Z in neutral head pose).
    static let screenTopIsForward: Bool = true

    /// Slight source height from depth so front/back items are not coplanar at the ears.
    static let sourceElevationFromDepth: Float = 0.14

    /// How much headphone pitch tilts the spatial listener (0 = yaw only).
    static let headPitchInfluence: Float = 0.7

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
