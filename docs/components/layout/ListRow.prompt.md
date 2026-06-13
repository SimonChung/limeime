A versatile grouped-list row: leading icon tile, title + subtitle, trailing slot.

```jsx
<ListRow icon={<Icon/>} title="管理輸入法" subtitle="13 種輸入法" chevron onClick={...} />
<ListRow title="打字音效" trailing={<Switch checked={false} onChange={...} />} />
<ListRow title="移除輸入法" destructive />
```

- `value` = right-aligned grey text (picker rows). `trailing` = arbitrary node (Switch/Stepper).
- `chevron` adds a disclosure arrow; `destructive` colors the title red.
- `iconColor` sets the rounded tile color (defaults to brand green).
