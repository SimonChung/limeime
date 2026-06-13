import * as React from "react";

export interface SegmentOption {
  label: string;
  value: string;
}

export interface SegmentedControlProps {
  /** Strings, or {label,value} pairs. */
  options?: (string | SegmentOption)[];
  value?: string;
  onChange?: (value: string) => void;
  style?: React.CSSProperties;
}

/**
 * iOS segmented picker in the LIME settings vocabulary — single-choice among
 * 2–4 short options (簡繁轉換, 字根/文字 search mode).
 */
export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;
