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
    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    // MARK: - State
    private var candidates:  [Mapping] = []
    private var selkeys:     String    = ""   // e.g. "1234567890"
    private var selkeyOption: Int      = 0    // 0=none, 1=show number, 2=show number+space

    // MARK: - Layout constants
    private let candidateFont   = UIFont.systemFont(ofSize: 23)
    private let selkeyFont      = UIFont.systemFont(ofSize: 12, weight: .light)
    private let candidateHPad:   CGFloat = 14
    private let dividerWidth:    CGFloat = 1

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    // MARK: - Setup
    private func setup() {
        backgroundColor = UIColor.systemGray6

        // Horizontal scroll view fills the whole bar; the composing code is
        // rendered as the first candidate entry (distinctively styled), so no
        // dedicated left-edge label is needed anymore.
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
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

    /// Retained for API compatibility. The composing code is now rendered
    /// as the first candidate entry in the bar, so there is no dedicated
    /// left-edge label to update.
    func setComposingCode(_ code: String) { _ = code }

    /// Replace the candidate list with new results.
    func setCandidates(_ mappings: [Mapping]) {
        candidates = mappings
        rebuildButtons()
        scrollView.setContentOffset(.zero, animated: false)
    }

    /// Configure numbered selection key display (spec §6 selkeyOption).
    /// - selkeys: string of selection key characters, e.g. "1234567890"
    /// - option: 0 = no prefix, 1 = show key label, 2 = show key label + space
    func setSelkeyConfig(selkeys: String, option: Int) {
        self.selkeys      = selkeys
        self.selkeyOption = option
    }

    // MARK: - Private

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, mapping) in candidates.enumerated() {
            if index > 0 {
                let sep = makeSeparator()
                stackView.addArrangedSubview(sep)
            }
            let btn = makeCandidateButton(mapping: mapping, index: index)
            stackView.addArrangedSubview(btn)
        }

        // "More" button at the end if there are candidates
        if !candidates.isEmpty {
            let sep = makeSeparator()
            stackView.addArrangedSubview(sep)
            let moreBtn = makeMoreButton()
            stackView.addArrangedSubview(moreBtn)
        }
    }

    private func makeCandidateButton(mapping: Mapping, index: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = index
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: candidateHPad, bottom: 0, right: candidateHPad)
        btn.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)

        // Composing-code record (mixed-mode raw-code entry): styled grey/monospace
        // so the user can visually distinguish it as "commit the raw English letters".
        // Mirrors Android mColorComposingCode.
        let isComposingCode = mapping.isComposingCodeRecord

        // Build selkey prefix when selkeyOption > 0 and a key character exists for this index
        let selkeyPrefix: String
        if !isComposingCode, selkeyOption > 0, !selkeys.isEmpty, index < selkeys.count {
            let keyChar = String(selkeys[selkeys.index(selkeys.startIndex, offsetBy: index)])
            selkeyPrefix = selkeyOption >= 2 ? "\(keyChar) " : keyChar
        } else {
            selkeyPrefix = ""
        }

        if selkeyPrefix.isEmpty {
            btn.setTitle(mapping.word, for: .normal)
            if isComposingCode {
                btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
                btn.setTitleColor(.secondaryLabel, for: .normal)
            } else {
                btn.titleLabel?.font = candidateFont
                // UIButton(type: .system) tints labels with the window tint (blue).
                // Force the dynamic label color so candidates read dark-on-light
                // and light-on-dark.
                btn.setTitleColor(.label, for: .normal)
            }
        } else {
            // Two-line-style button: selkey (small, top) + word (large, bottom) in a stack
            let container = UIStackView()
            container.axis = .vertical
            container.alignment = .center
            container.spacing = -2
            container.isUserInteractionEnabled = false

            let skLabel = UILabel()
            skLabel.text = selkeyPrefix
            skLabel.font = selkeyFont
            skLabel.textColor = .tertiaryLabel

            let wordLabel = UILabel()
            wordLabel.text = mapping.word
            wordLabel.font = candidateFont
            wordLabel.textColor = .label

            container.addArrangedSubview(skLabel)
            container.addArrangedSubview(wordLabel)
            container.translatesAutoresizingMaskIntoConstraints = false
            btn.addSubview(container)
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            ])
        }
        return btn
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sep.widthAnchor.constraint(equalToConstant: dividerWidth),
            sep.heightAnchor.constraint(equalToConstant: 20),
        ])
        return sep
    }

    private func makeMoreButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        btn.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        return btn
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < candidates.count else { return }
        delegate?.candidateBarView(self, didSelect: candidates[index])
    }

    @objc private func moreTapped() {
        delegate?.candidateBarViewDidRequestMore(self)
    }
}
