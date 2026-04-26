import UIKit

// Horizontal scrolling candidate bar above the keyboard.
// Mirrors Android's CandidateView.java (horizontal ListView).

protocol CandidateBarViewDelegate: AnyObject {
    func candidateBarView(_ view: CandidateBarView, didSelect mapping: Mapping)
    func candidateBarViewDidRequestMore(_ view: CandidateBarView)
}

final class CandidateBarView: UIView {

    weak var delegate: CandidateBarViewDelegate?

    // MARK: - Subviews
    private let scrollView  = CandidateScrollView()
    private let stackView   = UIStackView()
    private let moreButton  = UIButton(type: .system)
    private let moreSep     = UIView()          // fixed separator left of chevron
    /// Leading region that displays the composing keyname. iPad uses this
    /// in lieu of the in-keyboard composingPopupLabel strip (which wastes
    /// vertical space). iPhone keeps the strip and leaves this collapsed.
    /// Width is 0 when `composingText` is nil/empty; intrinsic otherwise.
    private let composingLabel = UILabel()
    private var composingLabelWidth: NSLayoutConstraint!

    // MARK: - Theme
    var theme: Int = 0 {
        didSet { guard oldValue != theme else { return }; applyTheme() }
    }
    private var palette: KeyboardPalette {
        KeyboardPalette.palettes[max(0, min(theme, KeyboardPalette.palettes.count - 1))]
    }

    // MARK: - Feedback
    var feedbackVibration: Bool = false
    var vibrateLevel: Int = 40  // 10–20→.light, 40→.medium, 60–80→.heavy

    private var impactFeedback: UIImpactFeedbackGenerator {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch vibrateLevel {
        case ..<30:   style = .light
        case 30..<50: style = .medium
        default:      style = .heavy
        }
        return UIImpactFeedbackGenerator(style: style)
    }

    // MARK: - State
    private var candidates:  [Mapping] = []


    /// Currently-highlighted candidate index, or -1 when no cell should be drawn highlighted.
    /// Mirrors Android `CandidateView.mSelectedIndex` — associated lists (related phrases,
    /// Chinese punctuation, English suggestions) always leave this at -1.
    private var selectedIndex: Int = -1
    /// Read-only access to the current selection index for arrow-key navigation.
    var currentSelectedIndex: Int { selectedIndex }
    /// Number of candidates currently displayed.
    var candidateCount: Int { candidates.count }
    /// Button for each entry in `candidates`, in order. Used by `setSelectedIndex` to re-style
    /// individual cells without rebuilding the whole stack (preserves scroll offset).
    private var candidateButtons: [CandidateButton] = []

    /// Tags used to locate the two labels inside a selkey-prefixed button so
    /// `applyHighlightStyle` can update their colors on a selection change.


    // MARK: - Layout constants
    /// Mirrors Android `font_size` scaler from LIMEPreferenceManager.getFontSize().
    /// Applied to candidate/selkey/composing fonts. Set by KeyboardViewController.
    var fontScale: CGFloat = 1.1 {
        didSet { guard oldValue != fontScale else { return }; rebuildButtons() }
    }
    /// True when running on iPad hardware. Captured once from `UIDevice` so the
    /// candidate font scales up on real iPad. iPhone-only apps running on iPad
    /// in scaled mode also get the larger font — the iPad screen is large enough
    /// to read it comfortably and matching the bar height that was already sized
    /// from `isOnPad` in the controller.
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var baseCandidateFontSize: CGFloat     { isPad ? 26 : 22 }
    private var baseComposingCodeFontSize: CGFloat { isPad ? 22 : 16 }
    private var candidateFont: UIFont     { UIFont.systemFont(ofSize: baseCandidateFontSize * fontScale, weight: .regular) }
    private var composingCodeFont: UIFont { UIFont.monospacedSystemFont(ofSize: baseComposingCodeFontSize * fontScale, weight: .regular) }
    private let candidateHPad:   CGFloat = 10
    private let dividerWidth:    CGFloat = 1

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    /// Tracks current chevron direction (used by `setChevronExpanded`).
    private var chevronExpanded: Bool = false

    // MARK: - Setup
    private func applyTheme() {
        backgroundColor = .clear
        moreButton.tintColor = palette.candiText
        moreSep.backgroundColor = palette.candiText.withAlphaComponent(0.2)
        composingLabel.textColor = palette.candiText
        rebuildButtons()
    }

    private func setup() {
        // Bar itself stays .clear so it blends with the shared keyboard blur
        // backdrop. The touch-trap fill lives on the candidate buttons only
        // (see makeCandidateButton) — those fill the bar edge-to-edge when
        // candidates are shown, so every visible bar pixel is a button
        // pixel at 0.01-alpha grey. Empty bar = pure blur, matching the
        // surrounding keys exactly.
        backgroundColor = .clear

        // Fixed chevron pinned to the right edge of the bar
        let chevronSize: CGFloat = 18
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: chevronSize, weight: .regular)
        moreButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: chevronConfig), for: .normal)
        moreButton.tintColor = palette.candiText
        // KVC sets the same backing storage as `contentEdgeInsets` without
        // tripping the iOS 15 deprecation warning. The non-Configuration
        // button path is intentional — see makeCandidateButton for the
        // reason (UIButton.Configuration.plain() inflates spacing).
        moreButton.setValue(NSValue(uiEdgeInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)),
                            forKey: "contentEdgeInsets")
        moreButton.isHidden = true
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        // 0.01-alpha touch trap so taps in the chevron's padding also fire —
        // same rationale as the candidate buttons below.
        moreButton.backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(moreButton)

        moreSep.backgroundColor = palette.candiText.withAlphaComponent(0.2)
        moreSep.isHidden = true
        moreSep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(moreSep)

        composingLabel.font = composingCodeFont
        composingLabel.textColor = palette.candiText
        composingLabel.textAlignment = .center
        composingLabel.backgroundColor = .clear
        composingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(composingLabel)

        // Scroll view occupies the bar to the left of the fixed chevron.
        // delaysContentTouches=false routes taps to candidate buttons immediately;
        // canCancelContentTouches=true lets the scroll view cancel button tracking
        // when a drag gesture is detected, so horizontal scrolling still works.
        // CandidateScrollView.touchesShouldCancel returns true for UIControl
        // subclasses so drags are never blocked by the buttons.
        // No additional UITapGestureRecognizer is needed: buttons are full bar
        // height (alignment=.fill + explicit height constraint), so touchUpInside
        // fires for any tap within the bar regardless of vertical position.
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stackView.axis = .horizontal
        // .fill makes each candidate button stretch to the full bar height so
        // taps anywhere in the bar register, not just on the glyph itself.
        // The highlight pill is drawn on an inner view sized to the text
        // (see CandidateButton) so the visual pill stays glyph-sized.
        stackView.alignment = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            // chevron flush to trailing edge — square so its width matches the bar
            // height exactly. Keeps the reserved zone consistent with the expanded
            // panel's collapse chevron (candidateBarHeight × candidateBarHeight).
            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            moreButton.topAnchor.constraint(equalTo: topAnchor),
            moreButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            moreButton.widthAnchor.constraint(equalTo: moreButton.heightAnchor),

            // thin separator just left of the chevron
            moreSep.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor),
            moreSep.centerYAnchor.constraint(equalTo: centerYAnchor),
            moreSep.widthAnchor.constraint(equalToConstant: dividerWidth),
            moreSep.heightAnchor.constraint(equalToConstant: 20),

            // scroll view fills the rest
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: moreSep.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    // MARK: - Public API

    /// Rotate the fixed chevron to indicate expanded (↑) or collapsed (↓) state.
    func setChevronExpanded(_ expanded: Bool) {
        chevronExpanded = expanded
        let name = expanded ? "chevron.up" : "chevron.down"
        let chevronSize: CGFloat = 18
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: chevronSize, weight: .regular)
        moreButton.setImage(UIImage(systemName: name, withConfiguration: chevronConfig), for: .normal)
    }

    /// Retained for API compatibility. The composing code is now rendered
    /// as the first candidate entry in the bar, so there is no dedicated
    /// left-edge label to update.
    func setComposingCode(_ code: String) { _ = code }

    /// Replace the candidate list with new results.
    ///
    /// - Parameters:
    ///   - mappings: the new candidate list.
    ///   - selectedIndex: the initial highlighted index. Pass `-1` (default) for associated
    ///     lists (related phrases, Chinese punctuation, English suggestions) so no cell is
    ///     drawn highlighted — matches Android `CandidateView.setSuggestions` rule.
    func setCandidates(_ mappings: [Mapping], selectedIndex: Int = -1) {
        candidates = mappings
        self.selectedIndex = (selectedIndex >= 0 && selectedIndex < mappings.count) ? selectedIndex : -1
        rebuildButtons()
        // layoutIfNeeded must come BEFORE setContentOffset(.zero).
        // During the layout pass UIScrollView internally adjusts contentOffset to
        // account for contentSize changes; calling setContentOffset after ensures
        // our zero value always wins and is not overwritten by UIScrollView's
        // internal adjustment. scrollSelectedIntoView is intentionally omitted
        // here — a fresh candidate list always starts at offset 0.
        scrollView.layoutIfNeeded()
        scrollView.setContentOffset(.zero, animated: false)
    }

    /// Append additional candidates to the existing list WITHOUT clearing buttons or
    /// resetting scroll. Used by background follow-up fetches so the user’s scroll
    /// position is undisturbed.
    ///
    /// If `mappings` starts with the same items already displayed the method only
    /// adds the net-new tail. If `mappings` is not a superset of the current list
    /// (e.g. the composing code changed) it falls back to a full `setCandidates`.
    func appendCandidates(_ mappings: [Mapping], selectedIndex: Int = -1) {
        // Preserve scroll position across the stage-2 upgrade.
        // setCandidates now calls layoutIfNeeded() BEFORE setContentOffset(.zero),
        // so when it returns layout is fully settled and there are no pending async
        // scroll adjustments. Overriding the .zero immediately after is safe.
        let preservedX = scrollView.contentOffset.x
        setCandidates(mappings, selectedIndex: selectedIndex)
        guard preservedX > 0 else { return }
        let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        guard maxX > 0 else { return }
        scrollView.setContentOffset(CGPoint(x: min(preservedX, maxX), y: 0), animated: false)
    }

    /// Update the highlighted index without rebuilding buttons (preserves scroll offset).
    /// Pass `-1` to clear the highlight.
    func setSelectedIndex(_ index: Int) {
        let clamped = (index >= 0 && index < candidates.count) ? index : -1
        guard clamped != selectedIndex else { return }
        let old = selectedIndex
        selectedIndex = clamped
        if old >= 0 && old < candidateButtons.count {
            applyHighlightStyle(button: candidateButtons[old], index: old, mapping: candidates[old])
        }
        if clamped >= 0 && clamped < candidateButtons.count {
            applyHighlightStyle(button: candidateButtons[clamped], index: clamped, mapping: candidates[clamped])
        }
        scrollSelectedIntoView(animated: true)
    }

    /// Mirrors Android `candidate_switch` pref (CandidateView.java:314).
    /// true  = free drag-scroll (scrollView follows finger continuously)
    /// false = paged: drag is suppressed, on release snap to next/prev candidate page
    var candidateSwitch: Bool = true {
        didSet {
            guard oldValue != candidateSwitch else { return }
            scrollView.isScrollEnabled = candidateSwitch
            if candidateSwitch {
                if let gr = pagingPanGesture { scrollView.removeGestureRecognizer(gr) }
                pagingPanGesture = nil
                pagingStartOffsetX = 0
            } else {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePagingPan(_:)))
                scrollView.addGestureRecognizer(pan)
                pagingPanGesture = pan
            }
        }
    }
    private weak var pagingPanGesture: UIPanGestureRecognizer?
    private var pagingStartOffsetX: CGFloat = 0

    @objc private func handlePagingPan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            pagingStartOffsetX = scrollView.contentOffset.x
        case .ended, .cancelled:
            let dx = gr.translation(in: scrollView).x
            // Ignore tiny drags — tap/select will handle them.
            guard abs(dx) > 20 else { return }
            if dx < 0 { scrollNextPage() } else { scrollPrevPage() }
        default:
            break
        }
    }

    /// Scroll right by one visible-width page, aligned to the first candidate
    /// that would fall at/beyond the left edge of the new viewport.
    private func scrollNextPage() {
        let w = scrollView.bounds.width
        let maxX = max(0, scrollView.contentSize.width - w)
        let target = min(pagingStartOffsetX + w, maxX)
        scrollView.setContentOffset(CGPoint(x: alignedOffset(for: target, preferLeft: true), y: 0), animated: true)
    }

    /// Scroll left by one visible-width page, aligned to a candidate boundary.
    private func scrollPrevPage() {
        let w = scrollView.bounds.width
        let target = max(0, pagingStartOffsetX - w)
        scrollView.setContentOffset(CGPoint(x: alignedOffset(for: target, preferLeft: false), y: 0), animated: true)
    }

    /// Snap a scroll offset to the nearest candidate button x-position so pages
    /// align on candidate boundaries (mirrors Android scrollPrev/scrollNext which
    /// use mWordX[] to snap to word boundaries).
    private func alignedOffset(for target: CGFloat, preferLeft: Bool) -> CGFloat {
        guard !candidateButtons.isEmpty else { return target }
        var best: CGFloat = 0
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for btn in candidateButtons {
            let x = btn.frame.minX
            let d = abs(x - target)
            if d < bestDist { bestDist = d; best = x }
        }
        return best
    }

    // MARK: - Private

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        candidateButtons.removeAll(keepingCapacity: true)

        for (index, mapping) in candidates.enumerated() {
            let btn = makeCandidateButton(mapping: mapping, index: index)
            stackView.addArrangedSubview(btn)
            // Activate AFTER addArrangedSubview so btn and stackView share a
            // common ancestor — activating before would crash with
            // "no common ancestor" AutoLayout assertion.
            btn.heightAnchor.constraint(equalTo: stackView.heightAnchor).isActive = true
            candidateButtons.append(btn)
            applyHighlightStyle(button: btn, index: index, mapping: mapping)
        }

        // Show/hide the fixed chevron depending on whether there are candidates
        let hasCandidates = !candidates.isEmpty
        moreButton.isHidden = !hasCandidates
        moreSep.isHidden    = !hasCandidates
    }

    private func makeCandidateButton(mapping: Mapping, index: Int) -> CandidateButton {
        // .custom avoids UIKit's system-button tint overrides and ensures the
        // touch area is exactly the button frame (no hidden restrictions).
        let btn = CandidateButton(type: .custom)
        btn.tag = index
        // Use contentEdgeInsets (not UIButton.Configuration) so the button has
        // exactly `candidateHPad` on each side. UIButton.Configuration.plain()
        // adds its own internal padding on top of contentInsets, which made
        // the candi-bar spacing visibly larger than the expanded panel.
        // KVC bypasses the iOS 15 deprecation warning while writing the same
        // backing storage — the property is still functional, just deprecated
        // for source code that opts into Configuration (we explicitly do not).
        btn.setValue(NSValue(uiEdgeInsets: UIEdgeInsets(top: 0, left: candidateHPad, bottom: 0, right: candidateHPad)),
                     forKey: "contentEdgeInsets")
        btn.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
        // Same 0.01-alpha neutral fill as the bar — see setup() comment.
        // Without this, taps in the vertical padding above/below the glyph
        // land on clear pixels and are dropped by the keyboard-extension
        // touch gate before touchUpInside can fire.
        btn.backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        btn.translatesAutoresizingMaskIntoConstraints = false
        // Height constraint is added in rebuildButtons() after addArrangedSubview.

        // Composing-code record (mixed-mode raw-code entry): styled grey/monospace
        // so the user can visually distinguish it as "commit the raw English letters".
        // Mirrors Android mColorComposingCode.
        let isComposingCode = mapping.isComposingCodeRecord

        btn.setTitle(mapping.word, for: .normal)
        if isComposingCode {
            btn.titleLabel?.font = composingCodeFont
            btn.setTitleColor(palette.candiText.withAlphaComponent(0.5), for: .normal)
        } else {
            btn.titleLabel?.font = candidateFont
            btn.setTitleColor(palette.candiText, for: .normal)
        }
        return btn
    }

    /// Paint selection-dependent background and text color on a single candidate button.
    /// Mirrors Android `CandidateView.doDraw` highlight branch + per-record-type color switch.
    private func applyHighlightStyle(button: CandidateButton, index: Int, mapping: Mapping) {
        let isSelected = (index == selectedIndex && selectedIndex >= 0)
        let isComposingCode = mapping.isComposingCodeRecord
        // Theme 1 (Dark) overrides to an elevated gray pill for Android parity;
        // all other themes (including Light) use the palette's own highlight colour.
        let highlightColor: UIColor
        if theme == 1 {
            highlightColor = UIColor(white: 0.23, alpha: 1)
        } else {
            highlightColor = palette.candiHighlight
        }

        // The pill is drawn on an inner view sized to the text glyph only,
        // so the highlight remains visually compact even though the button
        // frame now spans the full bar height for a comfortable tap target.
        button.pillView.backgroundColor = isSelected ? highlightColor : .clear

        if isComposingCode {
            // Selected composing-code gets full opacity (mirrors mColorComposingCodeHighlight).
            let color = isSelected ? palette.candiText : palette.candiText.withAlphaComponent(0.5)
            button.setTitleColor(color, for: .normal)
        } else {
            button.setTitleColor(palette.candiText, for: .normal)
        }
    }

    /// Scroll so the highlighted cell is visible. No-op when selection is cleared.
    /// Mirrors Android's scrollNext/scrollPrev behavior on selection change.
    private func scrollSelectedIntoView(animated: Bool) {
        guard selectedIndex >= 0, selectedIndex < candidateButtons.count else { return }
        let btn = candidateButtons[selectedIndex]
        // Force a layout so btn.frame is valid immediately after rebuildButtons.
        stackView.layoutIfNeeded()
        let rect = btn.convert(btn.bounds, to: scrollView)
        if !scrollView.bounds.contains(rect) {
            scrollView.scrollRectToVisible(rect, animated: animated)
        }
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < candidates.count else { return }
        if feedbackVibration { impactFeedback.impactOccurred() }
        // Flash the highlight on the tapped cell before the commit animates.
        setSelectedIndex(index)
        delegate?.candidateBarView(self, didSelect: candidates[index])
    }

    @objc private func moreTapped() {
        if feedbackVibration { impactFeedback.impactOccurred() }
        delegate?.candidateBarViewDidRequestMore(self)
    }
}

/// UIButton subclass that draws its selection "pill" on an inner subview
/// sized to the text glyph, independent of the button's own frame. Combined
/// with `UIStackView.alignment = .fill`, this lets the tappable area extend
/// to the full bar height while keeping the highlight visually compact.
final class CandidateButton: UIButton {
    let pillView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPillView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPillView()
    }

    private func setupPillView() {
        pillView.isUserInteractionEnabled = false
        pillView.backgroundColor = .clear
        pillView.layer.cornerRadius = 6
        pillView.layer.masksToBounds = true
        insertSubview(pillView, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let label = titleLabel else {
            pillView.frame = .zero
            return
        }
        // Hug the title label with a small pad so the pill matches the
        // glyph bounds rather than the full button frame.
        let padX: CGFloat = 4
        let padY: CGFloat = 2
        pillView.frame = label.frame.insetBy(dx: -padX, dy: -padY)
    }
}

/// UIScrollView subclass whose `touchesShouldCancel(in:)` returns `true` for
/// every subview, including `UIControl` descendants. The default
/// implementation returns `false` for UIControl, which would otherwise
/// prevent the candidate list from scrolling once the candidate buttons
/// stretch to the full bar height (UIStackView `alignment = .fill`).
final class CandidateScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}
