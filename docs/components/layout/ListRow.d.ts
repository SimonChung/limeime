import * as React from "react";

export interface ListRowProps {
  /** Leading icon node, shown in a rounded color tile. */
  icon?: React.ReactNode;
  /** Tile background color (defaults to brand green). */
  iconColor?: string;
  title?: React.ReactNode;
  subtitle?: React.ReactNode;
  /** Right-aligned secondary value text. */
  value?: React.ReactNode;
  /** Arbitrary trailing node (a Switch, Stepper, etc). */
  trailing?: React.ReactNode;
  /** Show a disclosure chevron. */
  chevron?: boolean;
  /** Render the title in destructive red. */
  destructive?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}

/**
 * A single row inside a ListGroup. Compose it with Switch / Stepper in the
 * trailing slot, a value string for picker-style rows, or `chevron` for
 * drill-down navigation rows.
 */
export declare function ListRow(props: ListRowProps): JSX.Element;
