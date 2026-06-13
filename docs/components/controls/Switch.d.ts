import * as React from "react";

export interface SwitchProps {
  checked?: boolean;
  disabled?: boolean;
  onChange?: (next: boolean) => void;
  style?: React.CSSProperties;
}

/**
 * The LIME toggle. Identical geometry to the iOS Settings switch with the
 * LIME-green (#4CAF50) ON track — used for every boolean preference and the
 * per-IM enable control.
 *
 * @startingPoint section="Controls" subtitle="iOS toggle with LIME-green track" viewport="700x120"
 */
export declare function Switch(props: SwitchProps): JSX.Element;
