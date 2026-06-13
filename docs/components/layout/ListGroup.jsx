import React from "react";

/**
 * LIME ListGroup — an iOS grouped form section: optional uppercase footnote
 * header, a rounded card holding ListRows (auto-separated), optional footer.
 */
export function ListGroup({ header, footer, children, inset = true, style = {}, ...rest }) {
  const rows = React.Children.toArray(children).filter(Boolean);
  return (
    <section style={{ fontFamily: "var(--font-sans)", ...style }} {...rest}>
      {header && (
        <div
          style={{
            font: "var(--weight-regular) 13px/18px var(--font-sans)",
            color: "var(--text-secondary)",
            textTransform: "uppercase",
            letterSpacing: "0.3px",
            padding: `0 ${inset ? 20 : 4}px 6px`,
          }}
        >
          {header}
        </div>
      )}
      <div
        style={{
          background: "var(--surface)",
          borderRadius: "var(--radius-card)",
          overflow: "hidden",
        }}
      >
        {rows.map((row, i) => (
          <React.Fragment key={i}>
            {row}
            {i < rows.length - 1 && (
              <div style={{ height: 0.5, background: "var(--separator)", marginLeft: 16 }} />
            )}
          </React.Fragment>
        ))}
      </div>
      {footer && (
        <div
          style={{
            font: "var(--weight-regular) 13px/18px var(--font-sans)",
            color: "var(--text-secondary)",
            padding: `6px ${inset ? 20 : 4}px 0`,
          }}
        >
          {footer}
        </div>
      )}
    </section>
  );
}
