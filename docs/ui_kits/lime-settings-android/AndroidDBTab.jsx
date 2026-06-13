/* 資料庫 — Android DB Manager. Faithful to the real Android source
   LimeStudio/app/src/main/res/layout/fragment_db_manager.xml: a 28sp bold inline
   heading, then three sections each = a small secondary label + an UnelevatedButton
   (radius 10dp, neutral setup_status_bg background, left-aligned tinted text+icon)
   + a 12sp secondary footer. Backup is colorPrimary; restore + reset are red. */
(function () {
  const { Icon, Button } = window.LimeM3;

  // Action + its supporting description, stacked tightly (no redundant title).
  function Action({ button, footer, gap, warn }) {
    return React.createElement("div", { style: { marginBottom: gap, display: "flex", flexDirection: "column", gap: 8 } },
      button,
      footer && React.createElement("div", { style: { display: "flex", alignItems: "flex-start", gap: 6, padding: "0 4px",
          font: "400 13px/18px 'Roboto', var(--font-sans)", color: warn ? "var(--md-error)" : "var(--md-on-surface-variant)" } },
        warn && React.createElement(Icon, { name: "warning", size: 15, fill: true, color: "var(--md-error)", style: { flex: "0 0 auto", marginTop: 1 } }),
        React.createElement("span", null, footer))
    );
  }

  function AndroidDBTab() {
    return React.createElement("div", { style: { padding: "16px 16px 24px", display: "flex", flexDirection: "column" } },
      // 28sp bold inline heading (textColorPrimary)
      React.createElement("div", { style: { font: "700 34px/41px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)", padding: "8px 0 18px" } }, "資料庫管理"),

      React.createElement(Action, { gap: 12, footer: "備份包含所有字根、關聯字及喜好設定。",
        button: React.createElement(Button, { variant: "filled", icon: "upload", full: true }, "備份資料庫") }),

      React.createElement(Action, { gap: 12, footer: "還原後鍵盤將重新載入資料庫。",
        button: React.createElement(Button, { variant: "outlined", icon: "download", full: true }, "還原資料庫") }),

      React.createElement(Action, { gap: 0, warn: true, footer: "警告：將清除目前所有輸入法資料表，還原為萊姆內建的空白預設資料庫，此動作無法復原。",
        button: React.createElement(Button, { variant: "error", icon: "refresh", full: true }, "還原預設資料庫") })
    );
  }
  window.AndroidDBTab = AndroidDBTab;
})();
