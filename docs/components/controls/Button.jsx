import React from "react";

/**
 * LIME Button — iOS-HIG button rendered in the LIME brand.
 * Variants: prominent (filled brand green), bordered (tinted fill),
 * plain (text only), destructive. Sizes: large / regular / small.
 */
export function Button({
  variant = "prominent",
  size = "regular",
  destructive = false,
  fullWidth = false,
  disabled = false,
  icon = null,
  children,
  style = {},
  ...rest
}) {
  const sizes = {
    large:   { pad: "14px 22px", font: "17px", weight: 600, radius: "var(--radius-button)", gap: "8px" },
    regular: { pad: "10px 18px", font: "17px", weight: 600, radius: "var(--radius-button)", gap: "6px" },
    small:   { pad: "6px 12px",  font: "15px", weight: 600, radius: "8px", gap: "5px" },
  };
  const s = sizes[size] || sizes.regular;

  const tint = destructive ? "var(--danger)" : "var(--accent)";
  const base = {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: s.gap,
    width: fullWidth ? "100%" : "auto",
    padding: s.pad,
    fontFamily: "var(--font-sans)",
    fontSize: s.font,
    fontWeight: s.weight,
    lineHeight: 1.1,
    border: "none",
    borderRadius: s.radius,
    cursor: disabled ? "default" : "pointer",
    opacity: disabled ? 0.4 : 1,
    transition: "filter .12s ease, opacity .12s ease, background .12s ease",
    WebkitTapHighlightColor: "transparent",
  };

  const variants = {
    prominent: { background: tint, color: "#fff" },
    bordered:  { background: destructive ? "rgba(255,59,48,0.12)" : "rgba(0,148,68,0.12)", color: tint },
    plain:     { background: "transparent", color: tint, padding: s.pad.replace(/\d+px$/, "0") },
  };

  return (
    <button
      type="button"
      disabled={disabled}
      style={{ ...base, ...(variants[variant] || variants.prominent), ...style }}
      onMouseDown={(e) => { if (!disabled) e.currentTarget.style.filter = "brightness(0.92)"; }}
      onMouseUp={(e) => { e.currentTarget.style.filter = "none"; }}
      onMouseLeave={(e) => { e.currentTarget.style.filter = "none"; }}
      {...rest}
    >
      {icon && <span style={{ display: "inline-flex", width: "1.1em", height: "1.1em" }}>{icon}</span>}
      {children}
    </button>
  );
}
