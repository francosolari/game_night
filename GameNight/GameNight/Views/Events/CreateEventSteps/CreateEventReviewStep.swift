import SwiftUI

struct CreateEventReviewStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @State private var showCoverCropPicker = false
    @State private var isUploadingCover = false
    @State private var coverUploadError: String?

    private var hasCustomCover: Bool {
        !viewModel.coverImageRemoved &&
        (viewModel.pendingCoverImageUrl != nil || viewModel.eventToEdit?.coverImageUrl != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Review & Send")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            coverArtSection

            // Preview card
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(viewModel.title)
                    .font(Theme.Typography.headlineLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                if !viewModel.location.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "mappin")
                            .foregroundColor(Theme.Colors.secondary)
                        Text(viewModel.location)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Games
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Games")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    if viewModel.selectedGames.isEmpty {
                        Text("No games selected — you can add later")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else {
                        ForEach(viewModel.selectedGames) { eventGame in
                            if let game = eventGame.game {
                                CompactGameCard(game: game, isPrimary: eventGame.isPrimary)
                            }
                        }
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Schedule
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(viewModel.scheduleMode == .fixed ? "Date" : "Time Options")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    if viewModel.scheduleMode == .fixed {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            if viewModel.hasDate {
                                let dateF: DateFormatter = {
                                    let f = DateFormatter()
                                    f.dateFormat = "EEE, MMM d"
                                    return f
                                }()
                                let timeF: DateFormatter = {
                                    let f = DateFormatter()
                                    f.dateFormat = "h:mm a"
                                    return f
                                }()
                                if viewModel.hasEndTime {
                                    Text("\(dateF.string(from: viewModel.fixedDate)) at \(timeF.string(from: viewModel.fixedStartTime)) - \(timeF.string(from: viewModel.fixedEndTime))")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                } else {
                                    Text("\(dateF.string(from: viewModel.fixedDate)) at \(timeF.string(from: viewModel.fixedStartTime))")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                            } else {
                                Text("Date not set")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    } else {
                        ForEach(viewModel.timeOptions) { option in
                            HStack {
                                Text(option.displayDate)
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(option.displayTime)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }

                        if viewModel.allowTimeSuggestions {
                            Text("Time suggestions enabled")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Invite summary
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Invites")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    Text("\(viewModel.tier1Invitees.count) playing")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if !viewModel.tier2Invitees.isEmpty {
                        Text("\(viewModel.tier2Invitees.count) on bench")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .cardStyle()

            if let error = viewModel.error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.error.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Cover Art Section

    private var coverArtSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Cover Art")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textTertiary)

                Spacer()

                if hasCustomCover {
                    Button {
                        print("[DEBUG] Remove cover tapped")
                        Task { await removeCoverPhoto() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                            Text("Remove")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.Colors.error.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        Button {
                            showCoverCropPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                if isUploadingCover {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 12))
                                }
                                Text(isUploadingCover ? "Uploading…" : "Upload")
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.12)))
                        }
                        .disabled(isUploadingCover)
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.coverVariant += 1
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                Text("Shuffle")
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let activeCoverUrl = viewModel.coverImageRemoved ? nil : (viewModel.pendingCoverImageUrl ?? viewModel.eventToEdit?.coverImageUrl)
            if let uploadedUrl = activeCoverUrl,
               let url = URL(string: uploadedUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 140)
                        .clipped()
                } placeholder: {
                    Color(Theme.Colors.backgroundElevated)
                        .overlay(ProgressView())
                        .frame(height: 140)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                .allowsHitTesting(false)
            } else {
                GenerativeEventCover(
                    title: viewModel.title,
                    eventId: viewModel.eventToEdit?.id ?? viewModel.previewEventId,
                    variant: viewModel.coverVariant
                )
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            }

            if let err = coverUploadError {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
        }
        .fullScreenCover(isPresented: $showCoverCropPicker) {
            ImageCropPicker(isPresented: $showCoverCropPicker) { image in
                Task { await uploadCoverPhoto(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func removeCoverPhoto() async {
        let urlToDelete = viewModel.pendingCoverImageUrl ?? viewModel.eventToEdit?.coverImageUrl
        let existingId = viewModel.eventToEdit?.id

        // Update UI immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.pendingCoverImageUrl = nil
            viewModel.coverImageRemoved = true
        }

        // Best-effort cleanup in background
        if let urlString = urlToDelete {
            let components = URL(string: urlString)?.pathComponents.dropFirst() ?? []
            let r2Path = components.joined(separator: "/")
            if !r2Path.isEmpty {
                do {
                    try await R2StorageService.shared.deleteImage(path: r2Path)
                } catch {
                    print("[R2] delete image failed (non-fatal): \(error)")
                }
            }
        }
        if let eventId = existingId {
            do {
                try await SupabaseService.shared.clearEventCoverImageUrl(eventId: eventId)
            } catch {
                print("[R2] clear cover URL in DB failed (non-fatal): \(error)")
            }
        }
    }

    private func uploadCoverPhoto(_ image: UIImage) async {
        isUploadingCover = true
        coverUploadError = nil
        defer { isUploadingCover = false }

        do {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                coverUploadError = "Could not process image"
                return
            }

            let eventId = viewModel.eventToEdit?.id ?? viewModel.previewEventId
            let publicUrl = try await R2StorageService.shared.uploadEventCover(data: jpeg, eventId: eventId)
            let cacheBustedUrl = publicUrl + "?v=\(Int(Date().timeIntervalSince1970))"

            // If editing an existing saved event, persist to DB immediately
            if let existingId = viewModel.eventToEdit?.id {
                try await SupabaseService.shared.updateEventCoverImageUrl(eventId: existingId, coverImageUrl: cacheBustedUrl)
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.coverImageRemoved = false
                viewModel.pendingCoverImageUrl = cacheBustedUrl
            }
        } catch {
            coverUploadError = "Upload failed: \(error.localizedDescription)"
        }
    }
}
