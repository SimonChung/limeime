# Issue #64: IM management screens lack visible scrollbar affordance

## Problem statement

Issue #64 reports that, in LIME 6.1.1, some text or function settings in the individual input-method management screens appear to be pushed out of the visible area when the phone uses larger display/font settings.

A follow-up comment from `jrywu` confirmed that the affected screens are scrollable, but no scrollbar is shown. This changes the issue from a content reachability problem to a scroll affordance and accessibility problem: users can reach the hidden content only if they discover that the page can scroll.

## Current observations

Relevant UI files:

- `LimeStudio/app/src/main/res/layout/fragment_im_detail.xml`
- `LimeStudio/app/src/main/res/layout/fragment_im_list.xml`
- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/ImDetailFragment.java`
- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/TwoPaneHostFragment.java`

`fragment_im_detail.xml` uses a `NestedScrollView` for the detail screen content. The scroll container is laid out correctly with `layout_height="0dp"` and `layout_weight="1"`, so overflowing content can scroll below the toolbar. However, the scroll view has no explicit id and no explicit scrollbar settings such as `android:scrollbars="vertical"`, `android:fadeScrollbars="false"`, or `android:scrollbarStyle`.

`ImDetailFragment.java` inflates the layout but does not configure the `NestedScrollView` programmatically. Because the scroll view has no id, the fragment currently cannot enable or tune scrollbar behavior from code without a layout change.

`fragment_im_list.xml` contains the input-method list in a `RecyclerView`. If the screenshots include the list screen as well as the detail screen, that list also lacks explicit vertical scrollbar configuration.

## Likely root cause

The screens are technically scrollable, but their scroll indicators rely on Android default scrollbar behavior. On modern Android themes/devices, default scrollbars may fade quickly, be visually subtle, or not appear in a way users notice. With large font or display scaling, the content overflow becomes more common, making the absence of a visible scroll affordance look like a layout clipping bug.

## Proposed solution

1. Give the detail `NestedScrollView` a stable id, for example `@+id/im_detail_scroll`.
2. Enable a visible vertical scrollbar for the detail scroll container in XML:
   - `android:scrollbars="vertical"`
   - `android:fadeScrollbars="false"` if the desired behavior is an always-visible indicator
   - choose an appropriate `android:scrollbarStyle`, such as `insideInset` or `outsideOverlay`, after checking the visual result
3. If the list screen is part of the affected flow, enable vertical scrollbar visibility on the `RecyclerView` as well.
4. Keep `fillViewport="true"` on the detail scroll view so short pages still fill the available pane while long pages scroll normally.
5. Avoid reducing text size as the primary fix, because the reported scenario is tied to larger user font/display settings and should remain accessible.

## Follow-up questions

- Which exact two screens are shown in the screenshots: input-method list, input-method detail, or another settings fragment?
- Does the reporter use Android system font size/display size larger than default?
- Should the scrollbar stay always visible, or is a stronger initial scroll hint enough?

## Verification plan

- Test on a device/emulator with default font/display settings and with large/maximum font and display settings.
- Open the individual input-method management screens shown in the screenshots.
- Confirm all content remains reachable by scrolling.
- Confirm a vertical scrollbar or equivalent scroll affordance is visible enough when content overflows.
- Confirm the change does not introduce unwanted permanent scrollbar space or overlap in two-pane/tablet layouts.
