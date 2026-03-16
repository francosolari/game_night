# Create Event Location And Poll Edit Design

## Goal

Fix the create-event details screen so an existing location opens an edit flow instead of restarting search, and poll date cards support explicit edit and delete behavior.

## Decisions

- Reuse `CustomLocationEditSheet` for existing-location edits in `CreateEventView`.
- Keep `LocationPickerSheet` as the search flow and reopen it only from the edit sheet's "Search new address" action.
- Use a dedicated `PollEditSheet` to edit a poll option's date, times, label, and deletion.
- Keep the existing trash icon on poll cards for direct removal.
- Remove implicit add-on-dismiss behavior from the poll add flow so new options are only created from an explicit save action.

## Affected Areas

- `GameNight/GameNight/Views/Events/CreateEventView.swift`
- `GameNight/GameNight/Views/Components/LocationPickerSheet.swift`
- `GameNight/GameNight/ViewModels/EventViewModel.swift`
- `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`

## Validation

- Unit tests cover editing and deleting poll options through stable identifiers.
- Simulator build succeeds after the UI wiring changes.
