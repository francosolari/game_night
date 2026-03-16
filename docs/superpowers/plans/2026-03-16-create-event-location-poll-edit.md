# Create Event Location And Poll Edit Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let existing locations open an edit sheet and let poll date cards be explicitly added, edited, and deleted without restarting the flow.

**Architecture:** Keep the current screen structure in `CreateEventView`, but swap fragile index-based poll editing for stable `TimeOption` identifiers and reuse the existing location edit component. Poll option creation and editing should only persist from explicit save actions.

**Tech Stack:** SwiftUI, XCTest, Xcodebuild

---

## Chunk 1: Poll Option Model Flow

### Task 1: Add failing tests for stable poll option edit/delete behavior

**Files:**
- Modify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run the targeted test to verify it fails**
- [ ] **Step 3: Implement minimal view-model support for update/remove by id**
- [ ] **Step 4: Run the targeted test to verify it passes**

## Chunk 2: Create Event UI Wiring

### Task 2: Wire location edit sheet and explicit poll add/edit sheets

**Files:**
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift`
- Reference: `GameNight/GameNight/Views/Components/LocationPickerSheet.swift`
- Reference: `GameNight/GameNight/Views/Events/DateTimePickerSheet.swift`

- [ ] **Step 1: Present `CustomLocationEditSheet` when a saved location is tapped**
- [ ] **Step 2: Replace index-based poll edit sheet presentation with id-based presentation**
- [ ] **Step 3: Remove add-on-dismiss behavior from poll option creation**
- [ ] **Step 4: Add delete action inside the poll edit sheet**

## Chunk 3: Verification

### Task 3: Run focused verification

**Files:**
- Verify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`
- Verify: `GameNight/GameNight/Views/Events/CreateEventView.swift`

- [ ] **Step 1: Run targeted tests**
- [ ] **Step 2: Run simulator build**
- [ ] **Step 3: Review diff for only intended changes**
