import SwiftUI
import StereoViewer

@main
struct StereoApp: App {
    var body: some Scene {
        WindowGroup {
            StereoViewerView()
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
