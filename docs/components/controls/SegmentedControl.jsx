import React from "react";

/**
 * LIME SegmentedControl — iOS segmented picker (used for 簡繁轉換, search-by
 * 字根/文字, etc). `options` is an array of strings or {label,value}.
 */
export function SegmentedControl({ options = [], value, onChange, style = {}, ...rest }) {
  const opts = options.map((o) => (typeof o === "string" ? { label: o, value: o } : o));
  const active = value ?? opts[0]?.value;
  return (
    <div
      style={{
        display: "inline-flex",
        padding: 2,
        gap: 2,
        background: "rgba(120,120,128,0.12)",
        borderRadius: 9,
        fontFamily: "var(--font-sans)",
        ...style,
      }}
      {...rest}
    >
      {opts.map((o) => {
        const on = o.value === active;
        return (
          <button
            key={o.value}
            type="button"
            onClick={() => onChange && onChange(o.value)}
            style={{
              flex: 1,
              padding: "6px 16px",
              fontSize: 13,
              fontWeight: on ? 600 : 500,
              color: "var(--text-primary)",
              background: on ? "#fff" : "transparent",
              border: "none",
              borderRadius: 7,
              boxShadow: on ? "0 1px 3px rgba(0,0,0,0.12), 0 1px 0.5px rgba(0,0,0,0.04)" : "none",
              cursor: "pointer",
              transition: "background .18s ease, box-shadow .18s ease",
              whiteSpace: "nowrap",
              WebkitTapHighlightColor: "transparent",
            }}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
