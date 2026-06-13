The translucent iOS bottom tab bar for the 4-tab LIME settings app.

```jsx
const [tab, setTab] = React.useState("setup");
<TabBar active={tab} onChange={setTab} items={[
  { key:"setup", label:"設定", icon:<Gear/> },
  { key:"im", label:"輸入法", icon:<List/> },
  { key:"prefs", label:"喜好設定", icon:<Sliders/> },
  { key:"db", label:"資料庫", icon:<Archive/> },
]} />
```

- Active tab tints brand green; others use secondary label grey.
- Pin to the bottom of a device frame; it provides its own blur + hairline.
