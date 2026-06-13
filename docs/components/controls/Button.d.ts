import * as React from "react";

export interface ButtonProps {
  /** Visual style. `prominent` = filled brand green (primary CTA). */
  variant?: "prominent" | "bordered" | "plain";
  size?: "large" | "regular" | "small";
  /** Render in destructive red (e.g. 移除輸入法 / 還原). */
  destructive?: boolean;
  fullWidth?: boolean;
  disabled?: boolean;
  /** Optional leading icon node (an SF-Symbol-equivalent SVG). */
  icon?: React.ReactNode;
  children?: React.ReactNode;
  style?: React.CSSProperties;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
}

/**
 * The LIME settings button. Use `prominent` for the single primary action on a
 * screen (前往設定, 確認新增), `bordered` for secondary actions, `plain` for
 * inline text actions, and `destructive` for irreversible operations.
 *
 * @startingPoint section="Controls" subtitle="iOS-HIG buttons in the LIME brand" viewport="700x200"
 */
export declare function Button(props: ButtonProps): JSX.Element;
