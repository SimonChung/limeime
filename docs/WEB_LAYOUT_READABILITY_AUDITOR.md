# Web Layout and Readability Auditor

This auditor checks how the Markdown manual reads after rendering as a web page.

## Pass Standard

- Each page has exactly one `#` heading.
- Heading hierarchy is logical.
- Long procedures use numbered lists.
- Screenshots have meaningful alt text.
- Warning blocks are visually separate from ordinary prose.
- Tables are used only when comparison is clearer than prose.
- Mobile readers do not need horizontal scrolling for normal content.

## Reject If

- A paragraph contains multiple operations and exceeds five rendered lines.
- A table is dense, wide, or used only for layout.
- Images have missing or filename-only alt text.
- Screenshot, instruction, and success state appear in an illogical order.
- The page reads like notes rather than a manual page.
