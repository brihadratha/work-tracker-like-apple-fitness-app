import ActivityKit
import SwiftUI
import WidgetKit

private let ringRed = Color(red: 1.0, green: 0.23, blue: 0.39)

@main
struct WorkRingsLiveActivities: WidgetBundle {
  var body: some Widget {
    WorkSessionLiveActivity()
  }
}

struct WorkSessionLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkSessionAttributes.self) { context in
      HStack(spacing: 16) {
        ZStack {
          Circle().stroke(ringRed.opacity(0.18), lineWidth: 7)
          Circle()
            .trim(from: 0, to: progress(context))
            .stroke(ringRed, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(ringRed)
        }
        .frame(width: 50, height: 50)

        VStack(alignment: .leading, spacing: 3) {
          Text(context.attributes.category.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(ringRed)
          timer(context)
            .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
          Text(context.state.isPaused ? "Paused" : "Session in progress")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 4)
        controls(context)
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.92))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(URL(string: "workrings://timer"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "circle.dashed.inset.filled")
            .foregroundStyle(ringRed)
            .font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.attributes.goalMinutes) min")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(context.attributes.category)
                .font(.caption.weight(.semibold))
              timer(context)
                .font(.title2.monospacedDigit().weight(.semibold))
            }
            Spacer()
            controls(context, compact: true)
          }
        }
      } compactLeading: {
        Image(systemName: "circle.dashed.inset.filled").foregroundStyle(ringRed)
      } compactTrailing: {
        timer(context).font(.caption2.monospacedDigit())
      } minimal: {
        Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
          .foregroundStyle(ringRed)
      }
      .widgetURL(URL(string: "workrings://timer"))
      .keylineTint(ringRed)
    }
  }

  @ViewBuilder
  private func controls(
    _ context: ActivityViewContext<WorkSessionAttributes>,
    compact: Bool = false
  ) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      HStack(spacing: compact ? 10 : 8) {
        Link(destination: URL(string: "workrings://timer")!) {
          Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
            .font(.system(size: compact ? 15 : 14, weight: .bold))
            .foregroundStyle(compact ? ringRed : Color.black)
            .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
            .background(compact ? Color.white.opacity(0.12) : Color.white, in: Circle())
        }
        Button(intent: StopWorkSessionIntent()) {
          Image(systemName: "stop.fill")
            .font(.system(size: compact ? 14 : 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
            .background(ringRed, in: Circle())
        }
        .buttonStyle(.plain)
      }
    } else {
      Link(destination: URL(string: "workrings://timer")!) {
        Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.black)
          .frame(width: 42, height: 42)
          .background(.white, in: Circle())
      }
    }
  }

  @ViewBuilder
  private func timer(_ context: ActivityViewContext<WorkSessionAttributes>) -> some View {
    if context.state.isPaused {
      Text(duration(context.state.elapsedSeconds))
    } else {
      Text(timerInterval: context.state.timerStart...Date.distantFuture, countsDown: false)
    }
  }

  private func progress(_ context: ActivityViewContext<WorkSessionAttributes>) -> Double {
    guard context.attributes.goalMinutes > 0 else { return 0 }
    return min(Double(context.state.elapsedSeconds) / Double(context.attributes.goalMinutes * 60), 1)
  }

  private func duration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remaining = seconds % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
      : String(format: "%02d:%02d", minutes, remaining)
  }
}
