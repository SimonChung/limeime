The 分數 (score) stepper from the LIME record/related row editors.

```jsx
const [score, setScore] = React.useState(0);
<Stepper value={score} min={0} max={9999} onChange={setScore} />
```

- Round −/＋ buttons (brand-green glyphs) flank a directly-editable numeric field.
- Values clamp to `[min, max]`; non-numeric input resets to 0.
