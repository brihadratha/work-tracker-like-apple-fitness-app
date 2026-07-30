import ActivityKit
import AppIntents
import Foundation

private enum LiveActivityActionStore {
  static let suiteName = "group.ai.atiq.workRings"
  static let pendingActionKey = "liveActivityPendingAction"

  static func write(
    type: String,
    sessionID: String,
    elapsed: Int,
    occurredAt: Date
  ) {
    UserDefaults(suiteName: suiteName)?.set(
      [
        "type": type,
        "sessionId": sessionID,
        "elapsedSeconds": elapsed,
        "occurredAt": Int(occurredAt.timeIntervalSince1970 * 1000),
      ],
      forKey: pendingActionKey
    )
  }
}

@available(iOSApplicationExtension 17.0, *)
struct ToggleWorkSessionIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Pause or Resume Focus Session"
  static var description = IntentDescription("Pauses or resumes the active focus session.")
  static var openAppWhenRun = false

  @Parameter(title: "Session") var sessionID: String

  init(sessionID: String) {
    self.sessionID = sessionID
  }

  init() {
    self.sessionID = ""
  }

  func perform() async throws -> some IntentResult {
    guard let activity = Activity<WorkSessionAttributes>.activities.first(
      where: { $0.attributes.sessionID == sessionID }
    ) else {
      return .result()
    }

    let now = Date()
    let state = activity.contentState
    let elapsed = state.isPaused
      ? state.elapsedSeconds
      : max(0, Int(now.timeIntervalSince(state.timerStart)))
    let willPause = !state.isPaused
    let nextState = WorkSessionAttributes.ContentState(
      elapsedSeconds: elapsed,
      timerStart: now.addingTimeInterval(TimeInterval(-elapsed)),
      isPaused: willPause
    )

    // Persist before awaiting ActivityKit so Flutter can consume this command
    // even when the user immediately opens or stops the app.
    LiveActivityActionStore.write(
      type: willPause ? "pause" : "resume",
      sessionID: sessionID,
      elapsed: elapsed,
      occurredAt: now
    )
    await activity.update(using: nextState)
    return .result()
  }
}

@available(iOSApplicationExtension 17.0, *)
struct StopWorkSessionIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Focus Session"
  static var description = IntentDescription("Stops and saves the active focus session.")
  static var openAppWhenRun = false

  @Parameter(title: "Session") var sessionID: String

  init(sessionID: String) {
    self.sessionID = sessionID
  }

  init() {
    self.sessionID = ""
  }

  func perform() async throws -> some IntentResult {
    guard let activity = Activity<WorkSessionAttributes>.activities.first(
      where: { $0.attributes.sessionID == sessionID }
    ) else {
      return .result()
    }

    let now = Date()
    let state = activity.contentState
    let elapsed = state.isPaused
      ? state.elapsedSeconds
      : max(0, Int(now.timeIntervalSince(state.timerStart)))
    let endedState = WorkSessionAttributes.ContentState(
      elapsedSeconds: elapsed,
      timerStart: now.addingTimeInterval(TimeInterval(-elapsed)),
      isPaused: true
    )

    LiveActivityActionStore.write(
      type: "stop",
      sessionID: sessionID,
      elapsed: elapsed,
      occurredAt: now
    )
    await activity.end(using: endedState, dismissalPolicy: .immediate)
    return .result()
  }
}
