import SwiftUI

struct EventLocationLabel: View {
    let event: GameEvent
    let viewerRole: EventViewerRole
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.system(size: size.iconSize))
            Text(displayText)
                .font(size.captionFont)
                .lineLimit(1)
        }
        .foregroundColor(Theme.Colors.textSecondary)
    }

    private var accessPolicy: EventAccessPolicy {
        EventAccessPolicy(
            visibility: event.visibility,
            viewerRole: viewerRole,
            rsvpDeadline: event.rsvpDeadline,
            allowGuestInvites: event.allowGuestInvites,
            now: Date()
        )
    }

    private var displayText: String {
        guard event.location != nil || event.locationAddress != nil else {
            return "TBD Location"
        }

        let presentation = EventLocationPresentation(
            locationName: event.location,
            locationAddress: event.locationAddress,
            canViewFullAddress: accessPolicy.canViewFullAddress
        )

        return presentation.title
    }
}
