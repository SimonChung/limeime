import React from "react";

/**
 * LIME Switch — the iOS toggle with the LIME-green ON track.
 * Matches LimeSettings ToggleSwitchIcon (track #4CAF50, white thumb).
 */
export function Switch({ checked = false, disabled = false, onChange, style = {}, ...rest }) {
  const W = 51, H = 31, T = 27;
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange && onChange(!checked)}
      style={{
        position: "relative",
        width: W,
        height: H,
        flex: "0 0 auto",
        padding: 0,
        border: "none",
        borderRadius: H / 2,
        background: checked ? "var(--switch-on)" : "rgba(120,120,128,0.16)",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.5 : 1,
        transition: "background .22s ease",
        WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      <span
        style={{
          position: "absolute",
          top: (H - T) / 2,
          left: checked ? W - T - 2 : 2,
          width: T,
          height: T,
          borderRadius: "50%",
          background: "#fff",
          boxShadow: "0 1px 1px rgba(0,0,0,0.18), 0 3px 8px rgba(0,0,0,0.10)",
          transition: "left .22s cubic-bezier(.4,.0,.2,1)",
        }}
      />
    </button>
  );
}
