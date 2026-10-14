import UIKit
import MetalKit
import simd

/// Drop-in UIKit view controller showing a side-by-side stereo view of a `StereoScene`,
/// steered by the device's motion sensors. Active in landscape; shows a hint in portrait.
///
/// Double-tap to recenter. Drag to adjust heading.
open class StereoViewController: UIViewController {
    public let scene: StereoScene
    public let motionTracker = MotionTracker()
    public var configuration: StereoConfiguration {
        didSet { renderer?.configuration = configuration }
    }

    private var mtkView: MTKView!
    private var renderer: StereoRenderer?
    private let hintLabel = UILabel()

    public init(scene: StereoScene = SampleScene(),
                configuration: StereoConfiguration = StereoConfiguration()) {
        self.scene = scene
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        self.scene = SampleScene()
        self.configuration = StereoConfiguration()
        super.init(coder: coder)
    }

    open override func loadView() {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 120
        view.backgroundColor = .black
        mtkView = view
        self.view = view
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        renderer = StereoRenderer(view: mtkView, scene: scene, configuration: configuration)
        mtkView.delegate = renderer
        renderer?.orientationProvider = { [weak self] in
            self?.currentOrientation() ?? simd_quatf(angle: 0, axis: [0, 1, 0])
        }

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = renderer == nil
            ? "Metal is unavailable on this device."
            : "Rotate to landscape and place the phone in your stereo viewer."
        hintLabel.textColor = .white
        hintLabel.backgroundColor = .black
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.font = .preferredFont(forTextStyle: .title3)
        view.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hintLabel.topAnchor.constraint(equalTo: view.topAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        motionTracker.start()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        motionTracker.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let isLandscape = view.bounds.width > view.bounds.height
        mtkView.isPaused = !isLandscape || renderer == nil
        hintLabel.isHidden = isLandscape && renderer != nil
    }

    open override var prefersStatusBarHidden: Bool { true }
    open override var prefersHomeIndicatorAutoHidden: Bool { true }
    open override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    /// Makes the direction the user is currently facing the scene's forward direction.
    public func recenter() {
        motionTracker.recenter()
    }

    private func currentOrientation() -> simd_quatf {
        let io = view.window?.windowScene?.interfaceOrientation ?? .landscapeRight
        return motionTracker.orientation(for: io)
    }

    @objc private func handleDoubleTap() {
        recenter()
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard configuration.allowsDragToLook else { return }
        let t = g.translation(in: view)
        g.setTranslation(.zero, in: view)
        motionTracker.manualYaw += Float(t.x) * 0.005
        if !motionTracker.isMotionAvailable {
            motionTracker.manualPitch = min(max(motionTracker.manualPitch + Float(t.y) * 0.005, -1.4), 1.4)
        }
    }
}
