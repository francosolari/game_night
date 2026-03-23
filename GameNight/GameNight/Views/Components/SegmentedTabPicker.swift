import SwiftUI

struct SegmentedTabPicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let options: [T]
    @Binding var selection: T

    @Namespace private var animation

    init(selection: Binding<T>, options: [T] = Array(T.allCases)) {
        self._selection = selection
        self.options = options
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(Theme.Animation.snappy) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(isSelected ? Theme.Colors.primaryActionText : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm - 1)
                                    .fill(Theme.Colors.primary)
                                    .matchedGeometryEffect(id: "segment", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.cardBackground)
        )
    }
}
