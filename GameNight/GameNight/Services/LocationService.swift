import Foundation
import MapKit
import Combine

/// Dedicated service for handling MapKit local search features
@MainActor
class LocationService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private var completer: MKLocalSearchCompleter
    private var cancellables = Set<AnyCancellable>()

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()

        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty {
                    self.searchResults = []
                } else {
                    self.isSearching = true
                    self.completer.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.searchResults = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location search failed: \(error.localizedDescription)")
            self.isSearching = false
        }
    }

    /// Fetches the MKPlacemark for a given completion
    func fetchPlacemark(for completion: MKLocalSearchCompletion) async throws -> MKPlacemark {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        let response = try await search.start()
        
        guard let item = response.mapItems.first else {
            throw NSError(domain: "LocationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Place not found"])
        }
        
        return item.placemark
    }
}
