import SwiftUI

struct CreateEventReviewStep: View {
    @ObservedObject var viewModel: CreateEventViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Review & Send")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

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
}
