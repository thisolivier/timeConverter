# Widget design brief — breakpoints (item 36b, filed 2026-11-04)

Olivier's notes for the widget design pass, ahead of the designs. Not yet
started. The shipped MVP (item 36) is one large size per platform with a
fixed list; this replaces that with layouts chosen by city count and
typography sized by available space.

## Breakpoints

Use city count to choose the layout, then available space to size the
typography.

| Widget | 1–3 cities | 4 cities | 5–6 cities |
|---|---|---|---|
| Small | One city fills the widget; two or three use full-width rows. | 2 × 2 grid. | 2 columns × 3 rows. Short city labels; omit offsets. |
| Medium | One, two, or three columns across a single row. | 2 × 2 grid. | 3 columns × 2 rows. Shorten or omit offsets. |
| Large | One hero clock, then two or three generous full-width rows. | 2 × 2 grid. | 2 columns × 3 rows. Retain full names and offsets where they fit. |

## Compression order

When a cell does not fit, compress in this order:

1. Reduce surplus padding and gaps.
2. Shorten offsets: "8 hours behind" → "8h behind".
3. Use recognisable short city names or codes.
4. Hide offset captions.
5. Reduce time numerals last, consistently across every cell.

For five cities, let the last city span the remaining row space. Keep the
user's ordering consistent across sizes.

## Numerals

Use a shared numeral size based on the widest time, so cells don't resize as
the clock changes. If the user chooses 12-hour display, reserve space for the
smaller AM/PM rather than switching formats automatically.

## Already decided

- The widget does not show the device's local time (the home screen has a
  clock). Noted 2026-11-04, not yet applied to the MVP; see backlog item 36.
