import SwiftUI
import MapKit

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding to the caller's state
    @Binding var locationName: String
    @Binding var locationAddress: String
    
    @StateObject private var locationService = LocationService()
    @State private var selectedPlacemark: MKPlacemark? = nil
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    TextField("Search for an address", text: $locationService.searchQuery)
                        .font(Theme.Typography.bodyMedium)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                    
                    if !locationService.searchQuery.isEmpty {
                        Button {
                            locationService.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(
                    Capsule()
                        .stroke(Theme.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                )
                .padding(Theme.Spacing.xl)
                
                // Use custom string value if they want
                if !locationService.searchQuery.isEmpty {
                    Button {
                        locationName = locationService.searchQuery
                        locationAddress = ""
                        dismiss()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            (Text("Use \"") + Text(locationService.searchQuery).bold() + Text("\""))
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    
                    Divider().padding(.horizontal, Theme.Spacing.xl)
                }

                // Results list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(locationService.searchResults, id: \.self) { result in
                            Button {
                                handleSelection(result)
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.vertical, Theme.Spacing.md)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationDestination(item: $selectedPlacemark) { placemark in
                LocationDetailsView(placemark: placemark, onSave: { name, address in
                    locationName = name
                    locationAddress = address
                    dismiss()
                })
            }
            .onAppear {
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
    }
    
    private func handleSelection(_ result: MKLocalSearchCompletion) {
        Task {
            do {
                let placemark = try await locationService.fetchPlacemark(for: result)
                await MainActor.run {
                    self.selectedPlacemark = placemark
                }
            } catch {
                print("Error resolving placemark: \(error)")
            }
        }
    }
}

// MARK: - Selected Location Details View
struct LocationDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let placemark: MKPlacemark
    let onSave: (String, String) -> Void
    
    @State private var displayName: String = ""
    @State private var aptSuite: String = ""

    private var streetLine: String {
        [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var cityStateLine: String {
        [placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var fullAddressString: String {
        let trimmedUnit = aptSuite.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryLine = trimmedUnit.isEmpty ? streetLine : "\(streetLine) \(trimmedUnit)"
        let parts = [primaryLine, cityStateLine].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Selected Address Card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(placemark.name ?? "Address")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "pencil")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                Text([streetLine, cityStateLine].filter { !$0.isEmpty }.joined(separator: "\n"))
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
            .padding(.horizontal, Theme.Spacing.xl)
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.Colors.textTertiary)
                Text("Approximate location shown before RSVP")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Spacing.md)
            
            // Edit Fields
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Display name")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    TextField(placemark.name ?? "Name this location", text: $displayName)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Apt / Suite / Floor")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    TextField("ex: Apt 4B", text: $aptSuite)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let finalName = displayName.isEmpty ? (placemark.name ?? "") : displayName
                    onSave(finalName, fullAddressString)
                }
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.Colors.secondary.opacity(0.2)))
            }
        }
        .onAppear {
            if let name = placemark.name {
                displayName = name
            }
        }
    }
}

enum LocationSheetMode: Identifiable {
    case picker
    case edit

    var id: String {
        switch self {
        case .picker:
            return "picker"
        case .edit:
            return "edit"
        }
    }
}

struct LocationFlowSheet: View {
    @State private var mode: LocationSheetMode
    @Binding var locationName: String
    @Binding var locationAddress: String
    let onRemove: () -> Void

    private let pickerTransition = AnyTransition.asymmetric(
        insertion: .offset(y: 36)
            .combined(with: .scale(scale: 0.98, anchor: .bottom))
            .combined(with: .opacity),
        removal: .opacity
    )

    private let editTransition = AnyTransition.asymmetric(
        insertion: .opacity,
        removal: .offset(y: -20)
            .combined(with: .scale(scale: 0.995, anchor: .top))
            .combined(with: .opacity)
    )

    init(
        initialMode: LocationSheetMode,
        locationName: Binding<String>,
        locationAddress: Binding<String>,
        onRemove: @escaping () -> Void
    ) {
        _mode = State(initialValue: initialMode)
        _locationName = locationName
        _locationAddress = locationAddress
        self.onRemove = onRemove
    }

    var body: some View {
        ZStack {
            if mode == .picker {
                LocationPickerSheet(
                    locationName: $locationName,
                    locationAddress: $locationAddress
                )
                .transition(pickerTransition)
                .zIndex(1)
            }

            if mode == .edit {
                CustomLocationEditSheet(
                    locationName: $locationName,
                    locationAddress: $locationAddress,
                    onEditAddress: {
                        withAnimation(Theme.Animation.snappy) {
                            mode = .picker
                        }
                    },
                    onRemove: onRemove
                )
                .transition(editTransition)
                .zIndex(2)
            }
        }
        .clipped()
        .animation(Theme.Animation.snappy, value: mode)
    }
}

// MARK: - Selected Location Edit Sheet
struct CustomLocationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var locationName: String
    @Binding var locationAddress: String
    
    let onEditAddress: () -> Void
    let onRemove: () -> Void
    
    @State private var draftName: String = ""
    @State private var draftAddressLine: String = ""
    @State private var draftCityStateLine: String = ""
    @State private var draftUnit: String = ""

    private var displayNamePlaceholder: String {
        let trimmed = draftAddressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Name this location" : trimmed
    }

    private var addressCardTitle: String {
        let trimmed = draftAddressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Address" : trimmed
    }

    private var addressCardSubtitle: String {
        let trimmed = draftCityStateLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Search for a location" : trimmed
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Capsule()
                .fill(Theme.Colors.textTertiary.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, Theme.Spacing.sm)

            HStack {
                Button("Clear") {
                    onRemove()
                    dismiss()
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.error)

                Spacer()

                Button("Save") {
                    let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let addressParts = [draftAddressLine, draftCityStateLine]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    var finalAddress = addressParts.joined(separator: ", ")
                    let trimmedUnit = draftUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedUnit.isEmpty {
                        finalAddress += finalAddress.isEmpty ? trimmedUnit : " \(trimmedUnit)"
                    }

                    locationName = trimmedName.isEmpty ? displayNamePlaceholder : trimmedName
                    locationAddress = finalAddress
                    dismiss()
                }
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.Colors.secondary.opacity(0.2)))
            }
            .padding(.horizontal, Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(addressCardTitle)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(addressCardSubtitle)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    Button {
                        onEditAddress()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.cardBackground)
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Display name")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    TextField(displayNamePlaceholder, text: $draftName)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Apt / Suite / Floor")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    TextField("ex: Unit 4", text: $draftUnit)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            let parsed = ParsedLocation(address: locationAddress)
            draftAddressLine = parsed.addressLine
            draftCityStateLine = parsed.cityStateLine
            draftUnit = parsed.unit

            let currentName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            draftName = currentName == parsed.defaultDisplayName ? "" : currentName
        }
    }
}

private struct ParsedLocation {
    let addressLine: String
    let cityStateLine: String
    let unit: String

    var defaultDisplayName: String {
        addressLine.isEmpty ? "Name this location" : addressLine
    }

    init(address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addressLine = ""
            cityStateLine = ""
            unit = ""
            return
        }

        let unitMarkers = [" apt ", " apartment ", " unit ", " suite ", " ste ", " floor ", " fl ", " #"]
        let lowercased = trimmed.lowercased()

        var baseAddress = trimmed
        var trailingUnit = ""

        for marker in unitMarkers {
            if let range = lowercased.range(of: marker, options: .backwards) {
                let distance = lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
                baseAddress = String(trimmed.prefix(distance)).trimmingCharacters(in: .whitespacesAndNewlines)
                trailingUnit = String(trimmed.suffix(trimmed.count - distance)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        let components = baseAddress
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if components.count >= 4 {
            let lastComponent = components.last ?? ""
            let lastWords = lastComponent.split(separator: " ").map(String.init)
            let stateToken = lastWords.first ?? lastComponent
            let inlineUnit = lastWords.dropFirst().joined(separator: " ")

            addressLine = [components[0], components[1], trailingUnit.isEmpty ? inlineUnit : trailingUnit]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            cityStateLine = [components[2], stateToken]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            unit = ""
            return
        }

        if components.count == 3 {
            let lastComponent = components[2]
            let lastWords = lastComponent.split(separator: " ").map(String.init)
            if lastWords.count > 1 {
                let stateToken = lastWords.first ?? lastComponent
                let inlineUnit = lastWords.dropFirst().joined(separator: " ")
                addressLine = [components[0], trailingUnit.isEmpty ? inlineUnit : trailingUnit]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                cityStateLine = [components[1], stateToken]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                unit = ""
                return
            }
        }

        addressLine = [components.first ?? baseAddress, trailingUnit]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        cityStateLine = components.dropFirst().joined(separator: ", ")
        unit = ""
    }
}
