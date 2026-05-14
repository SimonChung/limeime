# iOS IMDetailView Dismiss Bug — Postmortem

## Symptom

After tapping **移除** in the IMDetailView confirmation alert, the IM was deleted
from the database, but the IMDetailView **remained on screen** instead of popping
back to IMListView. A related bug: the **還原已學習記錄** restore toggle never
appeared in IMInstallView for the deleted IM.

## Why I Failed (Multiple Times)

Five fix attempts went down the wrong rabbit hole because I never asked
"what device is this running on?" The `docs/IPAD_KEYBOARD.md` file open in the
IDE was the only signal — and I missed it.

Each attempt below assumed the bug was about **timing or API choice in
NavigationView push/pop**, not about **device layout**.

### Attempt 1 — Reorder dismiss before refresh
Hypothesis: `clearTable` invalidates the list, removes the row, removes the
NavigationLink, so dismiss has no link to deactivate. Fix: call `onDismiss()` and
`dismiss()` BEFORE awaiting `clearTable`.

Result: **failed.**

### Attempt 2 — Stop setting `isLoading = true` on refresh
Hypothesis: `loadIMs()` flipping `isLoading` swaps the entire `List` for a
`ProgressView`, removing all NavigationLinks mid-pop. Fix: keep `isLoading`
false on refreshes.

Result: **failed.**

### Attempt 3 — `DispatchQueue.main.async` defer
Hypothesis: alert action runs synchronously inside the alert dismissal frame,
coalescing state changes. Fix: defer dismiss to next runloop.

Result: **failed.**

### Attempt 4 — Switch from `NavigationLink(tag:selection:)` to plain `NavigationLink`
Hypothesis: legacy selection-binding NavigationLink is flaky in iOS 16+; plain
NavigationLink lets `dismiss()` work natively. Removed `selectedIMID` state.

Result: **failed.** (Plain NavigationLink was correct, just not sufficient.)

### Attempt 5 — Move dismiss out of alert action via `.onChange`
Hypothesis: `@Environment(\.dismiss)` captured inside an alert action targets the
wrong context. Fix: set `pendingRemove = true`, call dismiss from a
`.onChange(of: pendingRemove)` handler running in normal view context.

Result: **failed.**

### Attempt 6 — Use legacy `presentationMode.wrappedValue.dismiss()`
Hypothesis: `@Environment(\.dismiss)` only works with `NavigationStack`, not
`NavigationView`. Use legacy presentationMode binding instead.

Result: **failed.**

### Attempt 7 — Force `.navigationViewStyle(.stack)` on iPad
Hypothesis: iPad's column-style `NavigationView` is the reason
`presentationMode.dismiss()` is a no-op. Forcing stack style restores
iPhone-style push/pop semantics on iPad.

Result: **technically worked, but rejected by the user.** It collapses iPad
into a single-column phone layout, breaking the sidebar/split UX that every
other tab uses. Not an acceptable solution.

### Attempt 8 — Parent-owned selection with `NavigationView` + `NavigationLink(tag:selection:)`
Hypothesis: Lift navigation control to the parent so the detail view never
tries to dismiss itself. The parent sets `selection = nil` after delete to
dismiss the pane.

Result: **failed.** `NavigationView` + `NavigationLink(tag:selection:)` has
a long-standing SwiftUI defect: setting selection to `nil` does NOT clear
the iPad detail column. The detail view stayed on screen even though the
binding correctly went to nil.

## Root Cause

**The user was running on iPad.** `NavigationView` on iPad defaults to
**column / split-view style** (`UISplitViewController` under the hood):

- The list (master) column shows `IMListView`.
- Tapping a `NavigationLink` shows the destination in the **detail column** —
  it is NOT pushed onto a stack.
- `dismiss()` and `presentationMode.dismiss()` operate on the **navigation
  stack**, not on the detail column.
- A detail-column view cannot be "popped" by dismiss — it stays visible until
  another link replaces it OR the user navigates the master column.

So every iteration of the fix was correct as far as it went — the dismiss call
fired, the state was set correctly, the navigation context was clean — but
the detail pane simply does not respond to dismiss in column style.

The toggle bug was a separate genuine issue (variant tableNames + empty backup
table), already fixed independently. But it appeared linked because the user
could not reach IMInstallView freshly without first popping IMDetailView.

## Resolution

Two structural changes — both required:

### A. Lift navigation control to the parent (`IMListView`)

`IMDetailView` cannot dismiss itself: on iPad the detail pane lives in a
split-view detail column and `dismiss()` / `presentationMode.dismiss()` are
no-ops there. The parent must own the navigation state.

`IMDetailView` exposes an `onDeleted: (() -> Void)?` callback. After the user
confirms **移除**, `performRemove()`:

- Persists the `user_backed_up_*` UserDefaults flag.
- Calls `onDeleted?()` **first** (synchronously, before any `await`).
- Then awaits `clearTable` and triggers `onRefresh`.

The parent's `onDeleted` handler simply sets `selection = nil`.

### B. Use `NavigationSplitView` (iOS 16+), not `NavigationView`

The first attempt at the parent-owned selection used
`NavigationView` + `NavigationLink(tag:selection:)`. This **still didn't
dismiss** on iPad because that legacy combo has a long-standing SwiftUI
defect: setting selection back to `nil` does NOT clear the iPad detail
column. The detail view stays on screen even though the binding says "no
selection".

The actual working fix is to use `NavigationSplitView`, which is the API
Apple designed for parent-driven detail dismissal:

```swift
// IMListView
private enum DetailSelection: Hashable { case im(Int64), related, install }
@State private var selection: DetailSelection?

NavigationSplitView {
    List(selection: $selection) {
        ForEach($imList) { $row in
            HStack { … }.tag(DetailSelection.im(row.id))
        }
        Label("關聯字庫", systemImage: "text.bubble").tag(DetailSelection.related)
    }
    .overlay(alignment: .bottomTrailing) {
        Button { selection = .install } label: { … }   // floating ＋
    }
} detail: {
    NavigationStack {
        switch selection {
        case .im(let id) where row exists:
            IMDetailView(im: row, onRefresh: loadIMs, onDeleted: clearSelection)
        case .related:
            IMDetailView(im: relatedRow, onRefresh: nil, onDeleted: clearSelection)
        case .install:
            IMInstallView(onRefresh: loadIMs)
        case .none, _:
            Text("選擇一個輸入法")                       // iPad placeholder
        }
    }
}

private func clearSelection() { selection = nil }
```

```swift
// IMDetailView
let onDeleted: (() -> Void)?
private func performRemove() {
    onDeleted?()                    // parent flips selection → switch hits .none
    Task { _ = await manageImController.clearTable(...) ; onRefresh?() }
}
```

With `NavigationSplitView` the detail content is rendered by a `switch` over
`selection`, so flipping selection to `nil` deterministically swaps the
detail column to the placeholder on iPad and pops the stack on iPhone. No
`.navigationViewStyle(.stack)` override needed — iPad keeps the sidebar/split
UX that matches every other tab.

Applied in `LimeIME-iOS/LimeSettings/Views/IMListView.swift` and
`LimeIME-iOS/LimeSettings/Views/IMDetailView.swift`.

## Lessons

1. **A view cannot dismiss itself when it lives in a split-view detail
   column.** On iPad, `dismiss()` / `presentationMode.dismiss()` are no-ops
   for the detail pane. Lift navigation control to the parent that owns
   the selection, and let the child request dismissal via callback.
2. **`NavigationView` + `NavigationLink(tag:selection:)` does NOT clear the
   iPad detail column when selection becomes `nil`.** This is a real
   SwiftUI defect, not a coding mistake. Parent-owned selection only
   actually works under `NavigationSplitView` (iOS 16+).
3. **Don't paper over the platform with `.navigationViewStyle(.stack)`.**
   Forcing stack style on iPad breaks the sidebar/split UX that every other
   tab uses and that users expect on a tablet.
4. **Render the detail with a `switch` over selection, not via
   `NavigationLink` destinations.** Then dismissal is just "flip selection
   to nil" — the View tree updates deterministically without depending on
   any `NavigationLink` activation/deactivation behaviour.
5. **Device matters.** Always ask which device the user is testing on
   (iPhone vs iPad vs Mac Catalyst) when SwiftUI navigation behaves
   differently from expectation.
6. **Don't iterate on hypotheses without ruling out environment factors
   first.** Six attempts × incremental code changes is much more expensive
   than one question to the user about their test device.

## Final Code Surface

| File | Change |
|---|---|
| `LimeIME-iOS/LimeSettings/Views/IMListView.swift` | Migrated from `NavigationView` to `NavigationSplitView`. Sidebar uses `List(selection: $selection)` with `.tag(DetailSelection.…)` rows. Detail column is a `@ViewBuilder switch` over `selection` rendering `IMDetailView` / `IMInstallView` / placeholder. Provides a `clearSelection()` callback to children. The floating ＋ button now sets `selection = .install` directly. **No `.navigationViewStyle` override — iPad keeps sidebar/split style.** |
| `LimeIME-iOS/LimeSettings/Views/IMDetailView.swift` | Replaced `onDismiss` / `pendingRemove` / `@Environment(\.dismiss)` / `presentationMode` with a single `onDeleted: (() -> Void)?` callback owned by the parent. New `performRemove()` calls `onDeleted?()` synchronously before awaiting `clearTable`, so the parent dismisses the detail pane by clearing its selection. Persists `user_backed_up_<tableNick>` UserDefaults flag at delete time. |
| `LimeIME-iOS/LimeSettings/Views/IMInstallView.swift` | (unchanged from the original fix) `FamilyInstallGroup.task` checks backup across all variant tableNames AND honours the `user_backed_up_*` flag so the restore toggle shows even when the actual backup table is empty. |
