import SwiftUI
import MapKit

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding to the caller's state
    @Binding var locationName: String
    @Binding var locationAddress: String
    
    @StateObject private var locationService = LocationService()
    @State private var selectedPlacemark: MKPlacemark? = nil
    
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
    
    private var fullAddressString: String {
        let parts = [
            placemark.subThoroughfare, // street number
            placemark.thoroughfare,    // street name
            placemark.locality,        // city
            placemark.administrativeArea // state
        ].compactMap { $0 }
        
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
                Text(fullAddressString)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textSecondary)
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
                                .fill(Theme.Colors.cardBackgroundHover)
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
                                .fill(Theme.Colors.cardBackgroundHover)
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
                    var finalAddress = fullAddressString
                    if !aptSuite.isEmpty {
                        finalAddress += " " + aptSuite 
                    }
                    onSave(finalName, finalAddress)
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

// MARK: - Selected Location Edit Sheet
struct CustomLocationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var locationName: String
    @Binding var locationAddress: String
    
    let onSearchAgain: () -> Void
    let onRemove: () -> Void
    
    @State private var draftName: String = ""
    @State private var draftAddress: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                // Edit Fields
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Display name")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        TextField("Name this location", text: $draftName)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.cardBackgroundHover)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Address (optional)")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        TextField("ex: 123 Main St, Apt 4B", text: $draftAddress)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.cardBackgroundHover)
                            )
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                
                // Action Buttons
                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSearchAgain()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search new address")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Capsule().stroke(Theme.Colors.secondary.opacity(0.3), lineWidth: 1))
                        .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    Button {
                        onRemove()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove location")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)

                Spacer()
            }
            .padding(.top, Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        locationName = draftName
                        locationAddress = draftAddress
                        dismiss()
                    }
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.Colors.secondary.opacity(0.2)))
                }
            }
            .onAppear {
                draftName = locationName
                draftAddress = locationAddress
            }
        }
    }
}
