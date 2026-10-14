import simd

public extension float4x4 {
    static var identity: float4x4 { matrix_identity_float4x4 }

    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }

    init(scale s: SIMD3<Float>) {
        self = float4x4(diagonal: SIMD4<Float>(s.x, s.y, s.z, 1))
    }

    init(uniformScale s: Float) {
        self.init(scale: SIMD3<Float>(repeating: s))
    }

    init(rotation q: simd_quatf) {
        self = float4x4(q)
    }

    /// Right-handed perspective projection with Metal's 0...1 clip-space depth.
    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * near, 0)
        ))
    }
}
