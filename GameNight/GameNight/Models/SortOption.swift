import Foundation

enum SortOption: String, CaseIterable, Identifiable, Hashable {
    case topRated = "Top Rated"
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
