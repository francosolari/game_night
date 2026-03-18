import SwiftUI

struct SortFilterBar: View {
    let options: [SortOption]
    @Binding var selected: SortOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(options) { option in
                    Button {
                        selected = option
                    } label: {
                        Text(option.rawValue)
                            .chipStyle(
                                color: Theme.Colors.primary,
                                isSelected: selected == option
                            )
                    }
                }
            }
        }
    }
}
