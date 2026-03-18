import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Search bar (expandable)
            if viewModel.showSearch {
                searchBar
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch viewModel.viewMode {
                case .calendar:
                    ScrollView {
                        EventCalendarGridView(viewModel: viewModel) { event in
                            navigateToEvent(event)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, 100)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    withAnimation(Theme.Animation.snappy) {
                                        viewModel.nextMonth()
                                    }
                                } else if value.translation.width > 50 {
                                    withAnimation(Theme.Animation.snappy) {
                                        viewModel.previousMonth()
                                    }
                                }
                            }
                    )
                case .list:
                    CalendarListView(viewModel: viewModel) { event in
                        navigateToEvent(event)
                    }
                }
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            viewModeToggle
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            CalendarFilterSheet(viewModel: viewModel)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Text(monthFormatter.string(from: viewModel.currentMonth))
                .font(Theme.Typography.displayLarge)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    withAnimation { viewModel.showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.cardBackground))
                }

                Button {
                    viewModel.showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.cardBackground))
                }

                Button {
                    withAnimation { viewModel.scrollToToday() }
                } label: {
                    Text("Today")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Capsule().fill(Theme.Colors.cardBackground)
                        )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textTertiary)
            TextField("Search events, games, hosts...", text: $viewModel.searchQuery)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { viewModel.viewMode = CalendarViewModel.ViewMode.calendar }
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.viewMode == .calendar ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
            }

            Button {
                withAnimation { viewModel.viewMode = .list }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.viewMode == .list ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.trailing, Theme.Spacing.xl)
        .padding(.bottom, 100)
    }

    // MARK: - Navigation

    private func navigateToEvent(_ event: GameEvent) {
        navigationPath.append(event)
    }
}
