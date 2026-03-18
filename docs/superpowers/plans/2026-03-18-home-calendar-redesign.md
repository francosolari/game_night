# Home Page & Calendar View Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Home page with a horizontal carousel, add a Calendar view pushed from Home, and rebuild event cards using composable building blocks with size variants.

**Architecture:** Composable building blocks (`EventDateLabel`, `EventLocationLabel`, `PlayerCountIndicator`, `GameInfoCompact`, `HostBadge`) with a `ComponentSize` enum, composed into two card layout shells (`CompactEventCard`, `ListEventCard`). Calendar view with grid/list toggle, filtering, and search pushed from Home's NavigationStack. NavigationStack lifted from HomeView to MainTabView for tab-reset behavior.

**Tech Stack:** SwiftUI, iOS 17+, existing Theme system, existing SupabaseService data layer

**Spec:** `docs/superpowers/specs/2026-03-18-home-calendar-redesign-design.md`

---

## File Structure

```
GameNight/GameNight/
  Views/
    Components/
      EventCardBlocks/
        ComponentSize.swift              (new — size enum)
        EventDateLabel.swift             (new — date/time display)
        EventLocationLabel.swift         (new — location with access policy)
        PlayerCountIndicator.swift       (new — meeple icons or progress bar)
        GameInfoCompact.swift            (new — game name + complexity + playtime)
        HostBadge.swift                  (new — avatar + host name)
      CompactEventCard.swift             (new — carousel + calendar day card)
      ListEventCard.swift               (new — calendar list row)
    Home/
      HomeView.swift                     (modify — carousel, NavigationStack removal)
    Calendar/
      CalendarView.swift                 (new — main container with header)
      CalendarGridView.swift             (new — month grid)
      CalendarListView.swift             (new — chronological list)
      CalendarFilterSheet.swift          (new — RSVP status filter)
      CalendarDayDetailView.swift        (new — day detail below grid)
  ViewModels/
    CalendarViewModel.swift              (new — data, filters, search)
    HomeViewModel.swift                  (no changes needed)
  App/
    ContentView.swift                    (modify — NavigationStack + tab reset)
    AppState.swift                       (modify — add homeNavigationPath)
```

---

### Task 1: ComponentSize Enum

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/ComponentSize.swift`

- [ ] **Step 1: Create the ComponentSize enum**

```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/ComponentSize.swift
git commit -m "feat: add ComponentSize enum for building block size variants"
```

---

### Task 2: EventDateLabel Building Block

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/EventDateLabel.swift`
- Reference: `GameNight/GameNight/Models/GameEvent.swift` (TimeOption, ScheduleMode)
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:89-109` (existing date display logic)

- [ ] **Step 1: Create EventDateLabel**

```swift
import SwiftUI

struct EventDateLabel: View {
    let event: GameEvent
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: size.iconSize))
            Text(displayText)
                .font(size.captionFont)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(foregroundColor.opacity(0.15))
        )
    }

    private var iconName: String {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return "chart.bar.fill"
        }
        return "calendar"
    }

    private var foregroundColor: Color {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return Theme.Colors.accent
        }
        return Theme.Colors.dateAccent
    }

    private var displayText: String {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return "\(event.timeOptions.count) time options"
        }

        guard let timeOption = confirmedOrFirstTimeOption else {
            return "No date set"
        }

        return formatRelativeDate(timeOption)
    }

    private var confirmedOrFirstTimeOption: TimeOption? {
        if let confirmedId = event.confirmedTimeOptionId {
            return event.timeOptions.first { $0.id == confirmedId }
        }
        return event.timeOptions.first
    }

    private func formatRelativeDate(_ timeOption: TimeOption) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: timeOption.date)
        let dayDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timeStr = timeFormatter.string(from: timeOption.startTime)

        // Strip ":00" for on-the-hour times
        let cleanTime = timeStr.replacingOccurrences(of: ":00", with: "")

        if dayDiff == 0 {
            return "Today \u{00B7} \(cleanTime)"
        } else if dayDiff == 1 {
            return "Tomorrow \u{00B7} \(cleanTime)"
        } else if dayDiff > 1 && dayDiff < 7 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            return "\(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else if dayDiff >= 7 && dayDiff < 14 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            return "Next \(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else if dayDiff < 0 {
            // Past event
            if dayDiff == -1 {
                return "Yesterday \u{00B7} \(cleanTime)"
            }
            let dayFormatter = DateFormatter()
            if size == .compact {
                dayFormatter.dateFormat = "M/d"
            } else {
                dayFormatter.dateFormat = "EEE, MMM d"
            }
            return "Past \(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        } else {
            // Far future
            let dayFormatter = DateFormatter()
            if size == .compact {
                dayFormatter.dateFormat = "EEE M/d"
            } else {
                dayFormatter.dateFormat = "EEE, MMM d"
            }
            return "\(dayFormatter.string(from: timeOption.date)) \u{00B7} \(cleanTime)"
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/EventDateLabel.swift
git commit -m "feat: add EventDateLabel building block with relative date formatting"
```

---

### Task 3: EventLocationLabel Building Block

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/EventLocationLabel.swift`
- Reference: `GameNight/GameNight/Models/EventAccessPolicy.swift` (EventAccessPolicy, EventViewerRole)
- Reference: `GameNight/GameNight/Models/EventLocationPresentation.swift` (EventLocationPresentation)
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:8-42` (existing viewerRole + accessPolicy logic)

- [ ] **Step 1: Create EventLocationLabel**

This component reuses the existing `EventAccessPolicy` and `EventLocationPresentation` models. The caller must provide the viewer role context since it depends on current user session state.

```swift
import SwiftUI

struct EventLocationLabel: View {
    let event: GameEvent
    let viewerRole: EventViewerRole
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.system(size: size.iconSize))
            Text(displayText)
                .font(size.captionFont)
                .lineLimit(1)
        }
        .foregroundColor(Theme.Colors.textSecondary)
    }

    private var accessPolicy: EventAccessPolicy {
        EventAccessPolicy(
            visibility: event.visibility,
            viewerRole: viewerRole,
            rsvpDeadline: event.rsvpDeadline,
            allowGuestInvites: event.allowGuestInvites,
            now: Date()
        )
    }

    private var displayText: String {
        guard event.location != nil || event.locationAddress != nil else {
            return "TBD"
        }

        let presentation = EventLocationPresentation(
            locationName: event.location,
            locationAddress: event.locationAddress,
            canViewFullAddress: accessPolicy.canViewFullAddress
        )

        return presentation.title
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/EventLocationLabel.swift
git commit -m "feat: add EventLocationLabel building block with access policy"
```

---

### Task 4: PlayerCountIndicator Building Block

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/PlayerCountIndicator.swift`

- [ ] **Step 1: Create PlayerCountIndicator**

```swift
import SwiftUI

struct PlayerCountIndicator: View {
    let confirmedCount: Int
    let minPlayers: Int
    let maxPlayers: Int?
    var size: ComponentSize = .standard

    private var effectiveMax: Int {
        maxPlayers ?? minPlayers
    }

    private var useMeepleMode: Bool {
        effectiveMax <= 6
    }

    var body: some View {
        if useMeepleMode {
            meepleView
        } else {
            compactTextView
        }
    }

    // MARK: - Meeple Icon Mode (≤6 max)

    private var meepleIconSize: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 16
        case .expanded: return 20
        }
    }

    private var meepleView: some View {
        HStack(spacing: size == .compact ? 1 : 2) {
            ForEach(0..<effectiveMax, id: \.self) { index in
                Image(systemName: index < confirmedCount ? "person.fill" : "person")
                    .font(.system(size: meepleIconSize))
                    .foregroundColor(meepleColor(for: index))
            }
        }
    }

    private func meepleColor(for index: Int) -> Color {
        if index < confirmedCount {
            return Theme.Colors.success
        } else if index < minPlayers {
            return Theme.Colors.success.opacity(0.4)
        } else {
            return Theme.Colors.textTertiary.opacity(0.4)
        }
    }

    // MARK: - Compact Text Mode (>6 max)

    private var compactTextView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("\(confirmedCount)")
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("/")
                    .foregroundColor(Theme.Colors.textTertiary)
                Text("\(minPlayers)")
                    .foregroundColor(Theme.Colors.success)
                if let max = maxPlayers, max != minPlayers {
                    Text("-\(max)")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .font(size.captionFont)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.Colors.textTertiary.opacity(0.2))
                        .frame(height: 3)

                    // Fill
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.Colors.success)
                        .frame(width: fillWidth(totalWidth: geo.size.width), height: 3)

                    // Min threshold marker
                    if effectiveMax > 0 {
                        let minPosition = CGFloat(minPlayers) / CGFloat(effectiveMax) * geo.size.width
                        Rectangle()
                            .fill(Theme.Colors.success.opacity(0.5))
                            .frame(width: 1, height: 5)
                            .offset(x: minPosition)
                    }
                }
            }
            .frame(height: 5)
        }
    }

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        guard effectiveMax > 0 else { return 0 }
        let ratio = CGFloat(min(confirmedCount, effectiveMax)) / CGFloat(effectiveMax)
        return totalWidth * ratio
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/PlayerCountIndicator.swift
git commit -m "feat: add PlayerCountIndicator with meeple icons and progress bar modes"
```

---

### Task 5: GameInfoCompact Building Block

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/GameInfoCompact.swift`
- Reference: `GameNight/GameNight/Views/Components/GameCard.swift:183-197` (ComplexityDot)
- Reference: `GameNight/GameNight/Models/Game.swift:47-52` (playtimeDisplay)
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:127-146` (existing game list)

- [ ] **Step 1: Create GameInfoCompact**

```swift
import SwiftUI

struct GameInfoCompact: View {
    let games: [EventGame]
    var size: ComponentSize = .standard

    private var displayCount: Int {
        switch size {
        case .compact: return 1
        case .standard, .expanded: return 2
        }
    }

    private var primaryGames: [EventGame] {
        let sorted = games.sorted { ($0.isPrimary ? 0 : 1) < ($1.isPrimary ? 0 : 1) }
        return Array(sorted.prefix(displayCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 1 : Theme.Spacing.xs) {
            ForEach(primaryGames) { eventGame in
                if let game = eventGame.game {
                    HStack(spacing: 4) {
                        if eventGame.isPrimary {
                            Image(systemName: "star.fill")
                                .font(.system(size: size == .compact ? 8 : 10))
                                .foregroundColor(Theme.Colors.highlight)
                        }
                        Text(game.name)
                            .font(size.captionFont)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        ComplexityDot(weight: game.complexity)
                        Text(game.playtimeDisplay)
                            .font(size == .compact ? Theme.Typography.caption2 : Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/GameInfoCompact.swift
git commit -m "feat: add GameInfoCompact building block with complexity and playtime"
```

---

### Task 6: HostBadge Building Block

**Files:**
- Create: `GameNight/GameNight/Views/Components/EventCardBlocks/HostBadge.swift`
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:149-157` (existing host display)
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:203-232` (AvatarView)

- [ ] **Step 1: Create HostBadge**

```swift
import SwiftUI

struct HostBadge: View {
    let host: User?
    let isCurrentUserHost: Bool
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            if let host {
                AvatarView(url: host.avatarUrl, size: size.avatarSize)
            }
            Text(displayText)
                .font(size.captionFont)
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var displayText: String {
        if isCurrentUserHost {
            return "You \u{00B7} Hosting"
        }
        if let host {
            return host.displayName
        }
        return "Unknown host"
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/EventCardBlocks/HostBadge.swift
git commit -m "feat: add HostBadge building block with avatar and host name"
```

---

### Task 7: CompactEventCard Layout Shell

**Files:**
- Create: `GameNight/GameNight/Views/Components/CompactEventCard.swift`
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:1-42` (viewerRole computation pattern)
- Reference: `GameNight/GameNight/Views/Components/EventCard.swift:182-200` (InviteStatusBadge)
- Reference: `GameNight/GameNight/Views/Components/GameCard.swift:122-157` (GameThumbnail)

- [ ] **Step 1: Create CompactEventCard**

```swift
import SwiftUI

struct CompactEventCard: View {
    let event: GameEvent
    var myInvite: Invite?
    var confirmedCount: Int = 0
    var onTap: (() -> Void)?

    private var isCurrentUserHost: Bool {
        event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var viewerRole: EventViewerRole {
        if isCurrentUserHost { return .host }
        if let status = myInvite?.status, status == .accepted || status == .maybe {
            return .rsvpd
        }
        if myInvite != nil { return .invitedNotRSVPd }
        return .publicViewer
    }

    private var coverImageUrl: String? {
        event.coverImageUrl ?? event.games.first(where: { $0.isPrimary })?.game?.imageUrl ?? event.games.first?.game?.imageUrl
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                // Cover image
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(width: 100, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status)
                            .scaleEffect(0.85)
                            .padding(4)
                    }
                }

                // Info stack
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    EventDateLabel(event: event, size: .compact)

                    Text(event.title)
                        .font(ComponentSize.compact.titleFont)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .compact)

                    if !event.games.isEmpty {
                        GameInfoCompact(games: event.games, size: .compact)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .compact)
                        Spacer()
                        PlayerCountIndicator(
                            confirmedCount: confirmedCount,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            size: .compact
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.sm)
            .frame(height: 136)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let urlString = coverImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                gradientPlaceholder
            }
        } else {
            gradientPlaceholder
        }
    }

    private var gradientPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
            .fill(Theme.Gradients.eventCard)
            .overlay {
                if let game = event.games.first?.game {
                    GameThumbnail(url: game.thumbnailUrl, size: 40)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.textTertiary.opacity(0.5))
                }
            }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/CompactEventCard.swift
git commit -m "feat: add CompactEventCard layout shell composing building blocks"
```

---

### Task 8: ListEventCard Layout Shell

**Files:**
- Create: `GameNight/GameNight/Views/Components/ListEventCard.swift`

- [ ] **Step 1: Create ListEventCard**

```swift
import SwiftUI

struct ListEventCard: View {
    let event: GameEvent
    var myInvite: Invite?
    var confirmedCount: Int = 0
    var onTap: (() -> Void)?

    private var isCurrentUserHost: Bool {
        event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var viewerRole: EventViewerRole {
        if isCurrentUserHost { return .host }
        if let status = myInvite?.status, status == .accepted || status == .maybe {
            return .rsvpd
        }
        if myInvite != nil { return .invitedNotRSVPd }
        return .publicViewer
    }

    private var coverImageUrl: String? {
        event.coverImageUrl ?? event.games.first(where: { $0.isPrimary })?.game?.imageUrl ?? event.games.first?.game?.imageUrl
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Cover image
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status)
                            .scaleEffect(0.75)
                            .padding(2)
                    }
                }

                // Info stack
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    EventDateLabel(event: event, size: .standard)

                    Text(event.title)
                        .font(ComponentSize.standard.titleFont)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .standard)

                    if !event.games.isEmpty {
                        GameInfoCompact(games: event.games, size: .standard)
                    }

                    HStack {
                        HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .compact)
                        Spacer()
                        PlayerCountIndicator(
                            confirmedCount: confirmedCount,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            size: .standard
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let urlString = coverImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                gradientPlaceholder
            }
        } else {
            gradientPlaceholder
        }
    }

    private var gradientPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
            .fill(Theme.Gradients.eventCard)
            .overlay {
                if let game = event.games.first?.game {
                    GameThumbnail(url: game.thumbnailUrl, size: 32)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.textTertiary.opacity(0.5))
                }
            }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Components/ListEventCard.swift
git commit -m "feat: add ListEventCard layout shell for calendar list mode"
```

---

### Task 9: Lift NavigationStack to MainTabView + Home Tab Reset

**Files:**
- Modify: `GameNight/GameNight/App/ContentView.swift:1-45` (MainTabView)
- Modify: `GameNight/GameNight/Views/Home/HomeView.swift:9-10,140-142` (remove NavigationStack)

- [ ] **Step 1: Add NavigationStack and tab reset to MainTabView**

In `ContentView.swift`, add a `@State private var homeNavigationPath = NavigationPath()` to `MainTabView`, and a `@State private var previousTab: AppState.Tab = .home` to track re-selection. Wrap the `HomeView()` in a `NavigationStack(path: $homeNavigationPath)` with `.navigationDestination` for `GameEvent.self`. Add `.onChange(of: appState.selectedTab)` handler to detect Home tab re-tap and reset the path.

Modify `MainTabView`:
```swift
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showCreateEvent = false
    @State private var homeNavigationPath = NavigationPath()
    @State private var previousTab: AppState.Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                NavigationStack(path: $homeNavigationPath) {
                    HomeView(navigationPath: $homeNavigationPath)
                        .navigationDestination(for: GameEvent.self) { event in
                            EventDetailView(eventId: event.id)
                        }
                }
                .tag(AppState.Tab.home)

                GameLibraryView()
                    .tag(AppState.Tab.games)

                Color.clear
                    .tag(AppState.Tab.create)

                GroupsView()
                    .tag(AppState.Tab.groups)

                ProfileView()
                    .tag(AppState.Tab.profile)
            }

            CustomTabBar(selectedTab: $appState.selectedTab, onCreateTap: {
                showCreateEvent = true
            })
        }
        .sheet(isPresented: $showCreateEvent) {
            CreateEventView()
                .environmentObject(appState)
        }
        .onChange(of: appState.selectedTab) { oldTab, newTab in
            if newTab == .create {
                showCreateEvent = true
                appState.selectedTab = .home
                return
            }
            // Reset home navigation on re-tap
            if newTab == .home && oldTab == .home {
                homeNavigationPath = NavigationPath()
            }
            previousTab = newTab
        }
    }
}
```

- [ ] **Step 2: Remove NavigationStack from HomeView**

In `HomeView.swift`, change the `body` to remove the `NavigationStack` wrapper and the `.navigationDestination(item: $selectedEvent)` modifier. Replace `selectedEvent` state with navigation path append. Add a `@Binding var navigationPath: NavigationPath` parameter.

Key changes to `HomeView`:
- Add `@Binding var navigationPath: NavigationPath`
- Remove `@State private var selectedEvent: GameEvent?`
- Remove `NavigationStack {` wrapper (line 10) and its closing brace (line 143)
- Remove `.navigationDestination(item: $selectedEvent)` (lines 140-142)
- Remove `.onChange(of: selectedEvent)` (lines 147-151)
- Change `EventCard` onTap to `navigationPath.append(event)` instead of `selectedEvent = event`

The new `HomeView` signature:
```swift
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @State private var draftToResume: GameEvent?
    // ... rest of body without NavigationStack wrapper
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/App/ContentView.swift GameNight/GameNight/Views/Home/HomeView.swift
git commit -m "refactor: lift NavigationStack to MainTabView with home tab reset behavior"
```

---

### Task 10: Home Page Carousel ("Next Up")

**Files:**
- Modify: `GameNight/GameNight/Views/Home/HomeView.swift:114-131` (replace Upcoming vertical list with carousel)

- [ ] **Step 1: Replace the Upcoming Events section with carousel**

In `HomeView.swift`, replace the `// Upcoming Events` VStack (lines 114-131) with the new carousel section:

```swift
// Next Up — horizontal carousel
VStack(alignment: .leading, spacing: Theme.Spacing.md) {
    SectionHeader(title: "Next Up", action: "View all") {
        navigationPath.append(CalendarDestination())
    }
    .padding(.horizontal, Theme.Spacing.xl)

    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(viewModel.upcomingEvents) { event in
                CompactEventCard(
                    event: event,
                    myInvite: viewModel.invite(for: event.id),
                    confirmedCount: viewModel.confirmedCount(for: event.id)
                ) {
                    navigationPath.append(event)
                }
                .frame(width: carouselCardWidth)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
}
```

Also add a computed property for card width:
```swift
private var carouselCardWidth: CGFloat {
    let screenWidth = UIScreen.main.bounds.width
    let padding = Theme.Spacing.xl * 2
    let spacing = Theme.Spacing.md
    return (screenWidth - padding - spacing) / 2.15
}
```

- [ ] **Step 2: Add CalendarDestination type and navigation destination**

Add a simple `CalendarDestination` struct (can be in HomeView.swift or a shared file) for type-safe navigation:

```swift
struct CalendarDestination: Hashable {}
```

In `ContentView.swift`, add a `.navigationDestination` for it inside the `NavigationStack`:
```swift
.navigationDestination(for: CalendarDestination.self) { _ in
    CalendarView()
}
```

- [ ] **Step 3: Add confirmedCount helper to HomeViewModel**

In `HomeViewModel.swift`, add:
```swift
func confirmedCount(for eventId: UUID) -> Int {
    myInvites.filter { $0.eventId == eventId && $0.status == .accepted }.count
}
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (CalendarView doesn't exist yet — create a placeholder)

Create a placeholder `CalendarView` first to unblock compilation:
```swift
// GameNight/GameNight/Views/Calendar/CalendarView.swift
import SwiftUI

struct CalendarView: View {
    var body: some View {
        Text("Calendar — coming soon")
            .navigationTitle("Calendar")
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add GameNight/GameNight/Views/Home/HomeView.swift GameNight/GameNight/App/ContentView.swift GameNight/GameNight/ViewModels/HomeViewModel.swift GameNight/GameNight/Views/Calendar/CalendarView.swift
git commit -m "feat: replace Upcoming section with horizontal carousel and View All navigation"
```

---

### Task 11: CalendarViewModel

**Files:**
- Create: `GameNight/GameNight/ViewModels/CalendarViewModel.swift`
- Reference: `GameNight/GameNight/ViewModels/HomeViewModel.swift` (data fetching pattern)
- Reference: `GameNight/GameNight/Services/SupabaseService.swift:140-200` (fetch methods)
- Reference: `GameNight/GameNight/Models/Invite.swift:42-82` (InviteStatus)
- Reference: `GameNight/GameNight/Models/GameEvent.swift:201-207` (EventStatus)

- [ ] **Step 1: Create CalendarViewModel**

```swift
import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    // MARK: - Data
    @Published var allEvents: [GameEvent] = []
    @Published var invitesByEventId: [UUID: Invite] = [:]
    @Published var isLoading = true
    @Published var error: String?

    // MARK: - UI State
    @Published var selectedDate: Date? = nil
    @Published var currentMonth: Date = Date()
    @Published var viewMode: ViewMode = .calendar
    @Published var searchQuery: String = ""
    @Published var showFilterSheet = false
    @Published var showSearch = false

    // MARK: - Filters
    @Published var activeFilters: Set<FilterCategory> = FilterCategory.defaultActive

    enum ViewMode {
        case calendar
        case list
    }

    enum FilterCategory: String, CaseIterable, Identifiable {
        case myEvents = "My events"
        case attending = "Attending"
        case deciding = "Deciding"
        case waitingOnHost = "Waiting on host"
        case notGoing = "Not going"

        var id: String { rawValue }

        static var defaultActive: Set<FilterCategory> {
            [.myEvents, .attending, .deciding, .waitingOnHost]
        }
    }

    private let supabase: any HomeDataProviding

    init(supabase: any HomeDataProviding = SupabaseService.shared) {
        self.supabase = supabase
    }

    // MARK: - Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            async let eventsTask = supabase.fetchUpcomingEvents()
            async let invitesTask = supabase.fetchMyInvites()

            let (events, invites) = try await (eventsTask, invitesTask)

            // Also fetch events from accepted invites that might not be in upcoming
            let existingIds = Set(events.map(\.id))
            let missingIds = Set(invites.map(\.eventId)).subtracting(existingIds)

            var allFetched = events
            if !missingIds.isEmpty {
                let additional = try await supabase.fetchEvents(ids: Array(missingIds))
                allFetched.append(contentsOf: additional)
            }

            self.allEvents = allFetched.sorted { eventSortDate($0) < eventSortDate($1) }
            self.invitesByEventId = Dictionary(uniqueKeysWithValues: invites.map { ($0.eventId, $0) })
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtering

    var filteredEvents: [GameEvent] {
        var events = allEvents

        // Apply RSVP filters
        events = events.filter { event in
            let invite = invitesByEventId[event.id]
            let isHost = event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id

            if activeFilters.contains(.myEvents) && isHost { return true }
            if activeFilters.contains(.attending) && invite?.status == .accepted { return true }
            if activeFilters.contains(.deciding) && (invite?.status == .pending || invite?.status == .maybe) { return true }
            if activeFilters.contains(.waitingOnHost) && invite?.status == .waitlisted { return true }
            if activeFilters.contains(.notGoing) {
                if invite?.status == .declined || invite?.status == .expired { return true }
                if event.status == .cancelled { return true }
            }
            return false
        }

        // Apply search
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            events = events.filter { event in
                event.title.lowercased().contains(query) ||
                event.games.contains { $0.game?.name.lowercased().contains(query) ?? false } ||
                (event.host?.displayName.lowercased().contains(query) ?? false)
            }
        }

        return events
    }

    // MARK: - Calendar Helpers

    func events(for date: Date) -> [GameEvent] {
        let calendar = Calendar.current
        return filteredEvents.filter { event in
            guard let timeOption = event.timeOptions.first else { return false }
            return calendar.isDate(timeOption.date, inSameDayAs: date)
        }
    }

    func hasEvents(on date: Date) -> Bool {
        !events(for: date).isEmpty
    }

    func confirmedCount(for eventId: UUID) -> Int {
        // We only have the current user's invite locally.
        // For full counts, the event detail view fetches all invites.
        // Here we return 0 as a baseline — a future enhancement could
        // include invite counts in the event query.
        0
    }

    func invite(for eventId: UUID) -> Invite? {
        invitesByEventId[eventId]
    }

    func resetFilters() {
        activeFilters = FilterCategory.defaultActive
    }

    func scrollToToday() {
        currentMonth = Date()
        selectedDate = Date()
    }

    // MARK: - Helpers

    private func eventSortDate(_ event: GameEvent) -> Date {
        event.timeOptions.first?.date ?? event.createdAt
    }

    /// Returns events grouped by day for list mode
    var eventsByDay: [(date: Date, events: [GameEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event -> Date in
            let eventDate = event.timeOptions.first?.date ?? event.createdAt
            return calendar.startOfDay(for: eventDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, events: $0.value) }
    }

    var todayIndex: Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return eventsByDay.firstIndex { $0.date >= today }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/ViewModels/CalendarViewModel.swift
git commit -m "feat: add CalendarViewModel with filtering, search, and date grouping"
```

---

### Task 12: CalendarFilterSheet

**Files:**
- Create: `GameNight/GameNight/Views/Calendar/CalendarFilterSheet.swift`
- Reference: `GameNight/GameNight/ViewModels/CalendarViewModel.swift` (FilterCategory)

- [ ] **Step 1: Create CalendarFilterSheet**

```swift
import SwiftUI

struct CalendarFilterSheet: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let filterIcons: [CalendarViewModel.FilterCategory: String] = [
        .myEvents: "crown.fill",
        .attending: "checkmark.circle.fill",
        .deciding: "questionmark.circle.fill",
        .waitingOnHost: "hourglass",
        .notGoing: "xmark.circle.fill"
    ]

    private let filterIconColors: [CalendarViewModel.FilterCategory: Color] = [
        .myEvents: Theme.Colors.highlight,
        .attending: Theme.Colors.success,
        .deciding: Theme.Colors.warning,
        .waitingOnHost: Theme.Colors.textTertiary,
        .notGoing: Theme.Colors.error
    ]

    private let filterDescriptions: [CalendarViewModel.FilterCategory: String] = [
        .myEvents: "Hosting / Hosted",
        .attending: "Going / On the List",
        .deciding: "Invited / Maybe / Interested",
        .waitingOnHost: "Pending / Waitlisted / Responded",
        .notGoing: "Can't Go / Not approved / Canceled"
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Theme.Colors.textTertiary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.Spacing.sm)

            // Filter rows
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(CalendarViewModel.FilterCategory.allCases) { category in
                    filterRow(category)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            // Bottom buttons
            HStack {
                Button("Reset") {
                    viewModel.resetFilters()
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button("Done") {
                    viewModel.showFilterSheet = false
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.cardBackground)
                )
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func filterRow(_ category: CalendarViewModel.FilterCategory) -> some View {
        Button {
            if viewModel.activeFilters.contains(category) {
                viewModel.activeFilters.remove(category)
            } else {
                viewModel.activeFilters.insert(category)
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: filterIcons[category] ?? "circle")
                    .font(.system(size: 22))
                    .foregroundColor(filterIconColors[category] ?? Theme.Colors.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(filterDescriptions[category] ?? "")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: viewModel.activeFilters.contains(category) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.activeFilters.contains(category) ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Calendar/CalendarFilterSheet.swift
git commit -m "feat: add CalendarFilterSheet with RSVP status filter categories"
```

---

### Task 13: CalendarGridView

**Files:**
- Create: `GameNight/GameNight/Views/Calendar/CalendarGridView.swift`
- Reference: `GameNight/GameNight/Models/Game.swift:18` (categories field)

- [ ] **Step 1: Create CalendarGridView**

```swift
import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date {
                        dayCellView(date: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            // Selected day detail
            if let selectedDate = viewModel.selectedDate {
                let dayEvents = viewModel.events(for: selectedDate)
                if !dayEvents.isEmpty {
                    CalendarDayDetailView(
                        date: selectedDate,
                        events: dayEvents,
                        viewModel: viewModel,
                        onEventTap: onEventTap
                    )
                }
            }
        }
    }

    private func dayCellView(date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = viewModel.selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayEvents = viewModel.events(for: date)

        return Button {
            withAnimation(Theme.Animation.snappy) {
                viewModel.selectedDate = isSelected ? nil : date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(Theme.Typography.callout)
                    .foregroundColor(isToday ? Theme.Colors.primary : Theme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background {
                        if isToday {
                            Circle().stroke(Theme.Colors.primary, lineWidth: 1.5)
                        }
                        if isSelected {
                            Circle().fill(Theme.Colors.primary.opacity(0.15))
                        }
                    }

                if let firstEvent = dayEvents.first {
                    Image(systemName: gameCategoryIcon(for: firstEvent))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Circle()
                        .fill(rsvpDotColor(for: firstEvent))
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(height: 14)
                    Color.clear.frame(height: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let month = viewModel.currentMonth

        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = weekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func gameCategoryIcon(for event: GameEvent) -> String {
        guard let primaryGame = event.games.first(where: { $0.isPrimary })?.game ?? event.games.first?.game else {
            return "gamecontroller.fill"
        }

        for category in primaryGame.categories {
            let lower = category.lowercased()
            if lower.contains("strategy") || lower.contains("board") { return "dice.fill" }
            if lower.contains("card") { return "suit.spade.fill" }
            if lower.contains("puzzle") || lower.contains("escape") { return "puzzlepiece.fill" }
            if lower.contains("party") || lower.contains("social") { return "person.3.fill" }
        }

        return "gamecontroller.fill"
    }

    private func rsvpDotColor(for event: GameEvent) -> Color {
        // Hosts are implicitly "going"
        let isHost = event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
        if isHost { return Theme.Colors.success }

        guard let invite = viewModel.invite(for: event.id) else {
            return Theme.Colors.dateAccent
        }

        return invite.status.color
    }
}
```

- [ ] **Step 2: Create CalendarDayDetailView**

```swift
// GameNight/GameNight/Views/Calendar/CalendarDayDetailView.swift
import SwiftUI

struct CalendarDayDetailView: View {
    let date: Date
    let events: [GameEvent]
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private var headerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE \u{00B7} MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Theme.Colors.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 5)
                Spacer()
            }

            Text(headerText)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textSecondary)

            ForEach(events) { event in
                CompactEventCard(
                    event: event,
                    myInvite: viewModel.invite(for: event.id),
                    confirmedCount: viewModel.confirmedCount(for: event.id)
                ) {
                    onEventTap(event)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/Views/Calendar/CalendarGridView.swift GameNight/GameNight/Views/Calendar/CalendarDayDetailView.swift
git commit -m "feat: add CalendarGridView with month grid and day detail expansion"
```

---

### Task 14: CalendarListView

**Files:**
- Create: `GameNight/GameNight/Views/Calendar/CalendarListView.swift`

- [ ] **Step 1: Create CalendarListView**

```swift
import SwiftUI

struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE MMMM d"
        return f
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(Array(viewModel.eventsByDay.enumerated()), id: \.element.date) { index, group in
                        // Today divider
                        if let todayIndex = viewModel.todayIndex, index == todayIndex {
                            todayDivider
                                .id("today")
                        }

                        // Day header
                        Text(dayFormatter.string(from: group.date))
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.xl)

                        // Events for this day
                        ForEach(group.events) { event in
                            let isPast = group.date < Calendar.current.startOfDay(for: Date())
                            ListEventCard(
                                event: event,
                                myInvite: viewModel.invite(for: event.id),
                                confirmedCount: viewModel.confirmedCount(for: event.id)
                            ) {
                                onEventTap(event)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                            .opacity(isPast ? 0.7 : 1.0)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                proxy.scrollTo("today", anchor: .top)
            }
        }
    }

    private var todayDivider: some View {
        HStack {
            VStack { Divider() }
            Text("Today")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primary)
                .padding(.horizontal, Theme.Spacing.sm)
            VStack { Divider() }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Calendar/CalendarListView.swift
git commit -m "feat: add CalendarListView with day grouping, today anchor, and past event dimming"
```

---

### Task 15: Full CalendarView (Container)

**Files:**
- Modify: `GameNight/GameNight/Views/Calendar/CalendarView.swift` (replace placeholder)

- [ ] **Step 1: Replace placeholder CalendarView with full implementation**

```swift
import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Search bar (expandable)
            if viewModel.showSearch {
                searchBar
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch viewModel.viewMode {
                case .calendar:
                    ScrollView {
                        CalendarGridView(viewModel: viewModel) { event in
                            navigateToEvent(event)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, 100)
                    }
                case .list:
                    CalendarListView(viewModel: viewModel) { event in
                        navigateToEvent(event)
                    }
                }
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            viewModeToggle
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            CalendarFilterSheet(viewModel: viewModel)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Text(monthFormatter.string(from: viewModel.currentMonth))
                .font(Theme.Typography.displayLarge)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    withAnimation { viewModel.showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.cardBackground))
                }

                Button {
                    viewModel.showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.cardBackground))
                }

                Button {
                    withAnimation { viewModel.scrollToToday() }
                } label: {
                    Text("Today")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Capsule().fill(Theme.Colors.cardBackground)
                        )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textTertiary)
            TextField("Search events, games, hosts...", text: $viewModel.searchQuery)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { viewModel.viewMode = .calendar }
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.viewMode == .calendar ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
            }

            Button {
                withAnimation { viewModel.viewMode = .list }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.viewMode == .list ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.trailing, Theme.Spacing.xl)
        .padding(.bottom, 100)
    }

    // MARK: - Navigation

    private func navigateToEvent(_ event: GameEvent) {
        navigationPath.append(event)
    }
}
```

**Important:** The `CalendarView` must accept a `@Binding var navigationPath: NavigationPath` so it can push event detail views directly onto the home navigation stack. Update the `CalendarView` instantiation in `ContentView.swift`'s `.navigationDestination`:
```swift
.navigationDestination(for: CalendarDestination.self) { _ in
    CalendarView(navigationPath: $homeNavigationPath)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/Views/Calendar/CalendarView.swift
git commit -m "feat: add full CalendarView with grid/list toggle, search, and filter sheet"
```

---

### Task 16: Month Navigation (Swipe)

**Files:**
- Modify: `GameNight/GameNight/Views/Calendar/CalendarGridView.swift`
- Modify: `GameNight/GameNight/Views/Calendar/CalendarView.swift`

- [ ] **Step 1: Add month navigation gestures to CalendarView**

Wrap the `CalendarGridView` in a `TabView` with `.page` style for swipe-based month navigation, or add a `DragGesture` handler. The simpler approach: add next/previous month buttons and a swipe gesture.

Add to `CalendarViewModel`:
```swift
func previousMonth() {
    if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
        currentMonth = newMonth
        selectedDate = nil
    }
}

func nextMonth() {
    if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
        currentMonth = newMonth
        selectedDate = nil
    }
}
```

Add a `.gesture(DragGesture(...))` to the `CalendarGridView` wrapper in `CalendarView` that calls `previousMonth()` on right swipe and `nextMonth()` on left swipe (using `onEnded` with threshold of 50pt horizontal translation).

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GameNight/GameNight/ViewModels/CalendarViewModel.swift GameNight/GameNight/Views/Calendar/CalendarView.swift
git commit -m "feat: add month swipe navigation to calendar grid"
```

---

### Task 17: Integration Testing & Polish

**Files:**
- Modify: Various — fix any compilation issues, adjust spacing/sizing

- [ ] **Step 1: Full build verification**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

Fix any compilation errors that arise from integration.

- [ ] **Step 2: Regenerate Xcode project**

Run: `cd GameNight && xcodegen generate`
Expected: "Generated GameNight.xcodeproj"

The project auto-discovers new files from the `GameNight/` source directory based on `project.yml`, so new files should already be included. Regenerate to ensure the project file is clean.

- [ ] **Step 3: Final build after regeneration**

Run: `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: integration fixes and xcode project regeneration"
```
