import SwiftUI

struct EventDateLabel: View {
    let event: GameEvent
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: size.iconSize))
            Text(displayText)
                .font(size.captionFont)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(foregroundColor.opacity(0.15))
        )
    }

    private var iconName: String {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return "chart.bar.fill"
        }
        return "calendar"
    }

    private var foregroundColor: Color {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return Theme.Colors.accent
        }
        return Theme.Colors.dateAccent
    }

    private var displayText: String {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return "\(event.timeOptions.count) time options"
        }

        guard let timeOption = confirmedOrFirstTimeOption else {
            return "No date set"
        }

        return formatRelativeDate(timeOption)
    }

    private var confirmedOrFirstTimeOption: TimeOption? {
        if let confirmedId = event.confirmedTimeOptionId {
            return event.timeOptions.first { $0.id == confirmedId }
        }
        return event.timeOptions.first
    }

    private func formatRelativeDate(_ timeOption: TimeOption) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: timeOption.date)
        let dayDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timeStr = timeFormatter.string(from: timeOption.startTime)

        let cleanTime = timeStr.replacingOccurrences(of: ":00", with: "")

        if dayDiff == 0 {
            return "Today \u{00B7} \(cleanTime)"
        } else if dayDiff == 1 {
            return "Tomorrow \u{00B7} \(cleanTime)"
        } else if dayDiff > 1 && dayDiff < 7 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            return "\(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else if dayDiff >= 7 && dayDiff < 14 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            return "Next \(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else if dayDiff < 0 {
            if dayDiff == -1 {
                return "Yesterday \u{00B7} \(cleanTime)"
            }
            let dayFormatter = DateFormatter()
            if size == .compact {
                dayFormatter.dateFormat = "M/d"
            } else {
                dayFormatter.dateFormat = "EEE, MMM d"
            }
            return "Past \(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else {
            let dayFormatter = DateFormatter()
            if size == .compact {
                dayFormatter.dateFormat = "EEE M/d"
            } else {
                dayFormatter.dateFormat = "EEE, MMM d"
            }
            return "\(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        }
    }
}
