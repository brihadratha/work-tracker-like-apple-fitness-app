import ActivityKit
import AppIntents
import Foundation

@available(iOSApplicationExtension 17.0, *)
struct StopWorkSessionIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Focus Session"
  static var description = IntentDescription("Stops and saves the active focus session.")
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    guard let activity = Activity<WorkSessionAttributes>.activities.first else {
      return .result()
    }

    let state = activity.contentState
    let elapsed = state.isPaused
      ? state.elapsedSeconds
      : max(0, Int(Date().timeIntervalSince(state.timerStart)))
    let endedState = WorkSessionAttributes.ContentState(
      elapsedSeconds: elapsed,
      timerStart: Date().addingTimeInterval(TimeInterval(-elapsed)),
      isPaused: true
    )

    let defaults = UserDefaults(suiteName: "group.ai.atiq.workRings")
    defaults?.set(elapsed, forKey: "liveActivityStoppedElapsedSeconds")
    await activity.end(using: endedState, dismissalPolicy: .immediate)
    return .result()
  }
}
