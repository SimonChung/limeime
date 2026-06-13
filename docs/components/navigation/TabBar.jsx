import React from "react";

/**
 * LIME TabBar — the iOS bottom tab bar for the 4-tab settings app.
 * items: [{ key, label, icon }]. Active tab tinted brand green.
 */
export function TabBar({ items = [], active, onChange, style = {}, ...rest }) {
  const cur = active ?? items[0]?.key;
  return (
    <nav
      style={{
        display: "flex",
        alignItems: "stretch",
        background: "rgba(249,249,249,0.94)",
        backdropFilter: "saturate(180%) blur(20px)",
        WebkitBackdropFilter: "saturate(180%) blur(20px)",
        borderTop: "0.5px solid var(--separator)",
        fontFamily: "var(--font-sans)",
        ...style,
      }}
      {...rest}
    >
      {items.map((it) => {
        const on = it.key === cur;
        const color = on ? "var(--accent)" : "var(--text-secondary)";
        return (
          <button
            key={it.key}
            type="button"
            onClick={() => onChange && onChange(it.key)}
            style={{
              flex: 1,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              gap: 3,
              padding: "7px 0 9px",
              border: "none",
              background: "transparent",
              color,
              cursor: "pointer",
              WebkitTapHighlightColor: "transparent",
            }}
          >
            <span style={{ width: 26, height: 26, display: "inline-flex", alignItems: "center", justifyContent: "center" }}>
              {it.icon}
            </span>
            <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: "0.1px" }}>{it.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
