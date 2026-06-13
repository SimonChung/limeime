iOS segmented picker for 2–4 short single-choice options (簡繁轉換, 字根/文字 search mode).

```jsx
const [m, setM] = React.useState("無");
<SegmentedControl options={["無","繁轉簡","簡轉繁"]} value={m} onChange={setM} />
```

- `options` accepts strings or `{label, value}` pairs.
- The selected segment gets the white floating pill; others are transparent.
