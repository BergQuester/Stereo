import CoreMotion
import UIKit
import simd

/// Converts device attitude into a camera orientation in scene space (Y-up, looking down -Z).
public final class MotionTracker {
    private let manager = CMMotionManager()
    private var yawOffset = simd_quatf(angle: 0, axis: [0, 1, 0])
    private var needsRecenter = true

    /// Extra heading added on top of sensors (driven by drag).
    public var manualYaw: Float = 0
    /// Pitch used only when motion sensors are unavailable (e.g. Simulator).
    public var manualPitch: Float = 0

    public var isMotionAvailable: Bool { manager.isDeviceMotionAvailable }

    public init() {}

    public func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 120.0
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame = frames.contains(.xArbitraryCorrectedZVertical)
            ? .xArbitraryCorrectedZVertical : .xArbitraryZVertical
        // Polled each frame for lowest latency.
        manager.startDeviceMotionUpdates(using: frame)
        needsRecenter = true
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
    }

    /// Makes the current heading the scene's forward (-Z) direction.
    public func recenter() {
        manualYaw = 0
        manualPitch = 0
        needsRecenter = true
    }

    public func orientation(for interfaceOrientation: UIInterfaceOrientation) -> simd_quatf {
        let yaw = simd_quatf(angle: manualYaw, axis: [0, 1, 0])
        guard let motion = manager.deviceMotion else {
            return simd_normalize(yaw * simd_quatf(angle: manualPitch, axis: [1, 0, 0]))
        }
        let a = motion.attitude.quaternion
        let attitude = simd_quatf(ix: Float(a.x), iy: Float(a.y), iz: Float(a.z), r: Float(a.w))
        let raw = Self.referenceToScene * attitude * Self.screenRotation(for: interfaceOrientation)
        if needsRecenter {
            yawOffset = Self.inverseHeading(of: raw)
            needsRecenter = false
        }
        return simd_normalize(yaw * yawOffset * raw)
    }

    // CoreMotion reference frame is Z-up; scene is Y-up with -Z forward.
    private static let referenceToScene = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

    // Maps screen axes (camera right/up/back) into device axes for the current UI orientation.
    private static func screenRotation(for o: UIInterfaceOrientation) -> simd_quatf {
        switch o {
        case .landscapeLeft:      return simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        case .landscapeRight:     return simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        case .portraitUpsideDown: return simd_quatf(angle: .pi, axis: [0, 0, 1])
        default:                  return simd_quatf(angle: 0, axis: [0, 0, 1])
        }
    }

    private static func inverseHeading(of q: simd_quatf) -> simd_quatf {
        let f = q.act([0, 0, -1])
        let heading = atan2(-f.x, -f.z)
        return simd_quatf(angle: -heading, axis: [0, 1, 0])
    }
}
