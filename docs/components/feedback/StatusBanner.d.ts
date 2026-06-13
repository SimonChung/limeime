import * as React from "react";

export interface StatusBannerProps {
  status?: "success" | "warning" | "danger";
  /** Override the default status glyph. */
  icon?: React.ReactNode;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

/**
 * The keyboard-activation status banner (萊姆輸入法已啟用 / 尚未啟用…). Color is
 * carried by the icon + text over a subtle tint, matching SetupTabView §4.2.
 *
 * @startingPoint section="Feedback" subtitle="Color-coded setup status banner" viewport="700x130"
 */
export declare function StatusBanner(props: StatusBannerProps): JSX.Element;
