import Foundation

enum SortOption: String, CaseIterable, Identifiable, Hashable {
    case recentlyAdded = "Recent"
    case topRated = "Top Rated"
    case alphabetical = "A-Z"
    case byYear = "By Year"
    case byWeight = "By Weight"

    var id: String { rawValue }
}

enum CreatorRole: String, Hashable {
    case designer = "Game Designer"
    case publisher = "Publisher"
}

struct CreatorDestination: Hashable {
    let name: String
    let role: CreatorRole
}
