import Foundation

@MainActor
final class CreatorDetailViewModel: ObservableObject {
    @Published var name: String
    @Published var role: CreatorRole
    @Published var games: [Game] = []
    @Published var isLoading = true
    @Published var sortMode: SortOption = .topRated
    @Published var isExpanded = false

    private let supabase: SupabaseService
    private var hasMoreGames = false

    var displayedGames: [Game] {
        let sorted: [Game]
        switch sortMode {
        case .topRated:
            sorted = games.sorted { ($0.bggRating ?? 0) > ($1.bggRating ?? 0) }
        case .alphabetical:
            sorted = games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byYear:
            sorted = games.sorted { ($0.yearPublished ?? 0) > ($1.yearPublished ?? 0) }
        case .byWeight:
            sorted = games.sorted { $0.complexity > $1.complexity }
        case .recentlyAdded:
            sorted = games
        }
        return isExpanded ? sorted : Array(sorted.prefix(5))
    }

    var showExpandButton: Bool {
        !isExpanded && (games.count > 5 || hasMoreGames)
    }

    var subtitle: String {
        "\(role.rawValue) · \(games.count)\(hasMoreGames ? "+" : "") games"
    }

    var averageRating: Double? {
        let rated = games.compactMap(\.bggRating)
        guard !rated.isEmpty else { return nil }
        return rated.reduce(0, +) / Double(rated.count)
    }

    var averageWeight: Double? {
        let weights = games.map(\.complexity).filter { $0 > 0 }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }

    init(name: String, role: CreatorRole, supabase: SupabaseService = .shared) {
        self.name = name
        self.role = role
        self.supabase = supabase
    }

    func loadGames() async {
        isLoading = true
        do {
            switch role {
            case .designer:
                games = try await supabase.fetchGamesByDesigner(name: name)
            case .publisher:
                games = try await supabase.fetchGamesByPublisher(name: name)
            }
            hasMoreGames = games.count == 50
        } catch {
            // Non-critical
        }
        isLoading = false
    }

    func loadAllGames() async {
        // Re-fetch without limit — requires adding unlimited fetch methods
        // For now, the initial 50 is sufficient
        isExpanded = true
    }
}
