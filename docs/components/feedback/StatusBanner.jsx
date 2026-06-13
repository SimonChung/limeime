import React from "react";

/**
 * LIME StatusBanner — the color-coded setup banner (§4.2). Status drives icon
 * + text color; the card itself uses a subtle tint.
 */
export function StatusBanner({ status = "success", children, icon, style = {}, ...rest }) {
  const map = {
    success: { fg: "var(--success-ink)", tint: "var(--status-tint-green)",  sym: CHECK },
    warning: { fg: "var(--warning-ink)", tint: "var(--status-tint-yellow)", sym: WARN },
    danger:  { fg: "var(--danger-ink)",  tint: "var(--status-tint-red)",    sym: XMARK },
  };
  const m = map[status] || map.success;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        padding: "12px 16px",
        borderRadius: "var(--radius-card)",
        background: m.tint,
        color: m.fg,
        font: "var(--weight-semibold) 15px/20px var(--font-sans)",
        ...style,
      }}
      {...rest}
    >
      <span style={{ flex: "0 0 auto", width: 20, height: 20, display: "inline-flex" }}>
        {icon || m.sym}
      </span>
      <span>{children}</span>
    </div>
  );
}

const CHECK = (
  <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
    <path d="M10 0a10 10 0 100 20 10 10 0 000-20zm4.7 7.7l-5.4 5.4a1 1 0 01-1.4 0L5.3 10.5a1 1 0 011.4-1.4l1.9 1.9 4.7-4.7a1 1 0 011.4 1.4z" />
  </svg>
);
const WARN = (
  <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
    <path d="M8.6 1.5L.7 15.2A1.6 1.6 0 002.1 17.6h15.8a1.6 1.6 0 001.4-2.4L11.4 1.5a1.6 1.6 0 00-2.8 0zM10 6a1 1 0 011 1v4a1 1 0 01-2 0V7a1 1 0 011-1zm0 9.5a1.2 1.2 0 110-2.4 1.2 1.2 0 010 2.4z" />
  </svg>
);
const XMARK = (
  <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
    <path d="M10 0a10 10 0 100 20 10 10 0 000-20zm3.5 12.1a1 1 0 01-1.4 1.4L10 11.4l-2.1 2.1a1 1 0 01-1.4-1.4L8.6 10 6.5 7.9a1 1 0 011.4-1.4L10 8.6l2.1-2.1a1 1 0 011.4 1.4L11.4 10z" />
  </svg>
);
