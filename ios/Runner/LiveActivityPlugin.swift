import ActivityKit
import Flutter
import Foundation

final class LiveActivityPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ai.atiq.workRings/live_activity",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(LiveActivityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "takeStopRequest" {
      let defaults = UserDefaults(suiteName: "group.ai.atiq.workRings")
      let elapsed = defaults?.object(forKey: "liveActivityStoppedElapsedSeconds") as? NSNumber
      defaults?.removeObject(forKey: "liveActivityStoppedElapsedSeconds")
      result(elapsed)
      return
    }

    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(nil)
      return
    }
    let arguments = call.arguments as? [String: Any] ?? [:]
    let elapsed = (arguments["elapsedSeconds"] as? NSNumber)?.intValue ?? 0

    switch call.method {
    case "start":
      let category = arguments["category"] as? String ?? "Focus"
      let goalMinutes = (arguments["goalMinutes"] as? NSNumber)?.intValue ?? 60
      let attributes = WorkSessionAttributes(
        category: category,
        goalMinutes: goalMinutes
      )
      let state = contentState(arguments: arguments, elapsed: elapsed)
      do {
        _ = try Activity<WorkSessionAttributes>.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
        result(nil)
      } catch {
        result(FlutterError(
          code: "live_activity_start_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    case "update":
      let state = contentState(arguments: arguments, elapsed: elapsed)
      Task {
        for activity in Activity<WorkSessionAttributes>.activities {
          await activity.update(using: state)
        }
        result(nil)
      }
    case "end":
      let state = WorkSessionAttributes.ContentState(
        elapsedSeconds: elapsed,
        timerStart: Date().addingTimeInterval(TimeInterval(-elapsed)),
        isPaused: true
      )
      Task {
        for activity in Activity<WorkSessionAttributes>.activities {
          await activity.end(using: state, dismissalPolicy: .default)
        }
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private func contentState(
    arguments: [String: Any],
    elapsed: Int
  ) -> WorkSessionAttributes.ContentState {
    let paused = arguments["isPaused"] as? Bool ?? false
    return WorkSessionAttributes.ContentState(
      elapsedSeconds: elapsed,
      timerStart: Date().addingTimeInterval(TimeInterval(-elapsed)),
      isPaused: paused
    )
  }
}
