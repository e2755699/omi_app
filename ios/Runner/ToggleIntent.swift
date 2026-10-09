import AppIntents
import Foundation
#if canImport(home_widget)
  import home_widget
#endif

// Shared by the Runner and CheerWidget targets. The widget's keycap buttons use it; it runs in the
// app process (see the ForegroundContinuableIntent extension below), where home_widget starts a
// headless Flutter engine and calls the Dart `homeWidgetInteraction` callback.
@available(iOS 17, *)
public struct ToggleIntent: AppIntent {
  static public var title: LocalizedStringResource = "打卡"

  @Parameter(title: "Widget URI")
  var url: URL?

  @Parameter(title: "AppGroup")
  var appGroup: String?

  public init() {}

  public init(url: URL?, appGroup: String?) {
    self.url = url
    self.appGroup = appGroup
  }

  public func perform() async throws -> some IntentResult {
    #if canImport(home_widget)
      await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup!)
    #endif
    return .result()
  }
}

#if canImport(home_widget)
  // Lets the widget work while the app is suspended. This launches the app in the background.
  @available(iOS 17, *)
  @available(iOSApplicationExtension, unavailable)
  extension ToggleIntent: ForegroundContinuableIntent {}
#endif
