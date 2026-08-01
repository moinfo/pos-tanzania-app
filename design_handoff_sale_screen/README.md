# Handoff: Sale Screen Redesign (Flutter POS)

## Overview
A redesign of the **Sale (POS) screen** of an existing Flutter point-of-sale app used by
distributors/shops in Tanzania (TSh currency, Swahili-speaking sellers, English UI copy).

The current screen was reported as too complicated: cart area too small and requiring
scrolling inside a scroll area, an intrusive payment dialog, and too much chrome
(store selector, "Sheet" button, cart, search, payments, bottom tabs all competing).

The redesign:
- Moves the **store selector into the app bar** (tap the store name to switch).
- **Removes the "Sheet" button** from the sale screen entirely (the whole secondary bar is gone).
- Makes the **cart the screen** — it owns all remaining vertical space; search is pinned above it.
- Replaces the **payment dialog with a bottom sheet** (amount + numeric keypad + method chips + one confirm button). Split / partial payments are supported.
- Adds a **numeric keypad bottom sheet for quantity** with presets 1 / 5 / 10 / 25 / 50 (sellers usually type 10, 25, 50).
- Adds an **order-level discount** (TSh amount or percent) reachable from the totals block.
- Makes **customer selection required** — an amber prompt sits at the top until one is chosen.

## About the Design Files
The files in this bundle are **design references created in HTML** — a working prototype showing
intended look and behaviour. They are **not production code to copy**.

The task is to **recreate this design inside the existing Flutter app**, using its established
patterns: existing widgets, theme, state management (Provider/Bloc/Riverpod — whatever the app
already uses), repositories and API calls. Do not introduce a new architecture. Only the
**visual design, layout, hierarchy and interaction model** should be taken from the prototype.

Open `Leruma Sale.dc.html` in a browser to interact with the prototype (search items, edit
quantity, apply a discount, take a payment, complete a sale).

## Fidelity
**High fidelity.** Colors, typography, spacing, radii, and interactions below are final and
should be matched closely. Where the existing Flutter app already has a theme token that is
within a hair of a value here, prefer the app's token.

Note: the prototype is framed in an iPhone bezel for presentation only. The app is Flutter
(Android-first). Ignore the bezel, the iOS status bar and the home indicator — use Flutter's
`SafeArea`. The bottom navigation bar shown is the app's existing one, reproduced for context;
do not rebuild it, just keep it.

---

## Screens / Views

### 1. Sale screen (main)
**Purpose:** the seller picks a customer, adds items, adjusts quantities, optionally discounts,
then charges.

**Layout** — a single vertical `Column`, top to bottom, no nested scroll views except the one
list in the middle:

| Region | Height | Notes |
|---|---|---|
| App bar | content + status bar | fixed |
| Context block (customer + search) | content | fixed, white, sits under app bar |
| Item list / cart | `Expanded` | the only scrollable region |
| Totals + actions | content | fixed footer, white, top shadow |
| Bottom navigation | content | existing app nav |

Page background: `#F4F6F9`.

#### 1a. App bar
- Background `#0A3F8F`. Padding `11px` bottom, `12px` horizontal; top padding = status bar height.
- Left: hamburger icon button, 36×36, three 2px white bars, 4px gap, 8px horizontal inset.
- Center: **store name** button, flex 1. Text `ANZWARI MVUNGI` — 14px / weight 700 / white /
  letter-spacing 0.6px / uppercase, ellipsised. Followed by a 12px chevron-down at
  `rgba(255,255,255,.8)`. Tapping opens the store switcher.
- Right: theme (moon) icon button, 36×36, white 19px glyph.
- A 1px inset top highlight `rgba(255,255,255,.14)`.

#### 1b. Customer row
White surface, `10px 12px` padding, `9px` gap between the customer row and the search field,
bottom shadow `0 1px 0 rgba(15,23,42,.06)`.

Two states:
- **Selected** — background `#F1F5FB`, radius 11px, padding `8px 10px`.
  - Avatar 28×28, radius 9px, `#0B5FD1`, white initial, 13px/700.
  - Name 14px/700 `#0F172A`, ellipsised. Phone 11px/500 `#7A8699`.
  - Trailing "Change" chip: 11px/700 `#0B5FD1` on white, radius 7px, padding `4px 8px`.
  - Pressed: background `#E4EDFA`.
- **Empty (required)** — background `#FFF6E7`, 1px border `#F1C97C`, radius 11px, padding `9px 10px`.
  - Person-plus icon `#C4820E`, label "Select customer to start" 14px/700 `#B4770B`, chevron right.
  - Pressed: `#FDEECF`.
  - **The Charge button must be blocked while no customer is selected** (customer is mandatory).

#### 1c. Search field
Height 46px, background `#F4F6F9`, 1.5px border `#E2E8F1`, radius 12px, horizontal padding 10px.
- Leading 18px magnifier `#8A94A6`.
- Input 15px/600 `#0F172A`; placeholder `Search item or scan barcode`.
- Trailing: barcode-scan icon `#0B5FD1` when empty; a 26×26 clear button (`#E2E8F1`, radius 8px)
  when there is text.
- Typing filters the item catalogue by name (case-insensitive `contains`). Searching is the
  primary way to find items — this is what sellers said they use.

#### 1d. Search results (shown while the query is non-empty, replaces the cart view)
Padding `10px 12px 16px`, 8px gap between cards.
Each result: white card, radius 12px, padding 12px, shadow `0 1px 2px rgba(15,23,42,.06)`.
- Name 15px/700; meta line 12px/600 `#7A8699` — `Stock {n} · {store}`.
- Price 15px/800 `#0B5FD1`.
- Trailing 32×32 blue (`#0B5FD1`) radius-10 add button with a white plus.
- Tapping the card adds qty 1 (or increments an existing line) and **clears the query**.
- Pressed: `#F1F5FB`.
Empty result: centered 14px/600 `#8A94A6` — "No item matches that name or barcode".

#### 1e. Cart (shown when query is empty and the cart is not empty)
Padding `12px 12px 18px`.
- Header row: `{n} ITEM(S) IN CART` — 11px/800, letter-spacing 1.1px, `#8A94A6`;
  right "CLEAR" — 11px/800 `#D14343` (clears cart, payments and discount).
- Card: white, radius 16px, shadows `0 1px 2px rgba(15,23,42,.06), 0 6px 16px rgba(15,23,42,.04)`.
- Each line: padding `11px 12px`, 1px bottom divider `#F1F4F8`, 10px gaps.
  - Name 14.5px/700, ellipsised; sub-line `{qty} × {unitPrice} TSh` 12px/600 `#7A8699`.
  - **Quantity pill** (tap → quantity sheet): height 44px, padding `0 11px`, background `#EFF4FB`,
    1.5px border `#D5E3F7`, radius 11px, number 16px/800 `#0B5FD1` (min-width 22px, centered),
    plus a 13px pencil glyph. Pressed `#E0EBFA`.
  - Line total: width 70px, right-aligned, 15px/800, tabular numerals.
  - Remove: 44×44 tap target (visually a 13px grey ✕ `#C3CBD8`), `margin-right:-10px` so the
    glyph still sits at the card edge. In Flutter use a 44×44 `IconButton` with a negative
    right padding equivalent.
- Below the cart, if any payments were already taken, a second white card (radius 14px) lists
  them: green check chip, method label 14px/700, amount 14px/800 `#16A34A`, and a ✕ to void.

#### 1f. Empty cart state
Centered, padding `56px 34px`: 46px outlined cart glyph `#C9D2DE`, then
"Search an item above to start this sale" 14.5px/700 `#8A94A6`, line-height 1.5.
Below it a wrapping row of **quick-add chips** (top 4 catalogue items): white, 1.5px `#E2E8F1`
border, radius 999px, padding `8px 13px`, name 13px/700 (no wrap) + price 13px/700 `#0B5FD1`.

#### 1g. Totals + actions footer
White, 1px top border `#E6EAF0`, shadow `0 -6px 18px rgba(15,23,42,.05)`, padding `9px 12px 10px`.
1. **Subtotal** row — label 12.5px/600 `#8A94A6`, value 13.5px/700 `#475569`.
2. **Discount** row (a button; opens the discount sheet) — 14px tag icon + label 12.5px/700
   `#0B5FD1`: "Add discount" when none, "Discount" or "Discount {p}%" when set.
   Value: `— ` in `#C3CBD8` when none, `− {amount}` in `#D14343` when set.
3. 1px dashed `#E2E8F1` separator, then **Total** (or "Balance due" once part-paid) —
   label 12.5px/700 `#7A8699`, amount 25px/800, letter-spacing −0.6px.
4. Action row, 9px gap:
   - **Suspend** — 52×52, radius 14px, 1.5px `#F1C97C` border on `#FFFBF3`, pause glyph `#C4820E`.
   - **Charge** — expanded, height 52, radius 14, `#0B5FD1`, white card glyph +
     `Charge {amountDue}` 16px/800; shadow `0 6px 14px rgba(11,95,209,.28)`; pressed `#0A52B4`.
     When the balance is already covered the label becomes `Complete sale`.

#### 1h. Bottom navigation (existing)
5 items — Reports, Home, **Sale** (active), Summary, Seller. Icon 19–20px, label 10.5px/700.
Inactive `#94A0B0`, active `#0B5FD1` (label weight 800). Top border `#EEF1F5`.

---

### 2. Quantity sheet (bottom sheet)
Opened by tapping a cart line's quantity pill.
White, radius `24px 24px 0 0`, padding `10px 14px 30px`, shadow `0 -8px 30px rgba(15,23,42,.2)`.
Grabber 38×4, radius 4, `#E2E8F1`, 12px bottom margin. Scrim `rgba(15,23,42,.45)` (tap to close).
Enter animation: translateY 100%→0, 240ms, `cubic-bezier(.2,.8,.3,1)`.

- Header: left `QUANTITY` 11px/800 ls 1px `#8A94A6` + item name 16px/800 ellipsised;
  right the live value 34px/800, ls −1px, `#0B5FD1`.
- Preset row: `1 5 10 25 50`, each flex-1, height 38, radius 10, `#F1F5FB`, 14px/800 `#0B5FD1`,
  pressed `#DEEAFA`. Tapping a preset **sets** the quantity.
- Keypad: 3-column grid, 8px gap, keys `1..9, 00, 0, ⌫`, each height 52, radius 12,
  `#F4F6F9`, 21px/700, pressed `#E4EAF2`. Digits append (max 9 chars), `⌫` deletes one.
- "Done" — full width, height 52, radius 14, `#0B5FD1`, white 16px/800. Closes the sheet.
- Quantity is applied live as the seller types; minimum 1.

### 3. Discount sheet (bottom sheet)
Opened from the Discount row in the footer. Same shell as the quantity sheet.
- Header: `DISCOUNT` 11px/800 `#8A94A6`, sub-line `Subtotal {n} TSh` 13px/700 `#7A8699`;
  right the live value 32px/800 `#0B5FD1` — `{n}%` in percent mode, formatted amount in TSh mode.
- Mode toggle, two flex-1 buttons, height 40, radius 11, 13.5px/800:
  selected `#E9F1FD` bg / `#0B5FD1` border+text; unselected white / `#E2E8F1` / `#7A8699`.
  Switching modes resets the entered value.
- Presets: `500 1,000 2,000 5,000` in TSh mode, `5% 10% 15% 20%` in percent mode.
  Height 38, radius 10, `#F1F5FB`, 13.5px/800 `#0B5FD1`.
- Same 3×4 keypad as above (height 50).
- Footer: "Remove" (96×52, radius 14, `#F1F4F8`, 14.5px/700 `#5A6577`) clears the discount and
  closes; primary button (expanded, 52, `#0B5FD1`) reads `Apply · −{computedAmount}` or "Done".
- Discount is **order-level**, capped at the subtotal, and applies before payments.

### 4. Payment sheet (replaces the old dialog)
Opened by Charge when a balance is due. Same sheet shell.
- Header: `PAYMENT` (or `PART PAYMENT` when payments already exist) + `Due {n} TSh` 13px/700;
  right the amount being entered 32px/800, ls −1px. **Defaults to the full amount due** —
  the common case is one tap to confirm.
- Method chips: `Cash` / `Bank` / `Credit`, flex-1, height 44, radius 12, 13.5px/800, 1.5px border.
  Selected `#E9F1FD` / border `#0B5FD1` / text `#0B5FD1`; unselected white / `#E2E8F1` / `#7A8699`.
  "Credit" = mkopo/deni, booked against the selected customer.
- Same 3×4 keypad (height 50).
- Confirm — full width, height 54, radius 14, `#16A34A`, white 16px/800, check glyph,
  shadow `0 6px 14px rgba(22,163,74,.26)`, pressed `#128040`.
  Label: `Complete · {amount}` when the entry covers the balance, otherwise
  `Add {amount} · {remaining} left`.
- Confirming appends a payment (capped at the balance) and closes the sheet. If the total is now
  covered the sale completes; otherwise the seller stays on the cart with the remaining balance
  and the payment listed under the cart — this is how split payments work.

### 5. Customer sheet
Tall bottom sheet: `top: 120px` to the bottom, radius `24px 24px 0 0`, padding `10px 14px 20px`.
- Title "Customer" 18px/800 + 30×30 close button (`#F1F4F8`, radius 9).
- Search field, height 44, same styling as the item search, placeholder "Search name or phone";
  filters on name **or** phone.
- Scrolling list, 7px gaps: rows padding 10px, radius 12, `#F7F9FC` (pressed `#E9F0FA`),
  34×34 blue avatar w/ initial, name 14.5px/700, phone 12px/600 `#7A8699`,
  trailing `Deni {amount}` 11.5px/700 `#B4770B` when the customer has an outstanding balance.
- Picking a customer closes the sheet.

### 6. Sale complete
Full-screen white overlay **below the app bar's status bar** (z-index under the status bar so the
system bar stays visible), padding `64px 30px 30px`, fade-in 200ms.
- 78×78 circle `#E7F6EE` with a 38px green check `#16A34A`, pop-in 300ms `cubic-bezier(.2,.9,.3,1.4)`.
- "Sale complete" 19px/800; total 32px/800 `#16A34A`, ls −1px;
  sub-line 13.5px/600 `#7A8699` — `{customer} · {n} item(s) · {payment methods joined by " + "}`.
- Buttons, full width, 9px gap: "New sale" (52, `#0B5FD1`, white 16px/800) and
  "Print receipt" (50, `#F1F4F8`, `#334155` 15px/700).

---

## Interactions & Behavior
- **Search → tap → added.** No quantity prompt on add; quantity is edited afterwards on the line.
- **One sheet at a time.** Every secondary action (quantity, discount, payment, customer) is a
  bottom sheet with a scrim; there are **no dialogs**.
- **Charge is a single primary action.** It is disabled/blocked when the cart is empty or no
  customer is selected.
- **Suspend** parks the sale (in the prototype it clears cart, payments, discount and query;
  in the real app it should write a suspended-sale record).
- Animations: sheets slide up 240ms `cubic-bezier(.2,.8,.3,1)`; scrim and success fade 180–200ms;
  success check pops 300ms `cubic-bezier(.2,.9,.3,1.4)`.
- Pressed states are listed per component above; every one of them is a flat colour change,
  no ripple-on-ripple. Flutter: `InkWell` with the listed `highlightColor`, or a
  `GestureDetector` + `AnimatedContainer`.
- **Minimum tap target 44×44** everywhere, including the line remove ✕ and the quantity pill.
- Currency format: thousands-separated with `,`, suffix ` TSh` where shown. Use tabular figures
  for all money columns (`fontFeatures: [FontFeature.tabularFigures()]`).

## State Management
Per-sale state (in the prototype, one component's state; in Flutter, one sale
controller/bloc scoped to the screen):

| State | Type | Notes |
|---|---|---|
| `customer` | Customer? | required before charging |
| `cart` | List<{name, price, qty}> | adding an existing item increments its qty |
| `payments` | List<{label, amount}> | supports multiple (split) payments |
| `discount` | int | raw entered value |
| `discMode` | `'tsh' \| 'pct'` | how `discount` is interpreted |
| `query` | String | item search |
| `custQuery` | String | customer search |
| `sheet` | `null \| 'qty' \| 'discount' \| 'pay' \| 'customer'` | one at a time |
| `qtyIndex` | int? | cart line being edited |
| `qtyBuf` / `payBuf` / `discBuf` | String | keypad buffers |
| `payMethod` | `'cash' \| 'bank' \| 'credit'` | |
| `done` | bool | success overlay |

Derived values:
```
subtotal = Σ price × qty
discountValue = min(discMode == 'pct' ? round(subtotal * discount / 100) : discount, subtotal)
total = max(0, subtotal − discountValue)
paid  = Σ payments.amount
due   = max(0, total − paid)
```
Data the real screen needs: item catalogue for the active store (name, price, stock),
customer list (name, phone, outstanding balance), and endpoints to create a sale, record
payments (including credit), suspend a sale, and print a receipt.

## Design Tokens
**Colors**
| Token | Hex | Use |
|---|---|---|
| Brand blue | `#0B5FD1` | primary actions, accents |
| Brand blue pressed | `#0A52B4` | |
| App bar navy | `#0A3F8F` | app bar |
| Blue tint 1 | `#E9F1FD` | selected chips |
| Blue tint 2 | `#F1F5FB` / `#EFF4FB` | soft fills |
| Blue tint pressed | `#DEEAFA` / `#E0EBFA` / `#E4EDFA` | |
| Blue border | `#D5E3F7` | qty pill border |
| Page background | `#F4F6F9` | |
| Surface | `#FFFFFF` | |
| Surface alt | `#F7F9FC` | list rows in sheets |
| Neutral fill | `#F1F4F8` | secondary buttons |
| Neutral fill pressed | `#E4EAF2` | |
| Border | `#E2E8F1`, `#E6EAF0`, `#EEF1F5`, `#F1F4F8` | |
| Text primary | `#0F172A` | |
| Text secondary | `#475569` | |
| Text muted | `#7A8699` | |
| Text faint | `#8A94A6`, `#94A0B0` | |
| Icon faint | `#C3CBD8`, `#C9D2DE` | |
| Success | `#16A34A` (pressed `#128040`, tint `#E7F6EE`) | payments, completion |
| Danger | `#D14343` | clear, discount amount |
| Warning | `#C4820E` / `#B4770B`, border `#F1C97C`, fills `#FFF6E7` `#FFFBF3` `#FDEECF` | required-customer, suspend, debt |

**Typography** — Plus Jakarta Sans (weights 400/500/600/700/800).
Scale used: 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 16, 18, 19, 21, 23, 25, 32, 34 px.
Uppercase micro-labels use letter-spacing 1–1.1px; large numerals use −0.2 to −1px.
If Plus Jakarta Sans is not already bundled, add it via `google_fonts` or as a bundled asset.

**Spacing** — 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 18, 20, 26, 30, 34, 54 px.
Standard screen gutter: 12px. Standard gap inside cards: 10px.

**Radius** — 7, 8, 9, 10, 11, 12, 14, 16, 24 (sheet top), 999 (chips).

**Shadows**
- Card: `0 1px 2px rgba(15,23,42,.06), 0 6px 16px rgba(15,23,42,.04)`
- Footer: `0 -6px 18px rgba(15,23,42,.05)`
- Sheet: `0 -8px 30px rgba(15,23,42,.2)`
- Primary button: `0 6px 14px rgba(11,95,209,.28)`; success: `0 6px 14px rgba(22,163,74,.26)`

**Heights** — control 44/46, primary button 52–54, quantity pill 44, keypad key 50–52,
preset chip 38–40, sheet grabber 4.

## Assets
No image assets. All icons are inline stroke SVGs (2–3px stroke, round caps) drawn from a
standard outline set: menu, moon, person-plus, search, barcode-scan, plus, pencil, close,
check, card, pause, tag/percent, cart, chart-bars, home, document, user.
Map them to the icon set the Flutter app already uses (`Icons.*` / a bundled set) rather than
importing new SVGs — match weight and size, not exact path.

## Files
| File | What it is |
|---|---|
| `Leruma Sale.dc.html` | The design. Open in a browser; it is fully interactive. |
| `ios-frame.jsx` | Presentation-only iPhone bezel. Not part of the design. |
| `support.js` | Runtime for the prototype. Not part of the design. |

Sample data in the prototype (catalogue and customers) is illustrative only —
wire the real screen to the app's existing data sources.
