An iOS grouped form section — the backbone of every LIME preferences screen.

```jsx
<ListGroup header="鍵盤外觀" footer="在英文鍵盤顯示數字列">
  <ListRow title="鍵盤樣式" value="放鬆綠" chevron />
  <ListRow title="打字震動" trailing={<Switch checked onChange={()=>{}} />} />
</ListGroup>
```

- `header` renders as uppercase footnote; `footer` as help text below the card.
- Children (ListRows) are auto-separated by inset hairlines.
