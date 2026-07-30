import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct WorkSessionAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var elapsedSeconds: Int
    var timerStart: Date
    var isPaused: Bool
  }

  var category: String
  var goalMinutes: Int
}
