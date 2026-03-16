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
}
