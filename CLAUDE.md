# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## General Rules
- When fixing bugs, make minimal targeted changes first. Do not refactor surrounding code or change approach without user approval. If a fix doesn't work on first attempt, pause and explain the root cause before trying a different approach.
- Build sustainably and responsibly to production coding standards from a FAANG company expectation

## Guidelines
- When working on Supabase backend, avoid SECURITY_DEFINER wherever possible
- When doing UI Elements reference the BrandGuidelines and support light and dark mode
- For interactive elements be sure to add toasts where necessary
- When doing any RLS policies reference (`.agents/skills/supabase-audit-rls/`) to validate 
- Verify iOS changes with xcodegen and xcodebuild and xcodetest -- ensure all passing tests and no build issues
- Prefer RPC over direct database access

## Project Overview

Game Night is a full-stack iOS app for scheduling game nights with friends. It consists of three components:
- **iOS app** (SwiftUI, `GameNight/`) — the main client
- **Supabase backend** (`Supabase/`) — PostgreSQL database, auth, edge functions
- **Web RSVP page** (`InviteWeb/`) — standalone HTML page for non-app users to RSVP

## Build & Run

### Build Process
- After any file creation or deletion in the Xcode project, always run `xcodegen` to regenerate the project file before attempting a build.

### iOS App
The Xcode project is at `GameNight/GameNight.xcodeproj`. It uses XcodeGen (`project.yml`) for project generation.

```bash
# Regenerate Xcode project after changing project.yml
cd GameNight && xcodegen generate

# Build from command line
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- **Deployment target:** iOS 17.0
- **Swift version:** 5.9
- **Only dependency:** supabase-swift (SPM, v2.0.0+)
- **Portrait only**, deep link scheme: `gamenight://`

### Secrets Setup
Copy `GameNight/GameNight/App/Secrets.swift.example` to `Secrets.swift` and fill in Supabase URL and publishable key. This file is gitignored.

Root `.env` file (from `.env.example`) holds Supabase, Twilio, and R2 credentials for edge functions.

### Supabase & Database
- When modifying Supabase RLS policies, always check for recursive policy references (e.g., table A's policy queries table B which queries table A). Test by running a simple SELECT as an authenticated user after applying migrations.

```bash
# Start local Supabase
supabase start

# Apply migrations
supabase db push

# Deploy edge functions
supabase functions deploy send-invite
supabase functions deploy send-sms
supabase functions deploy process-tiered-invites
supabase functions deploy r2-upload-url
supabase functions deploy r2-delete
```

## Architecture

### iOS App (MVVM)
- **Models** (`Models/`) — Codable structs mapping to Supabase tables: `User`, `GameEvent`, `Game`, `Invite`, `Group`
- **ViewModels** (`ViewModels/`) — `@StateObject` with `@Published` properties, async data loading
- **Views** (`Views/`) — SwiftUI views organized by feature: Onboarding, Home, GameLibrary, Events, Groups, Profile, Components
- **Services** (`Services/`) — Singleton services:
  - `SupabaseService` — all backend API calls (auth, CRUD, realtime subscriptions, blocking)
  - `BGGService` — BoardGameGeek XML API integration
  - `ContactPickerService`, `SMSService`, `R2StorageService`
- **Theme** (`Theme/`) — dark-first design system (electric violet/magenta palette inspired by Partiful/DICE)
- **App** (`App/`) — entry point (`GameNightApp`), `AppState` (global auth/navigation state), `ContentView` (5-tab navigation)

### Key Patterns
- `AppState` is injected as `@EnvironmentObject` throughout the view hierarchy
- All network calls use Swift async/await
- Auth flow: phone OTP via Supabase Auth + Twilio SMS
- Tiered invite system: invites sent in waves, auto-promoted on decline
- Supabase RealtimeChannelV2 for live event updates

### SwiftUI Patterns
- Avoid complex type expressions in single views; extract subviews to reduce type-checker load.
- When working with ScrollView + tap gestures, use `.contentShape(Rectangle())` and avoid nested Button/onTapGesture conflicts.

### Swift Code Conventions
- When adding new enum cases (e.g., MessageType, notification types), always update ALL switch statements and Codable conformances across the codebase. Use Grep to find all references before declaring the change complete.

### Database Schema (Supabase)
Core tables: `users`, `games`, `game_library`, `game_categories`, `groups`, `group_members`, `events`, `event_games`, `time_options`, `invites`, `consent_log`, `blocked_users`

Migrations are in `Supabase/migrations/`. Edge functions (TypeScript) are in `Supabase/functions/`.
