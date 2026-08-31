import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    #if DEBUG
      registerTestWindowChannel(flutterViewController)
    #endif

    super.awakeFromNib()
  }

  #if DEBUG
    /// Lets an integration test guarantee the window stays on screen.
    ///
    /// macOS pauses a window's display link once the window is fully occluded,
    /// and `tester.pump()` waits on a frame from that display link. So a test
    /// run behind a maximised editor does not fail — it stops, silently, for as
    /// long as the window stays covered. One run here hung for twenty-five
    /// minutes and then reported success; bringing the window to the front by
    /// hand released it instantly, which is what identified this.
    ///
    /// The tool tries to prevent it by running `open` after launch, but that is
    /// a race it documents losing ("no general-purpose way of knowing when a
    /// process is far enough along"), and every run here logs
    /// "Failed to foreground app; open returned 1".
    ///
    /// Floating level keeps the window visible without needing focus at all,
    /// and joining every Space covers the case where a full-screen app leaves
    /// our Space entirely.
    ///
    /// Honest about its status: this is a mitigation, not a proven fix. The
    /// stall could not be reproduced on demand afterwards — not by occluding
    /// the window with a maximised editor, not by stealing focus repeatedly
    /// mid-run, not by leaving a second instance of the app running. So the
    /// only evidence for the mechanism is that one hand-foregrounding released
    /// one stall. Kept because it is cheap, debug-only, and aimed at the single
    /// thing that was observed to matter; do not read it as case closed.
    ///
    /// Debug builds only, and only when a test asks — normal `flutter run`
    /// windows behave exactly as before.
    private func registerTestWindowChannel(_ controller: FlutterViewController) {
      let channel = FlutterMethodChannel(
        name: "app.resonance/test_window",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "keepOnScreen" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.level = .floating
        self?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        NSApp.activate(ignoringOtherApps: true)
        self?.makeKeyAndOrderFront(nil)
        result(true)
      }
    }
  #endif
}
