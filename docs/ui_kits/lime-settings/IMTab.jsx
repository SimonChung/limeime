/* 輸入法 — IM Manager tab. SetupImFragment IM grid + 關聯字庫 (§5.1).
   Stateful enable toggles, reorder-style list, floating + FAB. window.IMTab. */
(function () {
  const { ListGroup, ListRow, Switch } = window.LIMEDesignSystem_6ca3c0;
  const I = window.LimeIcons;

  // Grey rounded-square + Chinese-character avatar — matches the Android kit's IM list.
  function CharAvatar({ glyph }) {
    return React.createElement("span", {
      style: { width: 30, height: 30, flex: "0 0 auto", borderRadius: 7, background: "var(--icon-tile)", color: "#fff",
        display: "flex", alignItems: "center", justifyContent: "center", font: "500 15px/1 var(--font-sans)" },
    }, glyph);
  }
  function IconAvatar({ icon }) {
    return React.createElement("span", {
      style: { width: 30, height: 30, flex: "0 0 auto", borderRadius: 7, background: "var(--icon-tile)", color: "#fff",
        display: "flex", alignItems: "center", justifyContent: "center" },
    }, React.createElement("span", { style: { width: 17, height: 17, display: "inline-flex" } }, icon));
  }

  const IMS = [
    { id: "phonetic", label: "注音", glyph: "ㄅ", on: true },
    { id: "cj",       label: "倉頡", glyph: "倉", on: true },
    { id: "ecj",      label: "速成", glyph: "速", on: true },
    { id: "dayi",     label: "大易", glyph: "易", on: false },
    { id: "array",    label: "行列", glyph: "行", on: false },
    { id: "pinyin",   label: "拼音", glyph: "拼", on: false },
  ];

  function IMTab({ onOpen }) {
    const [ims, setIms] = React.useState(IMS);
    const toggle = (id) => setIms((s) => s.map((m) => (m.id === id ? { ...m, on: !m.on } : m)));
    return React.createElement("div", { style: { position: "relative", minHeight: "100%" } },
      React.createElement("div", { style: { padding: "0 24px 28px", display: "flex", flexDirection: "column", gap: 22 } },
        React.createElement("div", { style: { font: "700 34px/41px var(--font-sans)", letterSpacing: "-.4px", padding: "8px 0 0" } }, "管理輸入法"),
        React.createElement(ListGroup, { header: "已安裝的輸入法" },
          ...ims.map((m) =>
            React.createElement(ListRow, {
              key: m.id,
              leading: React.createElement(CharAvatar, { glyph: m.glyph }),
              title: m.label,
              style: { opacity: m.on ? 1 : 0.55 },
              onClick: () => onOpen && onOpen(m),
              chevron: true,
              trailing: React.createElement("span", { onClick: (e) => e.stopPropagation() },
                React.createElement(Switch, { checked: m.on, onChange: () => toggle(m.id) })),
            })
          )
        ),
        React.createElement(ListGroup, { header: "關聯字庫" },
          React.createElement(ListRow, { leading: React.createElement(IconAvatar, { icon: I.bubble({ size: 17 }) }), title: "關聯字庫", chevron: true, onClick: () => onOpen && onOpen({ id: "related", label: "關聯字庫", related: true }) })
        )
      ),
      // Floating action button
      React.createElement("button", {
        type: "button",
        style: {
          position: "absolute", right: 20, bottom: 20, width: 52, height: 52,
          borderRadius: "50%", border: "none", background: "var(--accent-blue)", color: "#fff",
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: "var(--shadow-fab)", cursor: "pointer",
        },
      }, I.plus({ size: 26 }))
    );
  }
  window.IMTab = IMTab;
})();
