import SwiftUI
import EventKit
import EventKitUI

struct AddToCalendarButton: View {
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let notes: String?

    @Environment(\.openURL) private var openURL
    @State private var showCalendarPicker = false
    @State private var showEventComposer = false
    @State private var showShareSheet = false
    @State private var icsFileURL: URL?

    var body: some View {
        Button {
            showCalendarPicker = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add to Calendar")
                    .font(Theme.Typography.calloutMedium)
            }
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule().fill(Theme.Colors.accent.opacity(0.12))
            )
        }
        .confirmationDialog("Add to Calendar", isPresented: $showCalendarPicker, titleVisibility: .visible) {
            Button("Apple Calendar") { showEventComposer = true }
            Button("Google Calendar") { openGoogleCalendar() }
            Button("Other (Share .ics)") { shareICSFile() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEventComposer) {
            CalendarEventComposer(
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = icsFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func openGoogleCalendar() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone.current

        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate ?? startDate.addingTimeInterval(3600))

        var components = URLComponents(string: "https://calendar.google.com/calendar/render")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title),
            URLQueryItem(name: "dates", value: "\(start)/\(end)"),
        ]
        if let location {
            components.queryItems?.append(URLQueryItem(name: "location", value: location))
        }
        if let notes {
            components.queryItems?.append(URLQueryItem(name: "details", value: notes))
        }

        if let url = components.url {
            openURL(url)
        }
    }

    private func shareICSFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let uid = UUID().uuidString
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate ?? startDate.addingTimeInterval(3600))

        var ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//CardboardWithMe//GameNight//EN
        BEGIN:VEVENT
        UID:\(uid)
        DTSTART:\(start)Z
        DTEND:\(end)Z
        SUMMARY:\(icsEscape(title))
        """

        if let location {
            ics += "\nLOCATION:\(icsEscape(location))"
        }
        if let notes {
            ics += "\nDESCRIPTION:\(icsEscape(notes))"
        }

        ics += """

        END:VEVENT
        END:VCALENDAR
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(title.prefix(30)).ics")

        do {
            try ics.write(to: tempURL, atomically: true, encoding: .utf8)
            icsFileURL = tempURL
            showShareSheet = true
        } catch {
            // Non-critical
        }
    }

    private func icsEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - EKEventEditViewController wrapper
struct CalendarEventComposer: UIViewControllerRepresentable {
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let notes: String?

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600)
        event.location = location
        event.notes = notes

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

// MARK: - UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
