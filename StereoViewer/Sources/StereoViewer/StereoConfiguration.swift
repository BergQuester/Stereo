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
    /// How head motion moves the viewpoint: look only, walk in place, or orbit.
    public var navigationMode: StereoNavigationMode
    /// Forward speed while walking in place, in meters per second.
    public var walkSpeed: Float
    /// Upward acceleration (in g) that counts as a step. Lower is more sensitive.
    public var stepThreshold: Float
    /// Long-press cycles through `StereoNavigationMode.allCases`.
    public var allowsLongPressToChangeNavigation: Bool

    public init(
        interpupillaryDistance: Float = 0.064,
        verticalFieldOfView: Float = 75,
        nearZ: Float = 0.05,
        farZ: Float = 500,
        lensDistortionEnabled: Bool = true,
        distortionK1: Float = 0.22,
        distortionK2: Float = 0.24,
        showsDivider: Bool = true,
        allowsDragToLook: Bool = true,
        navigationMode: StereoNavigationMode = .lookAround,
        walkSpeed: Float = 1.2,
        stepThreshold: Float = 0.18,
        allowsLongPressToChangeNavigation: Bool = true
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
        self.navigationMode = navigationMode
        self.walkSpeed = walkSpeed
        self.stepThreshold = stepThreshold
        self.allowsLongPressToChangeNavigation = allowsLongPressToChangeNavigation
    }
}
