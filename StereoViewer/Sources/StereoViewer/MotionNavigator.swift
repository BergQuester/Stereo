import simd

/// How head motion moves the viewpoint through the scene.
public enum StereoNavigationMode: Equatable {
    /// Head rotation only; the viewpoint stays at the scene's camera position.
    case lookAround
    /// Walk (or jog) in place to move forward in the direction you are facing.
    /// Steps are detected from the vertical bounce of the phone.
    case walkInPlace
    /// Turning your head moves you around a point `distance` meters in front of the
    /// starting viewpoint while always facing it: look left to circle to its right side,
    /// look down to see it from above.
    case orbit(distance: Float = 3)

    /// Modes cycled by the viewer's long-press gesture.
    public static let allCases: [StereoNavigationMode] = [.lookAround, .walkInPlace, .orbit()]

    public var displayName: String {
        switch self {
        case .lookAround:  return "Look Around"
        case .walkInPlace: return "Walk in Place"
        case .orbit:       return "Orbit"
        }
    }
}

/// Turns head orientation and vertical acceleration into a head position for the current mode.
final class MotionNavigator {
    /// Distance walked from the scene's camera position.
    private(set) var walkOffset: SIMD3<Float> = .zero

    private var filteredAcceleration: Float = 0
    private var stepArmed = true
    private var lastStepTime: Double = -.infinity
    private var speed: Float = 0
    private var lastUpdateTime: Double?

    /// Seconds after the last detected step during which the walker keeps moving.
    private static let stepHoldDuration: Double = 0.8
    /// Ignore peaks closer together than this (faster than any real step cadence).
    private static let minimumStepInterval: Double = 0.25
    /// Orbit never drops the eyes below this height, so looking up doesn't go under the floor.
    private static let orbitMinimumHeight: Float = 0.1

    func reset() {
        walkOffset = .zero
        filteredAcceleration = 0
        stepArmed = true
        lastStepTime = -.infinity
        speed = 0
        lastUpdateTime = nil
    }

    /// Advances walking state and returns the head position for this frame.
    /// - Parameters:
    ///   - orientation: Head orientation in scene space.
    ///   - basePosition: The scene's camera position.
    ///   - verticalAcceleration: Upward user acceleration in g, or nil without sensors.
    func headPosition(mode: StereoNavigationMode,
                      orientation: simd_quatf,
                      basePosition: SIMD3<Float>,
                      verticalAcceleration: Float?,
                      configuration: StereoConfiguration,
                      time: Double) -> SIMD3<Float> {
        let dt = Float(min(max(time - (lastUpdateTime ?? time), 0), 0.1))
        lastUpdateTime = time

        switch mode {
        case .lookAround:
            return basePosition

        case .walkInPlace:
            updateWalking(verticalAcceleration: verticalAcceleration ?? 0,
                          orientation: orientation, configuration: configuration,
                          time: time, dt: dt)
            return basePosition + walkOffset

        case .orbit(let distance):
            let center = basePosition + SIMD3<Float>(0, 0, -distance)
            var position = center - orientation.act([0, 0, -1]) * distance
            position.y = max(position.y, Self.orbitMinimumHeight)
            return position
        }
    }

    private func updateWalking(verticalAcceleration: Float, orientation: simd_quatf,
                               configuration: StereoConfiguration, time: Double, dt: Float) {
        // Low-pass to suppress sensor noise while keeping the ~2 Hz step bounce.
        filteredAcceleration += (verticalAcceleration - filteredAcceleration) * min(dt * 20, 1)

        // Peak detection with hysteresis: count a step on the upward push, re-arm once it falls back.
        if stepArmed, filteredAcceleration > configuration.stepThreshold,
           time - lastStepTime > Self.minimumStepInterval {
            lastStepTime = time
            stepArmed = false
        } else if filteredAcceleration < 0 {
            stepArmed = true
        }

        let isWalking = time - lastStepTime < Self.stepHoldDuration
        let targetSpeed = isWalking ? configuration.walkSpeed : 0
        speed += (targetSpeed - speed) * min(dt * 6, 1)

        // Move along the horizontal component of the gaze.
        let forward = orientation.act([0, 0, -1])
        let horizontal = SIMD3<Float>(forward.x, 0, forward.z)
        let length = simd_length(horizontal)
        guard length > 1e-3 else { return }
        walkOffset += horizontal / length * speed * dt
    }
}
