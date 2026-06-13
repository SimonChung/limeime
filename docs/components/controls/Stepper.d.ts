import * as React from "react";

export interface StepperProps {
  value?: number;
  min?: number;
  max?: number;
  onChange?: (value: number) => void;
  style?: React.CSSProperties;
}

/**
 * The 分數 (score) stepper from the LIME row editors: round −/＋ buttons around
 * a directly-editable numeric field, clamped to [min, max] (default 0…9999).
 */
export declare function Stepper(props: StepperProps): JSX.Element;
