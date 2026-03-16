# Event Edit Fix Design

**Problem**

Editing an existing event reused the create flow too literally:
- published edits still called the insert path, causing `events_pkey` duplicate-key failures
- the UI still behaved like a wizard instead of allowing direct save
- published invitees were not preloaded, so editing looked like a fresh invite list

**Approach**

Keep the existing form, but make published edit mode a real edit experience:
- preload current invites into the invite editor
- expose `Save Changes` from any step
- branch persistence so edit updates existing rows instead of inserting a new event
- diff invites during save so removed, updated, and new invitees are handled explicitly

**Persistence Rules**

- New events still insert `events`, related rows, and invites.
- Draft edits update the existing event and related rows.
- Published edits update the existing event, sync event games/time options, and diff invites.
- Invite tier changes update active vs waitlisted state instead of resetting the whole invite list.

**Verification**

- Added focused `CreateEventViewModelTests` for:
  - invite preloading
  - save-anytime edit mode
  - update-vs-create behavior
  - invite diffing
- Verified with targeted XCTest and a full simulator build.
