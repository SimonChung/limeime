/* Material 3 primitives + Material You palette engine for the LIME Android kit.
   Exposed on window.LimeM3. Icons use the Material Symbols Rounded webfont. */
(function () {
  // ── Material You light-scheme tonal palettes (seed → roles) ──────────────
  // Re-seeding these on #device is the whole point: on Android the app chrome
  // adopts the SYSTEM colour scheme (Material You), unlike the fixed-brand iOS app.
  // Each palette carries BOTH a light (v) and dark (d) tonal role map. Material You
  // generates both from the one system seed; day/night is MODE_NIGHT_FOLLOW_SYSTEM.
  const PALETTES = {
    green:  { label: "綠", seed: "#5b8a2c",
      v: { "primary":"#386a20","on-primary":"#ffffff","primary-container":"#b7f397","on-primary-container":"#042100",
           "secondary-container":"#d7e8c8","on-secondary-container":"#121f0d",
           "surface":"#f8faf0","surface-container-low":"#f2f5e9","surface-container":"#ecefe3",
           "surface-container-high":"#e6e9de","surface-container-highest":"#e0e4d8",
           "on-surface":"#1a1c16","on-surface-variant":"#44483b","outline":"#75796c","outline-variant":"#c5c8b9","error":"#ba1a1a" },
      d: { "primary":"#9cd67d","on-primary":"#0a3900","primary-container":"#1f5200","on-primary-container":"#b7f397",
           "secondary-container":"#3a4a31","on-secondary-container":"#d7e8c8",
           "surface":"#11140d","surface-container-low":"#1a1c16","surface-container":"#1e201a",
           "surface-container-high":"#282b24","surface-container-highest":"#33362e",
           "on-surface":"#e2e3d8","on-surface-variant":"#c5c8b9","outline":"#8f9285","outline-variant":"#44483b","error":"#ffb4ab" } },
    purple: { label: "紫", seed: "#6750a4",
      v: { "primary":"#65558f","on-primary":"#ffffff","primary-container":"#e9ddff","on-primary-container":"#21005d",
           "secondary-container":"#e8def8","on-secondary-container":"#1d192b",
           "surface":"#fdf7ff","surface-container-low":"#f7f2fa","surface-container":"#f2ecf4",
           "surface-container-high":"#ece6ee","surface-container-highest":"#e6e0e9",
           "on-surface":"#1d1b20","on-surface-variant":"#49454e","outline":"#7a757f","outline-variant":"#cac4cf","error":"#ba1a1a" },
      d: { "primary":"#cfbdfe","on-primary":"#36275d","primary-container":"#4d3d75","on-primary-container":"#e9ddff",
           "secondary-container":"#4a4458","on-secondary-container":"#e8def8",
           "surface":"#141218","surface-container-low":"#1d1b20","surface-container":"#211f26",
           "surface-container-high":"#2b2930","surface-container-highest":"#36343b",
           "on-surface":"#e6e0e9","on-surface-variant":"#cac4cf","outline":"#948f99","outline-variant":"#49454e","error":"#ffb4ab" } },
    blue:   { label: "藍", seed: "#2196f3",
      v: { "primary":"#36618e","on-primary":"#ffffff","primary-container":"#d1e4ff","on-primary-container":"#001d36",
           "secondary-container":"#d7e3f7","on-secondary-container":"#101c2b",
           "surface":"#f8f9ff","surface-container-low":"#f2f3fa","surface-container":"#eceef4",
           "surface-container-high":"#e6e8ee","surface-container-highest":"#e1e2e8",
           "on-surface":"#191c20","on-surface-variant":"#43474e","outline":"#73777f","outline-variant":"#c3c6cf","error":"#ba1a1a" },
      d: { "primary":"#a0cafd","on-primary":"#003258","primary-container":"#194975","on-primary-container":"#d1e4ff",
           "secondary-container":"#3b4858","on-secondary-container":"#d7e3f7",
           "surface":"#101418","surface-container-low":"#191c20","surface-container":"#1d2024",
           "surface-container-high":"#272a2f","surface-container-highest":"#32353a",
           "on-surface":"#e1e2e8","on-surface-variant":"#c3c6cf","outline":"#8d9199","outline-variant":"#43474e","error":"#ffb4ab" } },
    coral:  { label: "橘", seed: "#b0573c",
      v: { "primary":"#8f4c38","on-primary":"#ffffff","primary-container":"#ffdbd1","on-primary-container":"#3a0b01",
           "secondary-container":"#ffdbcf","on-secondary-container":"#2c150d",
           "surface":"#fff8f6","surface-container-low":"#fef1ec","surface-container":"#f8ebe6",
           "surface-container-high":"#f3e5e0","surface-container-highest":"#ece0da",
           "on-surface":"#231917","on-surface-variant":"#53433f","outline":"#85736e","outline-variant":"#d8c2bb","error":"#ba1a1a" },
      d: { "primary":"#ffb5a0","on-primary":"#561f0f","primary-container":"#723523","on-primary-container":"#ffdbd1",
           "secondary-container":"#5d4037","on-secondary-container":"#ffdbcf",
           "surface":"#1a110f","surface-container-low":"#231917","surface-container":"#271d1b",
           "surface-container-high":"#322825","surface-container-highest":"#3d3230",
           "on-surface":"#f1dfda","on-surface-variant":"#d8c2bb","outline":"#a08c87","outline-variant":"#53433f","error":"#ffb4ab" } },
  };

  let _seed = "green", _mode = "light";
  function applyPalette(key, mode) {
    if (key) _seed = key;
    if (mode) _mode = mode;
    const p = PALETTES[_seed]; if (!p) return;
    const dev = document.getElementById("device"); if (!dev) return;
    const roles = _mode === "dark" ? p.d : p.v;
    Object.entries(roles).forEach(([k, val]) => dev.style.setProperty("--md-" + k, val));
    // Semantic status colours are palette-independent (Material You themes only
    // `error`); set success/warning per light/dark so banners read in both modes.
    const status = _mode === "dark"
      ? { success: "#9cd67d", warning: "#ffb951" }
      : { success: "#2e7d32", warning: "#8a6100" };
    dev.style.setProperty("--md-success", status.success);
    dev.style.setProperty("--md-warning", status.warning);
    dev.setAttribute("data-mode", _mode);
  }

  const Icon = ({ name, size = 24, fill = false, color, style }) =>
    React.createElement("span", {
      className: "msr" + (fill ? " fill" : ""),
      style: { fontSize: size, color: color || "inherit", ...style },
    }, name);

  // ── Material 3 switch ────────────────────────────────────────────────────
  function Switch({ checked, onChange, disabled }) {
    const on = !!checked;
    return React.createElement("button", {
      onClick: () => !disabled && onChange && onChange(!on),
      "aria-pressed": on,
      style: {
        flex: "0 0 auto", width: 52, height: 32, borderRadius: 16, position: "relative", border: 0, padding: 0,
        cursor: disabled ? "default" : "pointer", transition: "background .18s, border-color .18s",
        background: on ? "var(--md-primary)" : "var(--md-surface-container-highest)",
        boxShadow: on ? "none" : "inset 0 0 0 2px var(--md-outline)",
        opacity: disabled ? .38 : 1,
      },
    }, React.createElement("span", {
      style: {
        position: "absolute", top: "50%", left: on ? 30 : 8, transform: "translateY(-50%)",
        width: on ? 24 : 16, height: on ? 24 : 16, borderRadius: "50%",
        background: on ? "var(--md-on-primary)" : "var(--md-outline)",
        transition: "left .18s cubic-bezier(.2,0,0,1), width .18s, height .18s, background .18s",
        display: "flex", alignItems: "center", justifyContent: "center",
      },
    }, on && React.createElement("span", { className: "msr fill", style: { fontSize: 16, color: "var(--md-on-primary-container)" } }, "check")));
  }

  // ── Material 3 buttons ───────────────────────────────────────────────────
  function Button({ variant = "filled", icon, children, onClick, color, full }) {
    const base = {
      display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
      height: 46, padding: icon ? "0 24px 0 16px" : "0 24px", borderRadius: 20, border: 0,
      font: "600 17px/1 'Roboto', var(--font-sans)", letterSpacing: ".1px", cursor: "pointer",
      width: full ? "100%" : "auto", WebkitTapHighlightColor: "transparent",
    };
    const skins = {
      filled: { background: "var(--md-primary)", color: "var(--md-on-primary)" },
      tonal: { background: "var(--md-secondary-container)", color: "var(--md-on-secondary-container)" },
      // Aligned to the iOS Button "bordered" variant: a subtle 12% tinted fill
      // (no outline), text in the tint colour. Adapts across light/dark + palettes.
      outlined: { background: "color-mix(in srgb, " + (color || "var(--md-primary)") + " 12%, transparent)", color: color || "var(--md-primary)" },
      text: { background: "transparent", color: color || "var(--md-primary)", padding: "0 12px" },
      error: { background: "color-mix(in srgb, var(--md-error) 12%, transparent)", color: "var(--md-error)" },
    };
    return React.createElement("button", { onClick, style: { ...base, ...skins[variant] } },
      icon && React.createElement(Icon, { name: icon, size: 18, color: skins[variant].color }),
      children);
  }

  // ── Bottom NavigationBar (M3) ────────────────────────────────────────────
  function NavBar({ items, active, onChange }) {
    return React.createElement("nav", {
      style: { display: "flex", height: 80, background: "var(--md-surface-container)", paddingTop: 12, transition: "background .35s ease" },
    }, items.map((it) => {
      const sel = it.key === active;
      return React.createElement("button", {
        key: it.key, onClick: () => onChange(it.key),
        style: { flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4, border: 0, background: "transparent", cursor: "pointer", padding: 0, WebkitTapHighlightColor: "transparent" },
      },
        React.createElement("span", {
          style: {
            width: 64, height: 32, borderRadius: 16, display: "flex", alignItems: "center", justifyContent: "center",
            background: sel ? "var(--md-secondary-container)" : "transparent", transition: "background .18s",
          },
        }, React.createElement(Icon, { name: it.icon, size: 24, fill: sel, color: sel ? "var(--md-on-secondary-container)" : "var(--md-on-surface-variant)" })),
        React.createElement("span", {
          style: { font: (sel ? 700 : 500) + " 12px/16px 'Roboto', var(--font-sans)", color: sel ? "var(--md-on-surface)" : "var(--md-on-surface-variant)" },
        }, it.label)
      );
    }));
  }

  // ── Navigation Rail (M3, tablet) ─────────────────────────────────────────
  function NavRail({ items, active, onChange, fab }) {
    return React.createElement("nav", {
      style: { width: 88, flex: "0 0 auto", display: "flex", flexDirection: "column", alignItems: "center",
        gap: 12, padding: "20px 0", background: "var(--md-surface)", transition: "background .35s ease" },
    },
      fab && React.createElement("button", {
        type: "button", onClick: fab.onClick,
        style: { width: 56, height: 56, borderRadius: 16, border: 0, marginBottom: 8,
          background: "var(--md-primary-container)", color: "var(--md-on-primary-container)",
          display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer",
          boxShadow: "0 1px 3px rgba(0,0,0,.3)" },
      }, React.createElement(Icon, { name: fab.icon || "add", size: 24 })),
      items.map((it) => {
        const sel = it.key === active;
        return React.createElement("button", {
          key: it.key, onClick: () => onChange(it.key),
          style: { display: "flex", flexDirection: "column", alignItems: "center", gap: 4, border: 0,
            background: "transparent", cursor: "pointer", padding: 0, WebkitTapHighlightColor: "transparent" },
        },
          React.createElement("span", {
            style: { width: 56, height: 32, borderRadius: 16, display: "flex", alignItems: "center", justifyContent: "center",
              background: sel ? "var(--md-secondary-container)" : "transparent", transition: "background .18s" },
          }, React.createElement(Icon, { name: it.icon, size: 24, fill: sel, color: sel ? "var(--md-on-secondary-container)" : "var(--md-on-surface-variant)" })),
          React.createElement("span", {
            style: { font: (sel ? 700 : 500) + " 12px/16px 'Roboto', var(--font-sans)", color: sel ? "var(--md-on-surface)" : "var(--md-on-surface-variant)" },
          }, it.label)
        );
      })
    );
  }

  // ── Material You palette chip switcher ───────────────────────────────────
  function PaletteSwitcher({ value, onChange }) {
    return React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 10 } },
      React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, color: "var(--md-on-surface-variant)", font: "500 13px/1 'Roboto', var(--font-sans)" } },
        React.createElement(Icon, { name: "palette", size: 18 }), "系統佈景主題色 (Material You)"),
      React.createElement("div", { style: { display: "flex", gap: 12 } },
        Object.entries(PALETTES).map(([key, p]) => {
          const sel = key === value;
          return React.createElement("button", {
            key, onClick: () => onChange(key), title: p.label,
            style: {
              width: 44, height: 44, borderRadius: "50%", cursor: "pointer", background: p.seed,
              border: sel ? "3px solid var(--md-on-surface)" : "3px solid transparent",
              outline: sel ? "2px solid var(--md-surface)" : "none", outlineOffset: -5,
              display: "flex", alignItems: "center", justifyContent: "center", WebkitTapHighlightColor: "transparent",
            },
          }, sel && React.createElement("span", { className: "msr fill", style: { fontSize: 22, color: "#fff" } }, "check"));
        })
      )
    );
  }

  window.LimeM3 = { Icon, Switch, Button, NavBar, NavRail, PaletteSwitcher, PALETTES, applyPalette };
  window.LimeM3.getMode = () => _mode;
})();
