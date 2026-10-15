import UIKit
import MetalKit
import simd

/// Drop-in UIKit view controller showing a side-by-side stereo view of a `StereoScene`,
/// steered by the device's motion sensors. Active in landscape; shows a hint in portrait.
///
/// Double-tap to recenter. Drag to adjust heading. Long-press to change navigation mode.
open class StereoViewController: UIViewController {
    public let scene: StereoScene
    public let motionTracker = MotionTracker()
    public var configuration: StereoConfiguration {
        didSet {
            renderer?.configuration = configuration
            if configuration.navigationMode != oldValue.navigationMode {
                navigator.reset()
            }
        }
    }

    private var mtkView: MTKView!
    private var renderer: StereoRenderer?
    private let hintLabel = UILabel()
    private let navigator = MotionNavigator()
    /// One banner per eye so it reads correctly inside a stereo viewer.
    private let bannerStack = UIStackView()

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
        renderer?.poseProvider = { [weak self] in
            self?.currentPose() ?? ([0, 1.6, 0], simd_quatf(angle: 0, axis: [0, 1, 0]))
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

        bannerStack.translatesAutoresizingMaskIntoConstraints = false
        bannerStack.axis = .horizontal
        bannerStack.distribution = .fillEqually
        bannerStack.isUserInteractionEnabled = false
        bannerStack.alpha = 0
        for _ in 0..<2 {
            let label = UILabel()
            label.textColor = .white
            label.textAlignment = .center
            label.font = .preferredFont(forTextStyle: .headline)
            label.shadowColor = .black
            label.shadowOffset = CGSize(width: 0, height: 1)
            bannerStack.addArrangedSubview(label)
        }
        view.addSubview(bannerStack)
        NSLayoutConstraint.activate([
            bannerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60)
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:))))
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

    /// Switches to the next mode in `StereoNavigationMode.allCases` and briefly shows its name.
    public func cycleNavigationMode() {
        let modes = StereoNavigationMode.allCases
        let index = modes.firstIndex { $0.displayName == configuration.navigationMode.displayName } ?? -1
        configuration.navigationMode = modes[(index + 1) % modes.count]
        showBanner(configuration.navigationMode.displayName)
    }

    private func currentPose() -> (position: SIMD3<Float>, orientation: simd_quatf) {
        let io = view.window?.windowScene?.interfaceOrientation ?? .landscapeRight
        let orientation = motionTracker.orientation(for: io)
        let position = navigator.headPosition(mode: configuration.navigationMode,
                                              orientation: orientation,
                                              basePosition: scene.cameraPosition,
                                              verticalAcceleration: motionTracker.verticalAcceleration,
                                              configuration: configuration,
                                              time: CACurrentMediaTime())
        return (position, orientation)
    }

    private func showBanner(_ text: String) {
        for case let label as UILabel in bannerStack.arrangedSubviews {
            label.text = text
        }
        bannerStack.layer.removeAllAnimations()
        bannerStack.alpha = 1
        UIView.animate(withDuration: 0.5, delay: 1.5, options: [.beginFromCurrentState]) {
            self.bannerStack.alpha = 0
        }
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

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, configuration.allowsLongPressToChangeNavigation else { return }
        cycleNavigationMode()
    }
}
