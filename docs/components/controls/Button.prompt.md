Filled/bordered/plain/destructive buttons in the LIME brand — use for any tappable action in a settings screen.

```jsx
<Button variant="prominent" size="large">前往設定</Button>
<Button variant="bordered">選用萊姆輸入法</Button>
<Button destructive>移除輸入法</Button>
```

- `variant`: `prominent` (filled brand green, the one primary CTA), `bordered` (12%-tinted fill), `plain` (text-only).
- `destructive` recolors any variant red — for 移除 / 還原 / 刪除.
- `size`: `large` (full-screen CTA), `regular`, `small`. `fullWidth` stretches to container.
