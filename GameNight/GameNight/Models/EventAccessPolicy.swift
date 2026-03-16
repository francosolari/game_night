import Foundation

enum EventViewerRole {
    case host
    case rsvpd
    case invitedNotRSVPd
    case publicViewer
}

struct EventAccessPolicy {
    let visibility: EventVisibility
    let viewerRole: EventViewerRole
    let rsvpDeadline: Date?
    let allowGuestInvites: Bool
    let now: Date

    var canViewFullAddress: Bool {
        visibility == .public || viewerRole == .host || viewerRole == .rsvpd
    }

    var canViewGuestList: Bool {
        viewerRole != .publicViewer
    }

    var canViewGuestCounts: Bool {
        true
    }

    var isRSVPClosed: Bool {
        guard let rsvpDeadline else { return false }
        return rsvpDeadline < now
    }

    var canInviteGuests: Bool {
        switch viewerRole {
        case .host:
            return true
        case .rsvpd:
            return allowGuestInvites
        case .invitedNotRSVPd, .publicViewer:
            return false
        }
    }
}

enum RSVPDeadlineDisplay {
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    static func label(for deadline: Date, now: Date = Date()) -> String {
        "RSVP BY \(value(for: deadline, now: now))"
    }

    static func value(for deadline: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let formatted: String

        if calendar.isDate(deadline, equalTo: now, toGranularity: .weekOfYear) {
            formatted = weekdayFormatter.string(from: deadline)
        } else {
            formatted = monthDayFormatter.string(from: deadline)
        }

        return formatted.uppercased()
    }
}
