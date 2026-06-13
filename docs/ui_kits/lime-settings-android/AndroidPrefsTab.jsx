/* 喜好設定 — Android IM Preferences (Material 3). Mirrors §8 / iOS PrefsTab.
   Material preference rows: title + summary, trailing switch or value. */
(function () {
  const { Icon, Switch } = window.LimeM3;

  function Group({ header, children }) {
    return React.createElement("div", { style: { display: "flex", flexDirection: "column" } },
      React.createElement("div", { style: { font: "500 13px/18px 'Roboto', var(--font-sans)", color: "var(--md-primary)", padding: "10px 8px 4px" } }, header),
      children
    );
  }
  // Material preference row — leading icon optional, title + summary, trailing slot.
  function Pref({ icon, title, summary, value, chevron, trailing, dim }) {
    return React.createElement("div", {
      style: { display: "flex", alignItems: "center", gap: 16, minHeight: 60, padding: "10px 8px",
        opacity: dim ? 0.5 : 1, WebkitTapHighlightColor: "transparent", borderRadius: 16, cursor: chevron ? "pointer" : "default" },
    },
      icon && React.createElement("span", { style: { width: 24, display: "flex", justifyContent: "center", color: "var(--md-on-surface-variant)" } },
        React.createElement(Icon, { name: icon, size: 24 })),
      React.createElement("div", { style: { flex: 1, minWidth: 0 } },
        React.createElement("div", { style: { font: "400 17px/22px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)" } }, title),
        summary && React.createElement("div", { style: { font: "400 13px/18px 'Roboto', var(--font-sans)", color: "var(--md-on-surface-variant)", marginTop: 1 } }, summary)
      ),
      value != null && React.createElement("span", { style: { font: "400 17px/22px 'Roboto', var(--font-sans)", color: "var(--md-primary)" } }, value),
      trailing,
      chevron && React.createElement(Icon, { name: "chevron_right", size: 22, color: "var(--md-on-surface-variant)" })
    );
  }
  function Divider() { return React.createElement("div", { style: { height: 1, background: "var(--md-outline-variant)", margin: "6px 8px" } }); }

  // M3 single-select segmented buttons — equal-width segments (flex: 1).
  function Segmented({ options, value, onChange }) {
    return React.createElement("div", { style: { display: "flex", width: "100%", borderRadius: 20, overflow: "hidden", boxShadow: "inset 0 0 0 1px var(--md-outline)" } },
      options.map((o, i) => {
        const sel = o === value;
        return React.createElement("button", {
          key: o, onClick: () => onChange(o),
          style: { flex: 1, display: "flex", alignItems: "center", justifyContent: "center", gap: 4, height: 38, padding: "0 8px", border: 0,
            borderLeft: i ? "1px solid var(--md-outline)" : "none",
            background: sel ? "var(--md-secondary-container)" : "transparent",
            color: sel ? "var(--md-on-secondary-container)" : "var(--md-on-surface)",
            font: "500 13px/1 'Roboto', var(--font-sans)", cursor: "pointer", whiteSpace: "nowrap" },
        }, sel && React.createElement(Icon, { name: "check", size: 16 }), o);
      })
    );
  }

  function AndroidPrefsTab() {
    const [s, setS] = React.useState({ numberRow: true, vibrate: true, sound: false, smart: true, autoSymbol: false, persistLang: false, related: true, learn: true, dict: true, autoCap: true });
    const t = (k) => () => setS((p) => ({ ...p, [k]: !p[k] }));
    const sw = (k) => React.createElement(Switch, { checked: s[k], onChange: t(k) });
    const [han, setHan] = React.useState("繁轉簡");

    return React.createElement("div", { style: { padding: "0 16px 28px", display: "flex", flexDirection: "column" } },
      React.createElement("div", { style: { font: "700 34px/41px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)", padding: "12px 8px 10px" } }, "喜好設定"),
      React.createElement(Group, { header: "鍵盤外觀" },
        React.createElement(Pref, { icon: "palette", title: "鍵盤樣式", value: "放鬆綠", chevron: true }),
        React.createElement(Pref, { title: "鍵盤大小", value: "一般", chevron: true }),
        React.createElement(Pref, { title: "字型大小", value: "一般", chevron: true }),
        React.createElement(Pref, { title: "數字列英文鍵盤", summary: "在英文鍵盤顯示數字列 (5 列鍵盤)", trailing: sw("numberRow") }),
        React.createElement(Pref, { title: "顯示方向鍵", value: "無", chevron: true })
      ),
      React.createElement(Divider),
      React.createElement(Group, { header: "鍵盤回饋" },
        React.createElement(Pref, { icon: "vibration", title: "打字震動", trailing: sw("vibrate") }),
        React.createElement(Pref, { title: "震動強度", value: "中", chevron: true, dim: !s.vibrate }),
        React.createElement(Pref, { title: "打字音效", trailing: sw("sound") })
      ),
      React.createElement(Divider),
      React.createElement(Group, { header: "輸入法行為" },
        React.createElement(Pref, { icon: "auto_awesome", title: "開啟中文智慧組詞", summary: "部份輸入法可能會影響中英混打功能", trailing: sw("smart") }),
        React.createElement(Pref, { title: "自動中文標點模式", summary: "無候選字詞時顯示中文標點選項", trailing: sw("autoSymbol") }),
        React.createElement(Pref, { title: "記憶中英模式", summary: "下次切換前保持中英模式", trailing: sw("persistLang") }),
        React.createElement(Pref, { icon: "search", title: "字根反查設定", chevron: true })
      ),
      React.createElement(Divider),
      React.createElement(Group, { header: "簡繁轉換" },
        React.createElement("div", { style: { padding: "10px 8px", display: "flex", flexDirection: "column", gap: 12 } },
          React.createElement("div", { style: { font: "400 17px/22px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)" } }, "字碼轉換"),
          React.createElement(Segmented, { options: ["無", "繁轉簡", "簡轉繁"], value: han, onChange: setHan }),
          React.createElement("div", { style: { font: "400 13px/18px 'Roboto', var(--font-sans)", color: "var(--md-on-surface-variant)" } }, "套用於所有輸入法的候選字輸出。")
        )
      ),
      React.createElement(Divider),
      React.createElement(Group, { header: "關聯字與學習" },
        React.createElement(Pref, { icon: "chat", title: "啟用關聯字庫", summary: "啟用關聯字庫功能", trailing: sw("related") }),
        React.createElement(Pref, { title: "自動學習新詞", summary: "從常用關聯字學習新詞", trailing: sw("learn") })
      ),
      React.createElement(Divider),
      React.createElement(Group, { header: "英文鍵盤" },
        React.createElement(Pref, { icon: "abc", title: "啟用英文字典", summary: "英文模式下顯示英文建議字", trailing: sw("dict") }),
        React.createElement(Pref, { title: "首字自動大寫", summary: "句首字母自動轉為大寫", trailing: sw("autoCap") })
      )
    );
  }
  window.AndroidPrefsTab = AndroidPrefsTab;
})();
