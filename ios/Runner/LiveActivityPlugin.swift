import ActivityKit
import Flutter
import Foundation

final class LiveActivityPlugin: NSObject, FlutterPlugin {
  private static let suiteName = "group.ai.atiq.workRings"
  private static let pendingActionKey = "liveActivityPendingAction"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ai.atiq.workRings/live_activity",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(LiveActivityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "takePendingAction" {
      let defaults = UserDefaults(suiteName: Self.suiteName)
      let action = defaults?.dictionary(forKey: Self.pendingActionKey)
      defaults?.removeObject(forKey: Self.pendingActionKey)
      result(action)
      return
    }

    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }

    let arguments = call.arguments as? [String: Any] ?? [:]
    let elapsed = (arguments["elapsedSeconds"] as? NSNumber)?.intValue ?? 0

    if call.method == "end" {
      let sessionID = arguments["sessionId"] as? String
      let resolvedElapsed = authoritativeElapsed(
        sessionID: sessionID,
        fallback: elapsed
      )
      UserDefaults(suiteName: Self.suiteName)?.removeObject(
        forKey: Self.pendingActionKey
      )
      let state = WorkSessionAttributes.ContentState(
        elapsedSeconds: resolvedElapsed,
        timerStart: Date().addingTimeInterval(TimeInterval(-resolvedElapsed)),
        isPaused: true
      )
      Task {
        await endAll(using: state)
        result(resolvedElapsed)
      }
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(nil)
      return
    }

    switch call.method {
    case "start":
      let attributes = attributes(from: arguments)
      let state = contentState(arguments: arguments, elapsed: elapsed)
      UserDefaults(suiteName: Self.suiteName)?.removeObject(
        forKey: Self.pendingActionKey
      )
      Task {
        await endAll(using: state)
        do {
          _ = try request(attributes: attributes, state: state)
          result(nil)
        } catch {
          result(flutterError("live_activity_start_failed", error))
        }
      }
    case "update", "synchronize":
      let attributes = attributes(from: arguments)
      let state = contentState(arguments: arguments, elapsed: elapsed)
      Task {
        do {
          try await synchronize(attributes: attributes, state: state)
          result(nil)
        } catch {
          result(flutterError("live_activity_sync_failed", error))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private func attributes(from arguments: [String: Any]) -> WorkSessionAttributes {
    WorkSessionAttributes(
      sessionID: arguments["sessionId"] as? String ?? "",
      category: arguments["category"] as? String ?? "Focus",
      goalMinutes: (arguments["goalMinutes"] as? NSNumber)?.intValue ?? 60
    )
  }

  @available(iOS 16.1, *)
  private func contentState(
    arguments: [String: Any],
    elapsed: Int
  ) -> WorkSessionAttributes.ContentState {
    WorkSessionAttributes.ContentState(
      elapsedSeconds: elapsed,
      timerStart: Date().addingTimeInterval(TimeInterval(-elapsed)),
      isPaused: arguments["isPaused"] as? Bool ?? false
    )
  }

  @available(iOS 16.1, *)
  private func synchronize(
    attributes: WorkSessionAttributes,
    state: WorkSessionAttributes.ContentState
  ) async throws {
    var matchingActivity: Activity<WorkSessionAttributes>?

    for activity in Activity<WorkSessionAttributes>.activities {
      if activity.attributes.sessionID == attributes.sessionID,
         matchingActivity == nil {
        matchingActivity = activity
        await activity.update(using: state)
      } else {
        await activity.end(using: state, dismissalPolicy: .immediate)
      }
    }

    if matchingActivity == nil {
      _ = try request(attributes: attributes, state: state)
    }
  }

  @available(iOS 16.1, *)
  private func request(
    attributes: WorkSessionAttributes,
    state: WorkSessionAttributes.ContentState
  ) throws -> Activity<WorkSessionAttributes> {
    try Activity<WorkSessionAttributes>.request(
      attributes: attributes,
      contentState: state,
      pushType: nil
    )
  }

  @available(iOS 16.1, *)
  private func authoritativeElapsed(
    sessionID: String?,
    fallback: Int
  ) -> Int {
    if let sessionID,
       let action = UserDefaults(suiteName: Self.suiteName)?.dictionary(
         forKey: Self.pendingActionKey
       ),
       action["sessionId"] as? String == sessionID,
       let elapsed = action["elapsedSeconds"] as? NSNumber {
      return max(0, elapsed.intValue)
    }

    guard let sessionID,
          let activity = Activity<WorkSessionAttributes>.activities.first(
            where: { $0.attributes.sessionID == sessionID }
          ) else {
      return max(0, fallback)
    }
    let state = activity.contentState
    return state.isPaused
      ? max(0, state.elapsedSeconds)
      : max(0, Int(Date().timeIntervalSince(state.timerStart)))
  }

  @available(iOS 16.1, *)
  private func endAll(using state: WorkSessionAttributes.ContentState) async {
    for activity in Activity<WorkSessionAttributes>.activities {
      await activity.end(using: state, dismissalPolicy: .immediate)
    }
  }

  private func flutterError(_ code: String, _ error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
}
