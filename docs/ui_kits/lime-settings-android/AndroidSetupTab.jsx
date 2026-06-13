/* 設定 — Android App Setup tab. Grounded in the real Android source
   LimeStudio/app/src/main/res/layout/fragment_setup.xml + SetupFragment.java
   (horizontal brand row, neutral status card, About card), but kept VISUALLY
   ALIGNED to the iOS SetupTab per the user's request (b): same structure —
   brand hero, success status, 設定萊姆輸入法 step guide, 前往設定 button, and a
   three-chip About footer (使用手冊 / 版權說明 / 原始碼) + copyright banner.
   Theme colour is inherited from the system (Material You) — no in-app control. */
(function () {
  const { Icon, Button } = window.LimeM3;

  const LICENSE_URL = "https://lime-ime.github.io/limeime/pages/license.html"; // R.string.url_license_limeime
  const MANUAL_URL = "https://lime-ime.github.io/limeime/pages/index.html";
  const GITHUB_URL = "https://github.com/lime-ime/limeime";                    // R.string.url_github_limeime

  const FG_GREEN = "#2e7d32"; // @color/setup_status_fg_green
  const STATUS_BG = "color-mix(in srgb, #808080 12%, transparent)"; // @color/setup_status_bg

  // Status card — neutral background, icon + text in the state colour (iOS parity).
  function StatusCard() {
    return React.createElement("div", {
      style: { display: "flex", alignItems: "center", gap: 10, padding: "12px 14px", borderRadius: 12, background: STATUS_BG },
    },
      React.createElement(Icon, { name: "check_circle", size: 20, fill: true, color: FG_GREEN }),
      React.createElement("span", { style: { font: "500 15px/20px 'Roboto', var(--font-sans)", color: FG_GREEN } }, "萊姆輸入法已啟用")
    );
  }

  // Green M3 toggle visual used in the activation step guide (matches iOS GreenToggle).
  function GreenToggle() {
    return React.createElement("div", { style: { width: 30, height: 18, borderRadius: 9, background: "var(--md-primary)", position: "relative", flex: "0 0 auto" } },
      React.createElement("div", { style: { position: "absolute", right: 2, top: 2, width: 14, height: 14, borderRadius: "50%", background: "var(--md-on-primary)", boxShadow: "0 1px 1px rgba(0,0,0,.18)" } }));
  }
  function StepRow({ icon, text }) {
    return React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 16 } },
      React.createElement("div", { style: { width: 32, display: "flex", justifyContent: "center", color: "var(--md-primary)" } }, icon),
      React.createElement("div", { style: { font: "400 17px/22px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)" } }, text)
    );
  }

  // Compact link chip aligned to the iOS footer: equal-width, rounded, tonal fill,
  // icon over label + external glyph.
  function LinkChip({ href, icon, children }) {
    return React.createElement("a", { href, target: "_blank", rel: "noopener noreferrer",
      style: { flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 7,
        padding: "15px 8px 13px", borderRadius: 14, background: "var(--md-surface-container-high)",
        color: "var(--md-primary)", textDecoration: "none", WebkitTapHighlightColor: "transparent" } },
      React.createElement(Icon, { name: icon, size: 22, color: "var(--md-primary)" }),
      React.createElement("span", { style: { display: "inline-flex", alignItems: "center", gap: 3, font: "500 14px/18px 'Roboto', var(--font-sans)" } },
        children, React.createElement(Icon, { name: "open_in_new", size: 13, style: { opacity: .7 } }))
    );
  }

  function AndroidSetupTab() {
    return React.createElement("div", { style: { padding: "8px 24px 28px", display: "flex", flexDirection: "column", gap: 24 } },
      // Brand hero — plain logo + wordmark, horizontal (aligned to iOS)
      React.createElement("div", { style: { display: "flex", flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 16, paddingTop: 20 } },
        React.createElement("img", { src: "../../assets/lime-logo-android.png", alt: "LIME", style: { width: 92, height: 92, objectFit: "contain" } }),
        React.createElement("div", { style: { font: "700 30px/36px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)" } }, "萊姆輸入法")
      ),
      React.createElement(StatusCard),
      React.createElement("div", { style: { font: "700 28px/34px 'Roboto', var(--font-sans)", color: "var(--md-on-surface)" } }, "設定萊姆輸入法"),
      React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16 } },
        React.createElement(StepRow, { icon: React.createElement(Icon, { name: "keyboard", size: 24, color: "var(--md-primary)" }), text: "輕觸「鍵盤」" }),
        React.createElement(StepRow, { icon: React.createElement(GreenToggle), text: "開啟萊姆輸入法" }),
        React.createElement(StepRow, { icon: React.createElement(GreenToggle), text: "開啟「允許完整取用」" })
      ),
      React.createElement("div", { style: { font: "400 15px/20px 'Roboto', var(--font-sans)", color: "var(--md-on-surface-variant)", textAlign: "center" } },
        "萊姆輸入法僅需完整取用以啟用按鍵震動回饋。若不需要此功能，可不開啟。萊姆輸入法不會收集或傳送任何個人資料。"),
      React.createElement(Button, { variant: "filled", full: true }, "前往設定"),
      React.createElement("div", { style: { font: "400 13px/18px 'Roboto', var(--font-sans)", color: "var(--md-on-surface-variant)", textAlign: "center" } },
        "若設定未直接顯示萊姆輸入法，請到「設定」>「系統」>「語言與輸入」>「螢幕鍵盤」開啟。"),
      // About footer — three equal-width chips + one-line copyright (aligned to iOS)
      React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16, paddingTop: 10 } },
        React.createElement("div", { style: { height: 1, background: "var(--md-outline-variant)", margin: "0 -24px" } }),
        React.createElement("div", { style: { display: "flex", gap: 10 } },
          React.createElement(LinkChip, { href: MANUAL_URL, icon: "menu_book" }, "使用手冊"),
          React.createElement(LinkChip, { href: LICENSE_URL, icon: "description" }, "版權說明"),
          React.createElement(LinkChip, { href: GITHUB_URL, icon: "code" }, "原始碼")
        ),
        React.createElement("div", { style: { font: "400 13px/18px 'Roboto', var(--font-sans)", color: "var(--md-on-surface-variant)", textAlign: "center", paddingTop: 6 } },
          "© LIME 萊姆輸入法 6.1.15 - 2026")
      )
    );
  }
  window.AndroidSetupTab = AndroidSetupTab;
})();
