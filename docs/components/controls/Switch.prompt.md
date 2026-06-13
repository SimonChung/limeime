The LIME-green iOS toggle — every boolean preference and the per-IM enable control.

```jsx
const [on, setOn] = React.useState(true);
<Switch checked={on} onChange={setOn} />
```

- Controlled: pass `checked` + `onChange(next)`.
- ON track is LIME green (#4CAF50); thumb is white. `disabled` dims it.
- Pair inside a `ListRow` via the `trailing` slot.
