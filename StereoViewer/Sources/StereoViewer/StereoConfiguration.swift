import Foundation

/// Tunable parameters for the stereo viewer.
public struct StereoConfiguration: Equatable {
    /// Distance between the two virtual eyes, in scene units (meters).
    public var interpupillaryDistance: Float
    /// Vertical field of view of each eye, in degrees.
    public var verticalFieldOfView: Float
    public var nearZ: Float
    public var farZ: Float
    /// Pre-warps each eye with barrel distortion to cancel viewer lens pincushion.
    public var lensDistortionEnabled: Bool
    public var distortionK1: Float
    public var distortionK2: Float
    /// Draws a thin line between the two eye images.
    public var showsDivider: Bool
    /// Drag adjusts heading (and pitch when no motion sensors, e.g. Simulator).
    public var allowsDragToLook: Bool

    public init(
        interpupillaryDistance: Float = 0.064,
        verticalFieldOfView: Float = 75,
        nearZ: Float = 0.05,
        farZ: Float = 500,
        lensDistortionEnabled: Bool = true,
        distortionK1: Float = 0.22,
        distortionK2: Float = 0.24,
        showsDivider: Bool = true,
        allowsDragToLook: Bool = true
    ) {
        self.interpupillaryDistance = interpupillaryDistance
        self.verticalFieldOfView = verticalFieldOfView
        self.nearZ = nearZ
        self.farZ = farZ
        self.lensDistortionEnabled = lensDistortionEnabled
        self.distortionK1 = distortionK1
        self.distortionK2 = distortionK2
        self.showsDivider = showsDivider
        self.allowsDragToLook = allowsDragToLook
    }
}
