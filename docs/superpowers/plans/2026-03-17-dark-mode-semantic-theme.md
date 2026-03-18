# Dark Mode Semantic Theme Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Roll the updated warm dark palette through the app while introducing semantic theme roles and preserving light-mode behavior exactly.

**Architecture:** Refactor the theme layer so both palettes map to semantic roles instead of literal color concepts, then keep the existing `Theme.Colors` API as compatibility aliases. Update the few controls that bypass semantic roles today so dark mode picks up the new surfaces, text, and tab treatments consistently.

**Tech Stack:** SwiftUI, UIKit appearance APIs, XCTest, Xcode project test target

---

### Task 1: Add theme mapping tests

**Files:**
- Modify: `GameNight/GameNightTests/Models/EventVisibilityTests.swift`
- Test: `GameNight/GameNightTests/Models/EventVisibilityTests.swift`

- [ ] **Step 1: Write failing tests**
- [ ] **Step 2: Run the targeted test command and verify the failures reflect missing semantic mappings**
- [ ] **Step 3: Implement the semantic palette refactor in the app target**
- [ ] **Step 4: Re-run the targeted tests and confirm they pass**

### Task 2: Refactor the theme layer

**Files:**
- Modify: `GameNight/GameNight/Theme/Theme.swift`
- Reference: `GameNight/GameNight/Theme/BrandGuide.swift`

- [ ] **Step 1: Add semantic palette properties and compatibility aliases**
- [ ] **Step 2: Map light-mode roles to the current rendered values**
- [ ] **Step 3: Map dark-mode roles to the updated warm palette values from `BrandGuide.Dark`**
- [ ] **Step 4: Keep gradients and existing screen call sites working through aliases**

### Task 3: Update dark-mode control consumers

**Files:**
- Modify: `GameNight/GameNight/Theme/ViewModifiers.swift`
- Modify: `GameNight/GameNight/App/ContentView.swift`
- Modify: `GameNight/GameNight/Views/Profile/ProfileView.swift`
- Modify: `GameNight/GameNight/Views/Components/SearchBar.swift`

- [ ] **Step 1: Apply semantic field, tab, and segmented-control roles**
- [ ] **Step 2: Preserve current light-mode visuals**
- [ ] **Step 3: Keep dark-mode button, text, and inactive tab contrast aligned with the new palette**

### Task 4: Sweep key text inputs

**Files:**
- Modify: `GameNight/GameNight/Views/Onboarding/OnboardingView.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift`
- Modify: `GameNight/GameNight/Views/Events/ActivityFeedView.swift`
- Modify: `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift`
- Modify: `GameNight/GameNight/Views/Profile/ProfileView.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventGamesStep.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventDetailsStep.swift`
- Modify: `GameNight/GameNight/Views/Components/LocationPickerSheet.swift`
- Modify: `GameNight/GameNight/Views/Components/TimeOptionPicker.swift`
- Modify: `GameNight/GameNight/Views/Groups/GroupsView.swift`
- Modify: `GameNight/GameNight/Views/Groups/CreateGroupFromAttendeesSheet.swift`

- [ ] **Step 1: Swap direct text-input fills from generic elevated surfaces to semantic field surfaces**
- [ ] **Step 2: Leave non-input elevated cards and chips unchanged**
- [ ] **Step 3: Verify the sweep does not alter light-mode values**

### Task 5: Verify

**Files:**
- Test: `GameNight/GameNightTests/Models/EventVisibilityTests.swift`

- [ ] **Step 1: Run focused `xcodebuild test` coverage for the updated theme tests**
- [ ] **Step 2: If available, run a broader build/test check for regression coverage**
- [ ] **Step 3: Summarize any remaining unverified UI-only behavior**
