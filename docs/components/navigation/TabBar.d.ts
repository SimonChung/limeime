import * as React from "react";

export interface TabBarItem {
  key: string;
  label: string;
  icon: React.ReactNode;
}

export interface TabBarProps {
  items?: TabBarItem[];
  active?: string;
  onChange?: (key: string) => void;
  style?: React.CSSProperties;
}

/**
 * The translucent iOS bottom tab bar for the LIME settings app — the four roots
 * 設定 / 輸入法 / 喜好設定 / 資料庫. Active tab tints brand green.
 *
 * @startingPoint section="Navigation" subtitle="iOS bottom tab bar (4 tabs)" viewport="700x110"
 */
export declare function TabBar(props: TabBarProps): JSX.Element;
