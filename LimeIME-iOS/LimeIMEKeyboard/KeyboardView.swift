import UIKit

// Full keyboard view: renders keys from a LimeKeyLayout.
// Phase 2: UIButton-based; Phase 3 can switch to UICollectionView for more flexibility.

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didPress keyDef: KeyDef)
    func keyboardView(_ view: KeyboardView, didLongPress keyDef: KeyDef)
    /// Called on touchDown for non-modifier keys — host should show a key-preview popup.
    /// `keyRect` is the key's frame in the KeyboardView's coordinate space.
    func keyboardView(_ view: KeyboardView, showPreviewFor keyDef: KeyDef, keyRect: CGRect)
    /// Called on touchUp/cancel — host should dismiss the key preview.
    func keyboardViewDismissPreview(_ view: KeyboardView)
}

final class KeyboardView: UIView {

    weak var delegate: KeyboardViewDelegate?

    private var layout: LimeKeyLayout
    private var isShiftOn: Bool = false
    private var rowViews: [UIView] = []
    private var repeatTimer: Timer?
    private var repeatKeyDef: KeyDef?
    private weak var globeButton: UIButton?

    // MARK: - Feedback settings (spec §15)
    var feedbackVibration: Bool = false
    var feedbackSound:     Bool = false
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // Layout constants (portrait).
    // Android key_height = 46dip portrait, 36dip landscape.
    // iOS row heights are scaled slightly larger to match modern iPhone proportions.
    private let rowHeightPortrait:       CGFloat = 52
    private let bottomRowHeightPortrait: CGFloat = 54
    private let rowHeightLandscape:      CGFloat = 36   // matches Android 36dip landscape
    private let bottomRowHeightLandscape:CGFloat = 38
    private let keyCornerRadius: CGFloat = 6
    private let keyShadowOpacity: Float  = 0.3
    // Gap between adjacent keys (horizontal) and between key and row edge (vertical).
    // Used in both makeRow layout and styleKeyContent aspect-ratio check.
    private let keyHGap: CGFloat = 5   // horizontal gap between keys
    private let keyVGap: CGFloat = 2   // vertical inset top/bottom

    /// Set by KeyboardViewController in viewWillLayoutSubviews; triggers a full rebuild.
    var isLandscape: Bool = false {
        didSet {
            guard isLandscape != oldValue else { return }
            rowViews.forEach { $0.removeFromSuperview() }
            rowViews.removeAll()
            globeButton = nil
            buildKeys()
        }
    }

    private var rowHeight:       CGFloat { isLandscape ? rowHeightLandscape       : rowHeightPortrait }
    private var bottomRowHeight: CGFloat { isLandscape ? bottomRowHeightLandscape  : bottomRowHeightPortrait }

    // Key appearance — dynamic colors so the keyboard tracks light/dark mode.
    private let normalKeyColor   = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.30, alpha: 1)
                                      : UIColor.white
    }
    private let modifierKeyColor = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1)
                                      : UIColor.systemGray3
    }
    private let pressedKeyColor  = UIColor.systemGray5
    private let keyLabelFont     = UIFont.systemFont(ofSize: 22, weight: .regular)
    private let keySublabelFont  = UIFont.systemFont(ofSize: 16, weight: .light)
    private let keyLabelFontLand     = UIFont.systemFont(ofSize: 22, weight: .regular)
    private let keySublabelFontLand  = UIFont.systemFont(ofSize: 16, weight: .light)

    // MARK: - Init
    init(layout: LimeKeyLayout) {
        self.layout = layout
        super.init(frame: .zero)
        backgroundColor = UIColor.systemGray4
        buildKeys()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Layout switch
    func setLayout(_ newLayout: LimeKeyLayout) {
        layout = newLayout
        rowViews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()
        globeButton = nil
        shiftKeyButton = nil
        buildKeys()
        // Restore shift icon after layout rebuild
        updateShiftKeyIcon()
    }

    /// Sum of all row heights for the current layout.
    /// Use this in KeyboardViewController.applyHeight() instead of a flat constant.
    var preferredHeight: CGFloat {
        layout.rows.reduce(0) { $0 + ($1.isBottomRow ? bottomRowHeight : rowHeight) }
    }

    // MARK: - Shift state

    /// Three-state shift: off / one-shot / caps-lock (mirrors Android mCapsLock + isShifted).
    enum ShiftState { case off, on, capsLock }

    private(set) var shiftState: ShiftState = .off
    /// Weak ref to the shift key button — stored during buildKeys for icon updates.
    private weak var shiftKeyButton: UIButton?

    /// Update shift state and refresh the shift key icon.
    /// Call from KeyboardViewController.setShift(_:capsLock:).
    func setShiftState(_ state: ShiftState) {
        guard state != shiftState else { return }
        shiftState = state
        isShiftOn  = state != .off
        updateShiftKeyIcon()
    }

    private func updateShiftKeyIcon() {
        guard let btn = shiftKeyButton else { return }
        let iconName: String
        switch shiftState {
        case .off:      iconName = "shift"
        case .on:       iconName = "shift.fill"
        case .capsLock: iconName = "capslock.fill"
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        btn.setImage(UIImage(systemName: iconName, withConfiguration: cfg), for: .normal)
        // Tint the shift key to show active state
        btn.tintColor = shiftState == .off ? .label : .systemBlue
    }

    func setShift(_ on: Bool) {
        isShiftOn = on
    }

    /// Show or hide the globe key based on needsInputModeSwitchKey (spec §10).
    func setGlobeKeyVisible(_ visible: Bool) {
        globeButton?.isHidden = !visible
    }

    // MARK: - Build
    private func buildKeys() {
        var prevRow: UIView? = nil

        for (rowIndex, row) in layout.rows.enumerated() {
            let rh = row.isBottomRow ? bottomRowHeight : rowHeight
            let rowView = makeRow(row: row, rowIndex: rowIndex, rowHeight: rh)
            addSubview(rowView)
            rowViews.append(rowView)

            rowView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
                rowView.heightAnchor.constraint(equalToConstant: rh),
            ])

            if let prev = prevRow {
                rowView.topAnchor.constraint(equalTo: prev.bottomAnchor).isActive = true
            } else {
                rowView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            }
            prevRow = rowView
        }

        if let last = prevRow {
            last.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }

    private func makeRow(row: KeyRow, rowIndex: Int, rowHeight: CGFloat) -> UIView {
        let rowView = UIView()
        rowView.backgroundColor = .clear

        // Total width percent in this row (should sum to 100 for regular rows)
        let totalPercent = row.keys.reduce(0) { $0 + $1.widthPercent }
        var prevButton: UIButton? = nil

        for (_, keyDef) in row.keys.enumerated() {
            let btn = makeKeyButton(keyDef: keyDef, rowHeight: rowHeight, totalPercent: totalPercent)
            rowView.addSubview(btn)

            btn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: rowView.topAnchor, constant: keyVGap),
                btn.bottomAnchor.constraint(equalTo: rowView.bottomAnchor, constant: -keyVGap),
                // Each key spans its proportional share of the row width minus keyHGap,
                // so adjacent keys are separated by keyHGap pt of background.
                btn.widthAnchor.constraint(equalTo: rowView.widthAnchor,
                                           multiplier: keyDef.widthPercent / totalPercent,
                                           constant: -keyHGap),
            ])

            if let prev = prevButton {
                btn.leadingAnchor.constraint(equalTo: prev.trailingAnchor, constant: keyHGap).isActive = true
            } else {
                btn.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: keyHGap / 2).isActive = true
            }
            prevButton = btn
        }

        return rowView
    }

    private func makeKeyButton(keyDef: KeyDef, rowHeight: CGFloat, totalPercent: CGFloat) -> UIButton {
        // Space key: custom touch tracking avoids UISwipeGestureRecognizer conflicts and
        // prevents keyDown from firing didPress(space) before swipe/long-press is resolved.
        if keyDef.code == LimeKeyCode.space.rawValue {
            return makeSpaceButton(keyDef: keyDef, rowHeight: rowHeight, totalPercent: totalPercent)
        }

        let btn = KeyButton(keyDef: keyDef)

        // Keyboard dismiss key (code -3):
        //   - single tap (touchUpInside): dismiss keyboard
        //   - long press: show options menu (globe preview, spec §10)
        // MUST use touchUpInside so the long-press GR can fire before the keyboard is dismissed.
        if keyDef.code == LimeKeyCode.done.rawValue {
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(specialLongPressed(_:)))
            lp.minimumPressDuration = 0.5
            btn.addGestureRecognizer(lp)
        }

        // Shift key: store reference for icon updates.
        if keyDef.code == LimeKeyCode.shift.rawValue {
            shiftKeyButton = btn
        }

        // Legacy globe key (code -200): long-press also shows options menu.
        if keyDef.code == LimeKeyCode.globe.rawValue {
            globeButton = btn
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(specialLongPressed(_:)))
            lp.minimumPressDuration = 0.5
            btn.addGestureRecognizer(lp)
        }

        applyButtonStyle(btn, keyDef: keyDef, rowHeight: rowHeight, totalPercent: totalPercent)

        btn.addTarget(self, action: #selector(keyDown(_:event:)), for: .touchDown)
        btn.addTarget(self, action: #selector(keyUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        // Done and globe keys fire didPress on touchUpInside (deferred so long-press can intercept)
        if keyDef.code == LimeKeyCode.done.rawValue || keyDef.code == LimeKeyCode.globe.rawValue {
            btn.addTarget(self, action: #selector(keyboardKeyTapped(_:)), for: .touchUpInside)
        }

        return btn
    }

    /// Build the space key as a SpaceKeyButton so tap/swipe/long-press are mutually exclusive.
    private func makeSpaceButton(keyDef: KeyDef, rowHeight: CGFloat, totalPercent: CGFloat) -> UIButton {
        let btn = SpaceKeyButton(keyDef: keyDef)
        applyButtonStyle(btn, keyDef: keyDef, rowHeight: rowHeight, totalPercent: totalPercent)

        btn.onTap = { [weak self] in
            guard let self else { return }
            if self.feedbackVibration { self.impactFeedback.impactOccurred() }
            if self.feedbackSound     { UIDevice.current.playInputClick() }
            self.delegate?.keyboardView(self, didPress: keyDef)
        }
        btn.onLongPress = { [weak self] in
            guard let self else { return }
            self.delegate?.keyboardView(self, didLongPress: keyDef)
        }
        btn.onSwipeLeft = { [weak self] in
            guard let self else { return }
            let kd = KeyDef(code: LimeKeyCode.prevIM.rawValue, isModifier: true)
            self.delegate?.keyboardView(self, didPress: kd)
        }
        btn.onSwipeRight = { [weak self] in
            guard let self else { return }
            let kd = KeyDef(code: LimeKeyCode.nextIM.rawValue, isModifier: true)
            self.delegate?.keyboardView(self, didPress: kd)
        }
        return btn
    }

    /// Apply background color, corner radius and shadow to any key button.
    private func applyButtonStyle(_ btn: UIButton, keyDef: KeyDef,
                                  rowHeight: CGFloat, totalPercent: CGFloat) {
        btn.backgroundColor = keyDef.isModifier ? modifierKeyColor : normalKeyColor
        btn.layer.cornerRadius = keyCornerRadius
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = keyShadowOpacity
        btn.layer.shadowRadius = 0
        styleKeyContent(btn: btn, keyDef: keyDef, rowHeight: rowHeight, totalPercent: totalPercent)
    }

    /// Renders key content.
    /// Layout rule (mirrors Android keyLabel \n rendering):
    ///   • Tall key  (height ≥ width): label small top,  sublabel large bottom — vertical stack
    ///   • Wide key  (width  > height): label small left, sublabel large right  — horizontal stack
    private func styleKeyContent(btn: UIButton, keyDef: KeyDef,
                                 rowHeight: CGFloat, totalPercent: CGFloat) {
        if !keyDef.icon.isEmpty {
            // SF Symbol icon key
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let img = UIImage(systemName: keyDef.icon, withConfiguration: config)
            btn.setImage(img, for: .normal)
            btn.tintColor = .label
        } else if !keyDef.sublabel.isEmpty {
            // Actual button dimensions matching makeRow constraints:
            //   width  = screenWidth × (widthPct/totalPct) − keyHGap
            //   height = rowHeight − 2×keyVGap
            let screenWidth    = UIScreen.main.bounds.width
            let estimatedWidth = screenWidth * (keyDef.widthPercent / totalPercent) - keyHGap
            let usableHeight   = rowHeight - 2 * keyVGap
            // Tall: height ≥ width  →  vertical stack (primary top, sublabel bottom)
            // Wide: width > height  →  horizontal stack (primary left, sublabel right)
            let isTall = usableHeight >= estimatedWidth

            let container = makeDualLabelView(primary: keyDef.label, sub: keyDef.sublabel,
                                              isTall: isTall)
            container.isUserInteractionEnabled = false
            container.translatesAutoresizingMaskIntoConstraints = false
            btn.addSubview(container)
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                container.widthAnchor.constraint(lessThanOrEqualTo: btn.widthAnchor, constant: -4),
            ])
        } else {
            // Single label key
            btn.setTitle(keyDef.label, for: .normal)
            btn.titleLabel?.font = keyLabelFont
            btn.setTitleColor(.label, for: .normal)
        }
    }

    /// Builds a two-part label view for keys that have both a primary label and a sublabel.
    /// - `isTall`: true → vertical (primary small top, sublabel large bottom)
    ///             false → horizontal (primary small left, sublabel large right)
    private func makeDualLabelView(primary: String, sub: String, isTall: Bool) -> UIView {
        let stack = UIStackView()
        stack.alignment = .center

        let primaryLbl = UILabel()
        primaryLbl.text = sub
        primaryLbl.textColor = .label
        primaryLbl.setContentHuggingPriority(.required, for: .horizontal)
        primaryLbl.setContentHuggingPriority(.required, for: .vertical)

        let subLbl = UILabel()
        subLbl.text = primary
        subLbl.textColor = .secondaryLabel
        subLbl.setContentHuggingPriority(.required, for: .horizontal)
        subLbl.setContentHuggingPriority(.required, for: .vertical)

        if isTall {
            // Vertical: primary (keyboard key char) small at top, sublabel (BPMF char) large below
            stack.axis = .vertical
            stack.spacing = 0
            primaryLbl.font = keyLabelFont
            subLbl.font     = keySublabelFont
            
            stack.addArrangedSubview(subLbl)
            stack.addArrangedSubview(primaryLbl)
        } else {
            // Horizontal: primary (keyboard key char) small on left, sublabel (BPMF char) on right
            stack.axis = .horizontal
            stack.spacing = 3
            primaryLbl.font = keyLabelFontLand
            subLbl.font     = keySublabelFontLand
            
            stack.addArrangedSubview(subLbl)
            stack.addArrangedSubview(primaryLbl)
        }
        return stack
    }

    // MARK: - Touch handling
    @objc private func keyDown(_ btn: UIButton, event: UIEvent) {
        guard let keyBtn = btn as? KeyButton else { return }
        keyBtn.wasLongPressed = false   // reset each new touch cycle
        btn.backgroundColor = pressedKeyColor

        let keyDef = keyBtn.keyDef

        // Haptic / audio feedback (spec §15)
        if feedbackVibration { impactFeedback.impactOccurred() }
        if feedbackSound     { UIDevice.current.playInputClick() }

        // Show key preview — delegate positions it in UIInputViewController.view (above keyboard)
        if keyDef.icon.isEmpty && !keyDef.isModifier
            && keyDef.code != LimeKeyCode.space.rawValue {
            let keyRect = btn.convert(btn.bounds, to: self)
            delegate?.keyboardView(self, showPreviewFor: keyDef, keyRect: keyRect)
        }

        // Keyboard dismiss key (code -3) and globe key (code -200): defer didPress to
        // touchUpInside so the long-press GR can fire before the action runs (spec §10).
        // Globe key must not fire advanceToNextInputMode() immediately on touchDown or the
        // keyboard switches before the long-press menu can appear.
        let deferToTouchUp = keyDef.code == LimeKeyCode.done.rawValue
                          || keyDef.code == LimeKeyCode.globe.rawValue
        if !deferToTouchUp {
            delegate?.keyboardView(self, didPress: keyDef)
        }

        // Start repeat timer for repeatable keys
        if keyDef.isRepeatable {
            repeatKeyDef = keyDef
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                self?.startRepeating()
            }
        }
    }

    /// Fires `didPress` for the keyboard dismiss key on touchUpInside (see keyDown comment).
    /// Suppressed if the key was long-pressed (wasLongPressed flag) to prevent dismissing
    /// the keyboard immediately after the long-press options menu appears.
    @objc private func keyboardKeyTapped(_ btn: UIButton) {
        guard let keyBtn = btn as? KeyButton, !keyBtn.wasLongPressed else { return }
        delegate?.keyboardView(self, didPress: keyBtn.keyDef)
    }

    @objc private func keyUp(_ btn: UIButton) {
        guard let keyBtn = btn as? KeyButton else { return }
        let isModifier = keyBtn.keyDef.isModifier
        btn.backgroundColor = isModifier ? modifierKeyColor : normalKeyColor
        delegate?.keyboardViewDismissPreview(self)
        stopRepeating()
    }

    private func startRepeating() {
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let keyDef = self.repeatKeyDef else { return }
            self.delegate?.keyboardView(self, didPress: keyDef)
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatKeyDef = nil
    }

    /// Long-press handler for keyboard dismiss key and legacy globe key.
    @objc private func specialLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began, let keyBtn = gr.view as? KeyButton else { return }
        // Mark so touchUpInside (keyboardKeyTapped) does NOT fire dismiss/action after long press.
        keyBtn.wasLongPressed = true
        delegate?.keyboardView(self, didLongPress: keyBtn.keyDef)
    }
}

// MARK: - SpaceKeyButton
// Handles tap / swipe-left / swipe-right / long-press internally using raw touch tracking.
// This avoids the UISwipeGestureRecognizer + UIButton.touchDown conflict where a space
// character fires on touchDown before UIKit has a chance to recognise the swipe direction.
private final class SpaceKeyButton: KeyButton {
    var onTap:        (() -> Void)?
    var onLongPress:  (() -> Void)?
    var onSwipeLeft:  (() -> Void)?
    var onSwipeRight: (() -> Void)?

    private var touchBeganPoint: CGPoint = .zero
    private var longPressTimer:  Timer?
    private var actionFired = false  // swipe or long-press already handled for this touch

    private static let swipeThreshold:    CGFloat       = 30
    private static let longPressDuration: TimeInterval  = 0.5

    // Override all four touch methods WITHOUT calling super so that UIKit never sends
    // the .touchDown / .touchUpInside control events → keyDown/keyUp never fire for space.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchBeganPoint = touch.location(in: self)
        actionFired = false
        backgroundColor = UIColor.systemGray5
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: SpaceKeyButton.longPressDuration, repeats: false
        ) { [weak self] _ in
            guard let self, !self.actionFired else { return }
            self.actionFired = true
            self.resetBg()
            self.onLongPress?()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !actionFired else { return }
        let dx = touch.location(in: self).x - touchBeganPoint.x
        if abs(dx) >= SpaceKeyButton.swipeThreshold {
            actionFired = true
            longPressTimer?.invalidate(); longPressTimer = nil
            resetBg()
            dx > 0 ? onSwipeRight?() : onSwipeLeft?()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate(); longPressTimer = nil
        resetBg()
        if !actionFired { onTap?() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate(); longPressTimer = nil
        resetBg()
    }

    private func resetBg() {
        backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.30, alpha: 1)
                                          : UIColor.white
        }
    }
}

// MARK: - KeyButton: stores its KeyDef
private class KeyButton: UIButton {
    let keyDef: KeyDef
    /// Set to true when a UILongPressGestureRecognizer fires on this button.
    /// Used to suppress the subsequent touchUpInside (e.g. done key dismissing keyboard after long press).
    var wasLongPressed = false
    init(keyDef: KeyDef) {
        self.keyDef = keyDef
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
}
