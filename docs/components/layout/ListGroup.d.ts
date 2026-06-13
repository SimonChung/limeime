import * as React from "react";

export interface ListGroupProps {
  /** Uppercase footnote header above the card (e.g. 鍵盤外觀). */
  header?: React.ReactNode;
  /** Footnote help text below the card. */
  footer?: React.ReactNode;
  /** Inset the header/footer text to the 20pt title column. */
  inset?: boolean;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

/**
 * An iOS grouped form section in the LIME settings style: optional uppercase
 * header, a rounded white card that hairline-separates its ListRow children,
 * and an optional footer. The backbone of every LIME preferences screen.
 *
 * @startingPoint section="Layout" subtitle="iOS grouped form section" viewport="700x260"
 */
export declare function ListGroup(props: ListGroupProps): JSX.Element;
