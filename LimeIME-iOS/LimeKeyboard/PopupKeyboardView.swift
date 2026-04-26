import UIKit

// Floating mini-keyboard that appears above a key when the user long-presses.
// Mirrors Android's MiniKeyboardPopup / PopupKeyboardView behaviour.

protocol PopupKeyboardViewDelegate: AnyObject {
    func popupKeyboardView(_ popup: PopupKeyboardView, didSelect keyDef: KeyDef)
}

final class PopupKeyboardView: UIView {

    weak var delegate: PopupKeyboardViewDelegate?

    private let layout:   LimeKeyLayout
    private let palette:  KeyboardPalette

    // Layout constants
    private let keyH:     CGFloat = 44
    private let keyMinW:  CGFloat = 40
    private let hPad:     CGFloat = 8
    private let vPad:     CGFloat = 8
    private let spacing:  CGFloat = 4

    // MARK: - Init

    init(layout: LimeKeyLayout, theme: Int = 0) {
        self.layout  = layout
        self.palette = KeyboardPalette.palettes[max(0, min(theme, KeyboardPalette.palettes.count - 1))]
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildUI() {
        backgroundColor = palette.background
        layer.cornerRadius  = 12
        layer.masksToBounds = false
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset  = CGSize(width: 0, height: 3)
        layer.shadowRadius  = 8

        var yOff: CGFloat = vPad
        for (ri, row) in layout.rows.enumerated() {
            var xOff: CGFloat = hPad
            for (ki, kd) in row.keys.enumerated() {
                let kw  = keyWidth(for: kd)
                let btn = makeKeyButton(kd, row: ri, col: ki)
                btn.frame = CGRect(x: xOff, y: yOff, width: kw, height: keyH)
                addSubview(btn)
                xOff += kw + spacing
            }
            let isLast = ri == layout.rows.count - 1
            yOff += keyH + (isLast ? 0 : spacing)
        }

        // Size the view to fit its content
        let totalW = layout.rows.map { contentWidth(of: $0) }.max() ?? 0
        let nRows  = CGFloat(layout.rows.count)
        let totalH = vPad + nRows * keyH + max(0, nRows - 1) * spacing + vPad
        frame.size = CGSize(width: totalW, height: totalH)
    }

    private func keyWidth(for kd: KeyDef) -> CGFloat {
        let text = cleanLabel(kd.label.isEmpty ? kd.sublabel : kd.label)
        let w    = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 22)]).width
        return max(keyMinW, ceil(w) + 20)
    }

    private func contentWidth(of row: KeyRow) -> CGFloat {
        let keysW = row.keys.reduce(0.0) { $0 + keyWidth(for: $1) }
        let gapW  = CGFloat(max(0, row.keys.count - 1)) * spacing
        return hPad + keysW + gapW + hPad
    }

    private func makeKeyButton(_ kd: KeyDef, row: Int, col: Int) -> UIButton {
        let btn = UIButton(type: .system)
        let text = cleanLabel(kd.label.isEmpty ? kd.sublabel : kd.label)
        btn.setTitle(text, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        btn.setTitleColor(palette.label, for: .normal)
        btn.backgroundColor = palette.normalKey
        btn.layer.cornerRadius  = 6
        btn.layer.masksToBounds = false
        btn.layer.shadowColor   = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.22
        btn.layer.shadowOffset  = CGSize(width: 0, height: 1)
        btn.layer.shadowRadius  = 1

        // Tag encodes row/col so we can recover the KeyDef on tap
        btn.tag = row * 1000 + col
        btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)

        // Highlight on press
        btn.addTarget(self, action: #selector(keyHighlight(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(keyUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return btn
    }

    // MARK: - Actions

    @objc private func keyTapped(_ sender: UIButton) {
        let ri = sender.tag / 1000
        let ki = sender.tag % 1000
        guard ri < layout.rows.count, ki < layout.rows[ri].keys.count else { return }
        delegate?.popupKeyboardView(self, didSelect: layout.rows[ri].keys[ki])
    }

    @objc private func keyHighlight(_ sender: UIButton) {
        sender.backgroundColor = palette.pressedKey
    }

    @objc private func keyUnhighlight(_ sender: UIButton) {
        sender.backgroundColor = palette.normalKey
    }

    // MARK: - Helpers

    /// Strip Android XML escape prefixes: \' → ', \? → ?, \@ → @, \\ → \
    private func cleanLabel(_ label: String) -> String {
        guard label.hasPrefix("\\"), label.count > 1 else { return label }
        let rest = String(label.dropFirst())
        return rest == "\\" ? "\\" : rest
    }
}
