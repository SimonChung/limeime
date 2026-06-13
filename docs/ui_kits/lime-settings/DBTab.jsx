/* 資料庫 — DB Manager tab. Mirrors DBManagerView.swift §7.
   Re-laid-out to match the Android kit: each action is a Button inside a
   grouped section with a supporting footer (備份 / 還原 / 初始資料庫). */
(function () {
  const { Button } = window.LIMEDesignSystem_6ca3c0;
  const I = window.LimeIcons;

  function Action({ button, footer, gap, warn }) {
    return React.createElement("div", { style: { marginBottom: gap, display: "flex", flexDirection: "column", gap: 8 } },
      button,
      footer && React.createElement("div", { style: { display: "flex", alignItems: "flex-start", gap: 6, padding: "0 4px",
          font: "400 13px/18px var(--font-sans)", color: warn ? "var(--danger-ink)" : "var(--text-secondary)" } },
        warn && React.createElement("span", { style: { width: 15, height: 15, flex: "0 0 auto", display: "inline-flex", marginTop: 1 } }, I.info ? I.info({ size: 15 }) : null),
        React.createElement("span", null, footer))
    );
  }

  function DBTab() {
    return React.createElement("div", { style: { padding: "0 24px 28px", display: "flex", flexDirection: "column" } },
      React.createElement("div", { style: { font: "700 34px/41px var(--font-sans)", letterSpacing: "-.4px", padding: "8px 0 20px" } }, "資料庫管理"),

      React.createElement(Action, { gap: 12, footer: "備份包含所有字根、關聯字及喜好設定。",
        button: React.createElement(Button, { variant: "prominent", fullWidth: true, icon: I.upload({ size: 18 }) }, "備份資料庫") }),

      React.createElement(Action, { gap: 12, footer: "還原後鍵盤將重新載入資料庫。",
        button: React.createElement(Button, { variant: "bordered", fullWidth: true, icon: I.download({ size: 18 }) }, "還原資料庫") }),

      React.createElement(Action, { gap: 12, warn: true, footer: "警告：將清除目前所有輸入法資料表，還原為萊姆內建的空白預設資料庫，此動作無法復原。",
        button: React.createElement(Button, { variant: "bordered", destructive: true, fullWidth: true, icon: I.refresh({ size: 18 }) }, "還原預設資料庫") }),

      React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, padding: "4px 4px 0", color: "var(--text-secondary)" } },
        React.createElement("span", { style: { width: 16, height: 16, display: "inline-flex" } }, I.info ? I.info({ size: 16 }) : null),
        React.createElement("span", { style: { font: "400 13px/18px var(--font-sans)" } }, "上次備份：lime_backup_1718.zip · 2.4 MB")
      )
    );
  }
  window.DBTab = DBTab;
})();
