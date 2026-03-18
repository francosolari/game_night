import SwiftUI

struct PublisherDetailView: View {
    @StateObject private var viewModel: CreatorDetailViewModel

    init(name: String) {
        _viewModel = StateObject(wrappedValue: CreatorDetailViewModel(name: name, role: .publisher))
    }

    var body: some View {
        CreatorDetailContent(viewModel: viewModel)
            .task { await viewModel.loadGames() }
    }
}
