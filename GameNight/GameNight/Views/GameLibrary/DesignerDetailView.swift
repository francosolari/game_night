import SwiftUI

struct DesignerDetailView: View {
    @StateObject private var viewModel: CreatorDetailViewModel

    init(name: String) {
        _viewModel = StateObject(wrappedValue: CreatorDetailViewModel(name: name, role: .designer))
    }

    var body: some View {
        CreatorDetailContent(viewModel: viewModel)
            .task { await viewModel.loadGames() }
    }
}
