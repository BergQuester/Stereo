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

    public final class Coordinator {
        var lastConfiguration: StereoConfiguration
        init(configuration: StereoConfiguration) { lastConfiguration = configuration }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(configuration: configuration)
    }

    public func makeUIViewController(context: Context) -> StereoViewController {
        StereoViewController(scene: makeScene(), configuration: configuration)
    }

    public func updateUIViewController(_ controller: StereoViewController, context: Context) {
        // Only push changes made from SwiftUI, so in-viewer changes (e.g. long-press
        // navigation mode switching) aren't reverted on unrelated re-renders.
        guard context.coordinator.lastConfiguration != configuration else { return }
        context.coordinator.lastConfiguration = configuration
        controller.configuration = configuration
    }
}
