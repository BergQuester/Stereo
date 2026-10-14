import SwiftUI

/// SwiftUI wrapper around `StereoViewController`.
///
///     StereoViewerView()                                  // sample scene
///     StereoViewerView(scene: MyScene(), configuration: .init(interpupillaryDistance: 0.06))
public struct StereoViewerView: UIViewControllerRepresentable {
    private let makeScene: () -> StereoScene
    private let configuration: StereoConfiguration

    public init(scene: @autoclosure @escaping () -> StereoScene = SampleScene(),
                configuration: StereoConfiguration = StereoConfiguration()) {
        self.makeScene = scene
        self.configuration = configuration
    }

    public func makeUIViewController(context: Context) -> StereoViewController {
        StereoViewController(scene: makeScene(), configuration: configuration)
    }

    public func updateUIViewController(_ controller: StereoViewController, context: Context) {
        if controller.configuration != configuration {
            controller.configuration = configuration
        }
    }
}
