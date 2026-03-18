import SwiftUI

enum ComponentSize {
    case compact
    case standard
    case expanded

    var captionFont: Font {
        switch self {
        case .compact: return Theme.Typography.caption2
        case .standard: return Theme.Typography.caption
        case .expanded: return Theme.Typography.callout
        }
    }

    var bodyFont: Font {
        switch self {
        case .compact: return Theme.Typography.caption
        case .standard: return Theme.Typography.callout
        case .expanded: return Theme.Typography.body
        }
    }

    var titleFont: Font {
        switch self {
        case .compact: return Theme.Typography.calloutMedium
        case .standard: return Theme.Typography.headlineMedium
        case .expanded: return Theme.Typography.headlineLarge
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 11
        case .standard: return 13
        case .expanded: return 16
        }
    }

    var avatarSize: CGFloat {
        switch self {
        case .compact: return 16
        case .standard: return 20
        case .expanded: return 28
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return Theme.Spacing.xs
        case .standard: return Theme.Spacing.sm
        case .expanded: return Theme.Spacing.md
        }
    }
}
