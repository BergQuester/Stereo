import Metal
import simd

/// Vertex layout shared with the Metal shader (32-byte stride).
public struct StereoVertex {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>

    public init(position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.position = position
        self.normal = normal
    }
}

/// Indexed triangle mesh living in GPU buffers.
public final class StereoMesh {
    public let vertexBuffer: MTLBuffer
    public let indexBuffer: MTLBuffer
    public let indexCount: Int

    public init?(device: MTLDevice, vertices: [StereoVertex], indices: [UInt32]) {
        guard !vertices.isEmpty, !indices.isEmpty,
              let vb = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<StereoVertex>.stride * vertices.count,
                                         options: .storageModeShared),
              let ib = device.makeBuffer(bytes: indices,
                                         length: MemoryLayout<UInt32>.stride * indices.count,
                                         options: .storageModeShared)
        else { return nil }
        vertexBuffer = vb
        indexBuffer = ib
        indexCount = indices.count
    }

    // MARK: - Primitives

    public static func box(device: MTLDevice, size: SIMD3<Float> = [1, 1, 1]) -> StereoMesh? {
        // (normal, u, v) per face
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            ([ 1, 0, 0], [0, 0, -1], [0, 1, 0]),
            ([-1, 0, 0], [0, 0,  1], [0, 1, 0]),
            ([ 0, 1, 0], [1, 0,  0], [0, 0, -1]),
            ([ 0,-1, 0], [1, 0,  0], [0, 0,  1]),
            ([ 0, 0, 1], [1, 0,  0], [0, 1, 0]),
            ([ 0, 0,-1], [-1, 0, 0], [0, 1, 0])
        ]
        let corners: [(Float, Float)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        let half = size * 0.5
        var vertices: [StereoVertex] = []
        var indices: [UInt32] = []
        for (n, u, v) in faces {
            let base = UInt32(vertices.count)
            for (su, sv) in corners {
                vertices.append(StereoVertex(position: (n + u * su + v * sv) * half, normal: n))
            }
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        return StereoMesh(device: device, vertices: vertices, indices: indices)
    }

    public static func plane(device: MTLDevice, size: Float) -> StereoMesh? {
        let h = size * 0.5
        let n = SIMD3<Float>(0, 1, 0)
        let vertices = [
            StereoVertex(position: [-h, 0,  h], normal: n),
            StereoVertex(position: [ h, 0,  h], normal: n),
            StereoVertex(position: [ h, 0, -h], normal: n),
            StereoVertex(position: [-h, 0, -h], normal: n)
        ]
        return StereoMesh(device: device, vertices: vertices, indices: [0, 1, 2, 0, 2, 3])
    }

    public static func sphere(device: MTLDevice, radius: Float = 1, segments: Int = 32, rings: Int = 16) -> StereoMesh? {
        var vertices: [StereoVertex] = []
        var indices: [UInt32] = []
        for r in 0...rings {
            let phi = Float(r) / Float(rings) * .pi
            for s in 0...segments {
                let theta = Float(s) / Float(segments) * 2 * .pi
                let n = SIMD3<Float>(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
                vertices.append(StereoVertex(position: n * radius, normal: n))
            }
        }
        let stride = UInt32(segments + 1)
        for r in 0..<rings {
            for s in 0..<segments {
                let a = UInt32(r) * stride + UInt32(s)
                let b = a + stride
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        return StereoMesh(device: device, vertices: vertices, indices: indices)
    }
}
