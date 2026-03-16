import SwiftUI

// MARK: - Toast Data
struct ToastItem: Equatable {
    let id = UUID()
    var style: ToastStyle
    var message: String

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastStyle {
    case success
    case error
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return Theme.Colors.success
        case .error: return Theme.Colors.error
        case .info: return Theme.Colors.primary
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: ToastItem

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: toast.style.icon)
                .font(.system(size: 18))
                .foregroundColor(toast.style.color)

            Text(toast.message)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(toast.style.color.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastItem?
    var duration: TimeInterval = 2.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(toast: toast)
                        .padding(.top, Theme.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(Theme.Animation.snappy) {
                                    self.toast = nil
                                }
                            }
                        }
                }
            }
            .animation(Theme.Animation.snappy, value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<ToastItem?>, duration: TimeInterval = 2.5) -> some View {
        modifier(ToastModifier(toast: toast, duration: duration))
    }
}
