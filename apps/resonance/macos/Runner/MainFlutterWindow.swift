import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  #if DEBUG
    /// Held for the process lifetime while a test is running. Released only by
    /// the process exiting, which is what ends the run anyway.
    private var testActivity: NSObjectProtocol?
  #endif

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

        // Hold an activity assertion for the life of the run.
        //
        // Measured, not guessed: a stalled run was sampled twice while the app
        // sat behind another window, and its consumed CPU time did not move at
        // all across twenty seconds — 1.16s, then 1.16s. Bringing the window to
        // the front restarted it (1.16s to 2.65s in fifteen seconds), and it
        // froze again the moment focus went elsewhere. The process was not slow;
        // it was stopped. That is App Nap, which suspends timers for an app it
        // judges to be doing nothing visible — and a test driving frames is
        // exactly that, since nobody is clicking and no audio is playing.
        //
        // The window pin above keeps it visible; this keeps it *running*, which
        // is a different thing and the one that was missing.
        if self?.testActivity == nil {
          self?.testActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "integration test driving frames"
          )
        }
        result(true)
      }
    }
  #endif
}
