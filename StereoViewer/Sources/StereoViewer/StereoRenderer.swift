import MetalKit
import QuartzCore
import simd

private struct FrameUniforms {
    var viewProjection: float4x4
    var lightDir: SIMD4<Float>
    var cameraPos: SIMD4<Float>
    var fog: SIMD4<Float>
}

private struct NodeUniforms {
    var model: float4x4
    var color: SIMD4<Float>
    var params: SIMD4<Float>
}

/// Renders the scene twice (left/right eye) side by side into an offscreen
/// texture, then composites it to the screen with optional lens pre-distortion.
final class StereoRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let scene: StereoScene
    var configuration: StereoConfiguration
    /// Supplies the head pose (scene-space position and orientation) each frame, after `scene.update`.
    var poseProvider: () -> (position: SIMD3<Float>, orientation: simd_quatf) = {
        ([0, 1.6, 0], simd_quatf(angle: 0, axis: [0, 1, 0]))
    }

    private let queue: MTLCommandQueue
    private let scenePipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private let startTime = CACurrentMediaTime()

    private static let offscreenFormat: MTLPixelFormat = .bgra8Unorm
    private static let depthFormat: MTLPixelFormat = .depth32Float

    init?(view: MTKView, scene: StereoScene, configuration: StereoConfiguration) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else { return nil }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: StereoShaders.source, options: nil)
        } catch {
            assertionFailure("StereoViewer shader compile failed: \(error)")
            return nil
        }

        let sceneDesc = MTLRenderPipelineDescriptor()
        sceneDesc.label = "Stereo scene"
        sceneDesc.vertexFunction = library.makeFunction(name: "scene_vertex")
        sceneDesc.fragmentFunction = library.makeFunction(name: "scene_fragment")
        sceneDesc.colorAttachments[0].pixelFormat = Self.offscreenFormat
        sceneDesc.depthAttachmentPixelFormat = Self.depthFormat

        let compDesc = MTLRenderPipelineDescriptor()
        compDesc.label = "Stereo composite"
        compDesc.vertexFunction = library.makeFunction(name: "quad_vertex")
        compDesc.fragmentFunction = library.makeFunction(name: "distort_fragment")
        compDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true

        guard let scenePipeline = try? device.makeRenderPipelineState(descriptor: sceneDesc),
              let compositePipeline = try? device.makeRenderPipelineState(descriptor: compDesc),
              let depthState = device.makeDepthStencilState(descriptor: depthDesc)
        else { return nil }

        self.device = device
        self.queue = queue
        self.scene = scene
        self.configuration = configuration
        self.scenePipeline = scenePipeline
        self.compositePipeline = compositePipeline
        self.depthState = depthState
        super.init()

        scene.build(device: device)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        colorTarget = nil
        depthTarget = nil
    }

    private func ensureTargets(width: Int, height: Int) {
        if let c = colorTarget, c.width == width, c.height == height { return }
        let color = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.offscreenFormat,
                                                             width: width, height: height, mipmapped: false)
        color.usage = [.renderTarget, .shaderRead]
        color.storageMode = .private
        let depth = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.depthFormat,
                                                             width: width, height: height, mipmapped: false)
        depth.usage = .renderTarget
        depth.storageMode = .private
        colorTarget = device.makeTexture(descriptor: color)
        depthTarget = device.makeTexture(descriptor: depth)
    }

    func draw(in view: MTKView) {
        let width = Int(view.drawableSize.width)
        let height = Int(view.drawableSize.height)
        guard width > 1, height > 0 else { return }
        ensureTargets(width: width, height: height)

        guard let colorTarget, let depthTarget,
              let drawable = view.currentDrawable,
              let commandBuffer = queue.makeCommandBuffer()
        else { return }

        scene.update(time: CACurrentMediaTime() - startTime)

        // --- Pass 1: both eyes into the offscreen texture
        let bg = scene.backgroundColor
        let scenePass = MTLRenderPassDescriptor()
        scenePass.colorAttachments[0].texture = colorTarget
        scenePass.colorAttachments[0].loadAction = .clear
        scenePass.colorAttachments[0].storeAction = .store
        scenePass.colorAttachments[0].clearColor = MTLClearColor(red: Double(bg.x), green: Double(bg.y),
                                                                 blue: Double(bg.z), alpha: 1)
        scenePass.depthAttachment.texture = depthTarget
        scenePass.depthAttachment.loadAction = .clear
        scenePass.depthAttachment.storeAction = .dontCare
        scenePass.depthAttachment.clearDepth = 1

        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: scenePass) else { return }
        enc.label = "Stereo eyes"
        enc.setRenderPipelineState(scenePipeline)
        enc.setDepthStencilState(depthState)
        enc.setCullMode(.none)

        let cfg = configuration
        let eyeWidth = Double(width) / 2
        let aspect = Float(eyeWidth) / Float(height)
        let projection = float4x4.perspective(fovY: cfg.verticalFieldOfView * .pi / 180,
                                              aspect: aspect, near: cfg.nearZ, far: cfg.farZ)
        let pose = poseProvider()
        let head = float4x4(translation: pose.position) * float4x4(rotation: pose.orientation)
        let fogDensity = scene.fogDensity
        let light = scene.lightDirection

        for (index, side) in [Float(-1), Float(1)].enumerated() {
            enc.setViewport(MTLViewport(originX: eyeWidth * Double(index), originY: 0,
                                        width: eyeWidth, height: Double(height), znear: 0, zfar: 1))
            let eye = head * float4x4(translation: [side * cfg.interpupillaryDistance * 0.5, 0, 0])
            let eyePos = eye.columns.3
            var frame = FrameUniforms(viewProjection: projection * eye.inverse,
                                      lightDir: SIMD4<Float>(light.x, light.y, light.z, 0),
                                      cameraPos: eyePos,
                                      fog: SIMD4<Float>(bg.x, bg.y, bg.z, fogDensity))
            enc.setVertexBytes(&frame, length: MemoryLayout<FrameUniforms>.stride, index: 1)
            enc.setFragmentBytes(&frame, length: MemoryLayout<FrameUniforms>.stride, index: 1)

            for node in scene.nodes {
                var params = SIMD4<Float>(0, 1, 0, 0)
                if case .checker(let tile) = node.surface { params = [1, max(tile, 0.001), 0, 0] }
                var uniforms = NodeUniforms(model: node.transform, color: node.color, params: params)
                enc.setVertexBuffer(node.mesh.vertexBuffer, offset: 0, index: 0)
                enc.setVertexBytes(&uniforms, length: MemoryLayout<NodeUniforms>.stride, index: 2)
                enc.setFragmentBytes(&uniforms, length: MemoryLayout<NodeUniforms>.stride, index: 2)
                enc.drawIndexedPrimitives(type: .triangle, indexCount: node.mesh.indexCount,
                                          indexType: .uint32, indexBuffer: node.mesh.indexBuffer,
                                          indexBufferOffset: 0)
            }
        }
        enc.endEncoding()

        // --- Pass 2: composite to screen with lens pre-distortion
        let compPass = MTLRenderPassDescriptor()
        compPass.colorAttachments[0].texture = drawable.texture
        compPass.colorAttachments[0].loadAction = .dontCare
        compPass.colorAttachments[0].storeAction = .store

        if let comp = commandBuffer.makeRenderCommandEncoder(descriptor: compPass) {
            comp.label = "Stereo composite"
            comp.setRenderPipelineState(compositePipeline)
            comp.setFragmentTexture(colorTarget, index: 0)
            let dividerHalfWidth: Float = cfg.showsDivider ? 1.5 / Float(width) : 0
            var params = SIMD4<Float>(cfg.distortionK1, cfg.distortionK2,
                                      cfg.lensDistortionEnabled ? 1 : 0, dividerHalfWidth)
            comp.setFragmentBytes(&params, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            comp.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            comp.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
