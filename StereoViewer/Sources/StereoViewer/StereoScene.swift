import Metal
import simd

/// A drawable object in a `StereoScene`.
public struct StereoNode {
    public enum Surface {
        case solid
        /// World-space XZ checkerboard, handy for floors.
        case checker(tileSize: Float)
    }

    public var mesh: StereoMesh
    public var transform: float4x4
    public var color: SIMD4<Float>
    public var surface: Surface

    public init(mesh: StereoMesh,
                transform: float4x4 = .identity,
                color: SIMD4<Float> = [1, 1, 1, 1],
                surface: Surface = .solid) {
        self.mesh = mesh
        self.transform = transform
        self.color = color
        self.surface = surface
    }
}

/// Implement this to supply your own content to the viewer.
/// Scene uses a right-handed, Y-up coordinate system in meters; the viewer starts looking down -Z.
public protocol StereoScene: AnyObject {
    var nodes: [StereoNode] { get }
    /// World position of the head (midpoint between the eyes).
    var cameraPosition: SIMD3<Float> { get }
    var backgroundColor: SIMD3<Float> { get }
    /// Direction light travels (e.g. pointing down).
    var lightDirection: SIMD3<Float> { get }
    var fogDensity: Float { get }

    /// Called once with the renderer's device; create meshes here.
    func build(device: MTLDevice)
    /// Called every frame before drawing.
    func update(time: TimeInterval)
}

public extension StereoScene {
    var cameraPosition: SIMD3<Float> { [0, 1.6, 0] }
    var backgroundColor: SIMD3<Float> { [0.62, 0.74, 0.88] }
    var lightDirection: SIMD3<Float> { simd_normalize([-0.4, -1, -0.3]) }
    var fogDensity: Float { 0.02 }
    func update(time: TimeInterval) {}
}
