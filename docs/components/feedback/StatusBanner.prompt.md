The keyboard-activation status banner from the 設定 tab.

```jsx
<StatusBanner status="success">萊姆輸入法已啟用</StatusBanner>
<StatusBanner status="warning">鍵盤已啟用，但尚未允許完整取用</StatusBanner>
<StatusBanner status="danger">尚未啟用萊姆輸入法鍵盤</StatusBanner>
```

- `status` drives the glyph + text color over a subtle matching tint.
- Pass `icon` to override the default check/warning/x glyph.
