# Stereo

Metal side-by-side stereo viewer (Cardboard-style) driven by CoreMotion.

- `Stereo.xcodeproj` – demo app (open this, pick your iPhone, run).
- `StereoViewer/` – Swift package containing everything reusable.

## Use in another app

1. Xcode ▸ File ▸ Add Package Dependencies… ▸ Add Local… ▸ select `StereoViewer`.
2. Show it:

```swift
import StereoViewer

StereoViewerView()                       // SwiftUI, sample scene
    .ignoresSafeArea()
    .statusBarHidden()

let vc = StereoViewController()          // UIKit
```

3. Your own content – conform to `StereoScene`:

```swift
final class MyScene: StereoScene {
    private(set) var nodes: [StereoNode] = []
    func build(device: MTLDevice) {
        if let box = StereoMesh.box(device: device) {
            nodes.append(StereoNode(mesh: box,
                                    transform: float4x4(translation: [0, 1.6, -2]),
                                    color: [1, 0.3, 0.2, 1]))
        }
    }
    func update(time: TimeInterval) { /* animate nodes */ }
}

StereoViewerView(scene: MyScene(),
                 configuration: .init(interpupillaryDistance: 0.062, lensDistortionEnabled: false))
```

## Controls

- Landscape only (portrait shows a hint).
- Double-tap: recenter heading.
- Drag: nudge heading (also pitch in Simulator, where there are no sensors).
- Long-press: cycle navigation mode (a banner shows the new mode in each eye).

## Navigation modes

Set `StereoConfiguration.navigationMode` (or long-press in the viewer):

- `.lookAround` (default) – head rotation only.
- `.walkInPlace` – walk or jog in place to move forward in the direction you're facing.
  Steps are detected from the phone's vertical bounce; tune with `walkSpeed` and `stepThreshold`.
- `.orbit(distance:)` – turning your head circles you around a point `distance` meters
  ahead of the start position while you keep facing it (look down to see it from above).

```swift
StereoViewerView(configuration: .init(navigationMode: .walkInPlace, walkSpeed: 1.5))
```

## How it works

- `MotionTracker` reads `CMDeviceMotion.attitude` (Z-up reference), converts it to the
  Y-up scene frame and applies the screen rotation for landscape left/right.
- `StereoRenderer` renders the scene for each eye (offset ±IPD/2 along the head's
  right axis) into the halves of an offscreen texture, then composites to the
  screen with optional barrel pre-distortion (`distortionK1/K2`) for viewer lenses.
- Shaders are compiled at runtime from source, so the package has no resources.
