import Metal
import simd

/// Demo content: checkered floor, a ring of colored blocks, distant pillars,
/// and a spinning cube with orbiting spheres straight ahead.
public final class SampleScene: StereoScene {
    public private(set) var nodes: [StereoNode] = []

    private struct Orbiter {
        let index: Int
        let radius: Float
        let speed: Float
        let phase: Float
    }

    private var spinnerIndex: Int?
    private var orbiters: [Orbiter] = []
    private let focus = SIMD3<Float>(0, 1.6, -3)

    public init() {}

    public func build(device: MTLDevice) {
        guard nodes.isEmpty,
              let cube = StereoMesh.box(device: device),
              let sphere = StereoMesh.sphere(device: device),
              let ground = StereoMesh.plane(device: device, size: 200)
        else { return }

        nodes.append(StereoNode(mesh: ground, color: [0.78, 0.78, 0.74, 1], surface: .checker(tileSize: 1)))

        // Near ring of blocks
        let ringCount = 12
        for i in 0..<ringCount {
            let a = Float(i) / Float(ringCount) * 2 * .pi
            let h = 0.5 + Float(i % 3) * 0.75
            let pos = SIMD3<Float>(sin(a) * 6, h / 2, -cos(a) * 6)
            nodes.append(StereoNode(mesh: cube,
                                    transform: float4x4(translation: pos) * float4x4(scale: [0.8, h, 0.8]),
                                    color: Self.hue(Float(i) / Float(ringCount))))
        }

        // Distant pillars for depth reference
        let pillarCount = 24
        for i in 0..<pillarCount {
            let a = (Float(i) + 0.5) / Float(pillarCount) * 2 * .pi
            let h = 3 + Float(i % 4) * 2
            let pos = SIMD3<Float>(sin(a) * 25, h / 2, -cos(a) * 25)
            let g = 0.55 + Float(i % 3) * 0.1
            nodes.append(StereoNode(mesh: cube,
                                    transform: float4x4(translation: pos) * float4x4(scale: [1.5, h, 1.5]),
                                    color: [g, g, g + 0.05, 1]))
        }

        spinnerIndex = nodes.count
        nodes.append(StereoNode(mesh: cube, color: [0.95, 0.82, 0.3, 1]))

        for i in 0..<5 {
            orbiters.append(Orbiter(index: nodes.count,
                                    radius: 0.9 + Float(i) * 0.3,
                                    speed: 0.6 + Float(i) * 0.15,
                                    phase: Float(i) * 1.3))
            nodes.append(StereoNode(mesh: sphere, color: Self.hue(Float(i) / 5 + 0.1)))
        }

        update(time: 0)
    }

    public func update(time: TimeInterval) {
        let t = Float(time)
        if let i = spinnerIndex {
            nodes[i].transform = float4x4(translation: focus)
                * float4x4(rotation: simd_quatf(angle: t * 0.7, axis: simd_normalize([1, 1, 0.3])))
                * float4x4(uniformScale: 0.6)
        }
        for o in orbiters {
            let a = t * o.speed + o.phase
            let offset = SIMD3<Float>(cos(a) * o.radius, sin(a * 1.3) * 0.4, sin(a) * o.radius)
            nodes[o.index].transform = float4x4(translation: focus + offset) * float4x4(uniformScale: 0.15)
        }
    }

    private static func hue(_ h: Float) -> SIMD4<Float> {
        let h6 = (h - floor(h)) * 6
        let r = min(max(abs(h6 - 3) - 1, 0), 1)
        let g = min(max(2 - abs(h6 - 2), 0), 1)
        let b = min(max(2 - abs(h6 - 4), 0), 1)
        return [0.2 + 0.75 * r, 0.2 + 0.75 * g, 0.2 + 0.75 * b, 1]
    }
}
