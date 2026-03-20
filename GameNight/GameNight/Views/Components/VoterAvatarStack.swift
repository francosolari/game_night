import SwiftUI

struct VoterAvatarStack: View {
    let voters: [(id: UUID, name: String, avatarUrl: String?)]
    var maxVisible: Int = 4
    var avatarSize: CGFloat = 24
    var onTap: (() -> Void)? = nil

    private var displayVoters: [(id: UUID, name: String, avatarUrl: String?)] {
        Array(voters.prefix(maxVisible))
    }

    private var overflow: Int {
        max(0, voters.count - maxVisible)
    }

    var body: some View {
        if voters.isEmpty { EmptyView() } else {
            Button {
                onTap?()
            } label: {
                HStack(spacing: -(avatarSize * 0.3)) {
                    ForEach(Array(displayVoters.enumerated()), id: \.element.id) { index, voter in
                        AvatarView(url: voter.avatarUrl, size: avatarSize)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.cardBackground, lineWidth: 2)
                            )
                            .zIndex(Double(maxVisible - index))
                    }

                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.system(size: avatarSize * 0.4, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(width: avatarSize, height: avatarSize)
                            .background(
                                Circle()
                                    .fill(Theme.Colors.fieldBackground)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Colors.cardBackground, lineWidth: 2)
                                    )
                            )
                            .zIndex(0)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
        }
    }
}
