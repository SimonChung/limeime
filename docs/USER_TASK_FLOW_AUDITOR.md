# User Task Flow Auditor

This auditor reads each manual page as a real user trying to finish a task.

## Pass Standard

A page passes only if the user can identify:

- the entry point screen or tab
- the first action to take
- the expected success state
- the next step when the expected state does not appear
- which related page to open for deeper work

## Reject If

- The page opens with a product definition instead of a task.
- The page lists features without sequencing them into user actions.
- Instructions say to confirm something but do not name the screen, tab, visible state, or result.
- Quick start does not route device-migration users to backup/restore before rebuilding code tables.
- Troubleshooting lacks observable symptoms and concrete fixes.
- Platform-specific conditions are mixed together so the user cannot tell which steps apply.

## Required Flow Types

For LIME, the manual must clearly route at least these user situations:

- first installation
- restoring from an old device
- installing or importing an input method
- changing keyboard appearance or behavior
- backing up, restoring, or resetting the database
- Android voice input setup and fallback
- iPhone/iPad Full Access and vibration feedback
