# Handoff: Dashboard, Side Menu & Customer Credit (Flutter POS)

## Overview
Redesigns of four screens of the existing Flutter POS app used by Leruma Distribution Centre
(Tanzania, TSh, English UI):

**`Leruma Home.dc.html`**
1. **Home / Dashboard** — replaces the four saturated colour tiles, the standalone "Welcome Back"
   card and the two long stacked commission lists.
2. **Side menu (drawer)** — replaces the flat 12-item list with grouped, scannable sections.

**`Leruma Credit.dc.html`** (one file, four views, wired together)
3. **Credit & debt** — supervisor list, and the drill-down to that supervisor's **customers**.
4. **Customer statement** — balances, period, transactions, and the record-payment sheet.
5. **Debt collection** — period totals and payment history.

Both files are interactive: open them in a browser and click through
(hamburger → drawer; supervisor row → customers; customer row → statement; "Record payment" →
payment sheet; "Daily debt collection" → collection screen). Recording a payment updates every
level live.

## About the Design Files
These are **design references built in HTML**, not production code to copy. Recreate the design
inside the existing Flutter app using its established patterns — existing widgets, theme, state
management, repositories and API calls. Take only the **visual design, layout, hierarchy and
interaction model** from the prototypes.

The iPhone bezel, iOS status bar and home indicator are presentation only. The app is Flutter,
Android-first — use `SafeArea`.

## Fidelity
**High fidelity.** Colours, type, spacing, radii and interactions below are final. Prefer an
existing app token when it is within a hair of a value here.

## ⚠ Sample data — do not ship
The prototypes contain figures that are **not** from the client's data. Wire everything to the
real API; the numbers below exist only so the layouts can be judged with content.

Real (taken from the client's screenshots):
- Total credit **205,638,700**, total paid **192,976,700**, balance **12,662,000**
- Supervisor **Apolinali Apolinali Mpinga**, 677036711
- Customers **Mija (sembe) Mapinga** 693176005 (22,270,500 / 19,370,500) and
  **Ngosha Kerege** 756545800 (47,747,500 / 44,857,500)
- Debt collection for 01–31 Aug 2026: **0 payments**
- 130 total customers, 128 shops served, 1 served today, 0 disciplinary cases

Invented for the mock — replace or delete:
- Dashboard: the 7-day bar chart, "6.4% vs last week", "Collected 4.21M / Outstanding 8.45M",
  and the chips "+4", "98%", "+0.8%", "Clean"
- Dashboard: every commission figure (targets, averages, percentages, amounts) — the client's
  real data is all zeros
- Credit: customers **Amadoni Shop**, **Gody Shop Mbezi**, **Amani Shop** and their amounts
  (their totals were chosen to add up to the supervisor's real totals)
- Drawer: the "3" badge on Receivings

---

# Screen 1 — Home / Dashboard

Page background `#F2F5F9`. Column: app bar (fixed) → scrolling body → bottom nav (fixed).

### 1.1 App bar
Background `#103863`, padding `54px 14px 14px` (top = status bar), row, gap 11.
- **Hamburger** — 40×40, radius 12, `rgba(255,255,255,.12)` (pressed `.22`), three 2px white bars,
  4px gap, 10px horizontal inset. Opens the drawer.
- **Centre block** — kicker `SELLER` 11px/700/ls .8px `rgba(255,255,255,.6)`;
  name "Apolinar Mpinga" 16px/800/ls −.2px white, ellipsised.
  (This replaces the separate "Welcome Back" card — do not reinstate it.)
- **Theme toggle** — 40×40, same fill, 18px white moon.

### 1.2 Primary KPI card
White, radius 20, padding 15/16, shadow `0 1px 2px rgba(16,56,99,.05), 0 8px 22px rgba(16,56,99,.07)`,
inset 14px from the screen edges, 14px below the app bar.
- Header row: `TOTAL CREDITS` 11.5px/800/ls 1px `#6B7684`; right a **date chip** —
  `#F1F5FB`, radius 999, padding `6px 11px`, 13px calendar glyph `#1D7DC4` + date 12px/800
  `#1D7DC4`, `nowrap`. Pressed `#E4EDFA`. Opens a date picker.
- Amount: **12.66M** 34px/800/ls −1.4px `#103863`, with a `TSh` suffix 14px/700 `#6B7684`.
- **7-day bar chart** — row of 7 flex-1 columns, 5px gap, 60px tall, bars bottom-aligned,
  radius `5px 5px 2px 2px`, height = `10 + value*0.6` px.
  Past days `#D3E2F0`; today `#1D7DC4`. Under it a row of day letters
  (M T W T F S S) 10px/700 `#6B7684`, today `#1668A6` 800.
- **Split row** — two flex-1 blocks, `#F5F8FC`, radius 12, padding `9px 11px`:
  `COLLECTED` 11px/800/ls .6px `#6B7684` over the value 15px/800 `#12833C`;
  `OUTSTANDING` over 15px/800 `#103863`.
- **Footer** — 1px `#F1F4F8` top rule; left a delta chip (`#E7F6EE`, radius 7, up-arrow +
  percentage 11.5px/800 `#12833C`) then "vs last week" 12px/600 `#64748B` `nowrap`;
  right "Details" 12.5px/800 `#1668A6`.

### 1.3 Quick actions
Three-column grid, 9px gap, 12px above the stat grid. Each: white card, radius 16,
padding `13px 8px`, same card shadow, pressed `#F1F5FB`. Inside, centred:
a 38×38 radius-13 tinted square with an 18px glyph, then the label 12px/800 `#103863`.
- **New sale** — cart glyph, `#1668A6` on `#EAF3FB`
- **Add customer** — people glyph, `#12833C` on `#E7F6EE`
- **Collect debt** — bank glyph, `#8A5F0B` on `#FDF1DC`

### 1.4 Stat grid
Two-column grid, 10px gap. Each card: white, radius 16, padding 13, card shadow.
- Top row: 34×34 radius-11 tinted square with a 16px glyph; right a delta chip
  11px/800, radius 7, padding `3px 7px`.
- Value 24px/800/ls −.7px `#103863`; label 12.5px/600 `#5C6675`.

| Card | Value | Label | Icon / tint | Chip |
|---|---|---|---|---|
| Customers | 130 | Total customers | people, `#1D7DC4` on `#EAF3FB` | `+4` `#12833C` on `#E7F6EE` |
| Shops | 128 | Shops served | store, `#7A57C9` on `#F0EBFA` | `98%` `#5E3FA8` on `#F0EBFA` |
| Today | 1 | Served today | cart, `#16A34A` on `#E7F6EE` | `+0.8%` `#12833C` on `#E7F6EE` |
| Discipline | 0 | Disciplinary cases | shield, `#5A6577` on `#EEF1F5` | `Clean` `#4A5462` on `#EEF1F5` |

**Semantic colour rule:** red is reserved for real problems. "Shops served" must not be red, and
credit totals are navy, not red.

### 1.5 Commissions
Header row: "Commissions" 16.5px/800/ls −.3px `#103863`; right the period 12px/700 `#64748B`.

**Segmented control** — this replaces the two separate stacked sections
("Muhidini Haji Commissions" and "Team Commission"). Track `#EAEFF5`, radius 13, padding 4.
Two flex-1 buttons, height 38, radius 10, 13.5px/800, `nowrap`.
Selected: white, `#103863`, shadow `0 2px 6px rgba(16,56,99,.12)`. Unselected: transparent, `#64748B`.
Tabs: **My commission** / **Team**. Switching swaps the level rows below.

**Level rows** — one white card, radius 18, padding `4px 14px`, card shadow; each row
padding `14px 0` with a 1px `#F1F4F8` divider, pressed 65% opacity:
- 36×36 radius-12 level badge with the Roman numeral 13px/800/ls .4px.
- Name 14.5px/800 `#103863`; sub-line 12px/600 `#64748B`
  (My: "Target 4.0M · avg 3.1M"; Team: "104 / 130 customers").
- Right: amount 15px/800 and a caption 11px/700 `#6B7684` ("commission" / "net" / "not reached").
- Chevron 15px `#9AA5B4`.
- Progress row: 7px track `#EEF2F7` radius 5 with a filled bar, then the percentage
  12px/800 `#475569`, min-width 38, right-aligned.

Level tones:

| Level | Badge bg / fg | Bar | Amount |
|---|---|---|---|
| I | `#E7F6EE` / `#12833C` | `#16A34A` | `#12833C` |
| II | `#FDF1DC` / `#8A5F0B` | `#E5A227` | `#103863` |
| III | `#EAF3FB` / `#1668A6` | `#1D7DC4` | `#6B7684` (unreached) |

### 1.6 Discipline banner
`#FFF8EC`, 1px `#F3DDB4`, radius 16, padding 13. 34×34 radius-11 `#FBEDD2` square with a 17px
warning glyph `#C4820E`; title 13.5px/800 `#8A5F0B`; sub-line 12px/600 `#8A5F0B`.
Shown when there are no cases; switch to the danger palette when there are.

### 1.7 Bottom navigation
White, 1px `#EEF1F5` top border, 5 equal columns, padding `7px 0 26px`.
20px glyph + 10.5px label. Inactive `#64748B`/700, active `#1668A6`/800.
Items: Seller · Home (active) · Sales · Customers · Reports.

---

# Screen 2 — Side menu (drawer)

Scrim `rgba(4,26,61,.45)`, fade 180ms, tap to dismiss.
Panel: 300px wide, full height, `#F7F9FC`, slide-in 240ms `cubic-bezier(.2,.8,.3,1)`,
shadow `8px 0 30px rgba(4,26,61,.25)`.

- **Header** — `#103863`, padding `52px 16px 16px`. 46×46 radius-15 `#1D7DC4` avatar with the
  initials 16px/800 white; name 15.5px/800 white; role "Seller · Leruma" 11.5px/700
  `rgba(255,255,255,.6)`; 32×32 close button `rgba(255,255,255,.14)`.
- **Groups** — scrolling, padding `10px 10px 6px`, 12px between groups.
  Group title 10.5px/800/ls 1.1px `#6B7684`, padding `6px 8px`.
  Items: height 46, radius 12, padding `0 10px`, gap 11, 19px glyph, label 14.5px/700 `#334155`,
  pressed `#E9F0F8`. Expandable items get a 14px chevron-down `#B6C0CD`;
  an item may carry a count badge (white 11px/800 on `#D14343`, radius 999).
  **Active item:** fill `#E4EFFA`, icon and label `#1668A6`, label weight 800.

  | Group | Items |
  |---|---|
  | SELL | Sales ⌄, Customers ⌄, Trade |
  | STOCK | Items, Suppliers ⌄, Receivings (badge) |
  | MONEY | Financial Banking, NFC ⌄ |
  | INSIGHTS | Home (active), Seller Report, Reports, Summary |

  Every destination from the current drawer is preserved — only the grouping and order changed.
- **Footer** — pinned, white, 1px `#E7ECF3` top border, padding `8px 10px 28px`:
  **Settings** (19px gear `#5A6577`, label 14.5px/700 `#334155`, pressed `#F1F4F8`) and
  **Logout** (19px logout glyph `#D14343`, label 14.5px/800 `#D14343`, pressed `#FDECEC`).

---

# Screen 3 — Credit & debt (supervisors) and customers drill-down

One screen, two data levels. Page `#F2F5F9`.

### 3.1 App bar
`#103863`, padding `54px 14px 14px`. Back button 40×40 `rgba(255,255,255,.12)`;
kicker + title (kicker 11px/700/ls .8px `rgba(255,255,255,.6)`, title 16px/800 white, ellipsised);
theme toggle 40×40.
- Supervisor level: `CUSTOMER` / "Credit & debt".
- Customer level: `SUPERVISOR` / the supervisor's name; back returns to the supervisor list.
- Statement level: `STATEMENT` / the customer's name; back returns to the customer list.
- Collection level: `DEBT COLLECTION` / the seller's name.

### 3.2 Totals card
White, radius 20, padding 16, big card shadow.
- `OUTSTANDING BALANCE` 11.5px/800/ls 1px `#6B7684`; right a status chip
  (`#FDF1DC`, radius 8, 6px `#C4820E` dot + "N open accounts" 11px/800 `#8A5F0B`).
- Balance 32px/800/ls −1.3px `#103863` + `TSh` 14px/700 `#6B7684`.
  **Not red** — an outstanding balance is normal business, not an error.
- **Collection progress** — "Collected this cycle" 12px/700 `#5C6675`, percentage 12.5px/800
  `#12833C`, then a 9px track `#EEF2F7` radius 6 with a `#16A34A` fill.
  `collected% = paid / credit`.
- **Split row** — `TOTAL CREDIT` block (`#F5F8FC`, radius 13, value `#103863`) and
  `TOTAL PAID` block (`#EEF9F2`, label `#3F7355`, value `#12833C`), labels 10.5px/800/ls .7px.

### 3.3 Daily debt collection card (supervisor level only)
White, radius 18, padding 14, card shadow, pressed `#F1F5FB`.
42×42 radius-14 `#E7F6EE` square with a 20px cash glyph `#12833C`;
title "Daily debt collection" 14.5px/800 `#103863`; sub "All debt payments received today"
12px/600 `#5C6675`; right the amount 14.5px/800 `#12833C` over "today" 10.5px/700 `#6B7684`;
15px chevron `#9AA5B4`. Opens Screen 4.

### 3.4 Search + filters
- Search: white, 1.5px `#E6EBF2`, radius 14, height 48; 18px magnifier `#8A94A6`;
  text 15px/700; placeholder "Search supervisor or phone" / "Search customer or phone";
  28×28 clear button (`#EEF2F7`, radius 9) when filled. Filters on name **or** phone.
- Filter chips: height 36, radius 11, padding `0 13px`, 12.5px/800, `nowrap`, 1.5px border.
  Selected `#103863` fill / white text; unselected white / `#5C6675` / `#E6EBF2`.
  **All · With balance · Settled**.

### 3.5 List
Header: "N SUPERVISORS" / "N CUSTOMERS" 11px/800/ls 1.1px `#6B7684`;
right a sort button (13px sliders glyph + "Highest balance" 11.5px/800 `#1668A6`).

Row card: white, radius 18, padding 14, card shadow, pressed `#F7FAFD`, 10px gap between cards.
- 42×42 radius-14 avatar with initials 15px/800 white — `#1D7DC4` when a balance is open,
  `#12833C` when settled. **Initials must skip non-letter tokens**: "Mija (sembe) Mapinga" → `MM`,
  never `M(`.
- Name 14.5px/800 `#103863`, ellipsised; phone row: 12px handset glyph + 12px/600 `#5C6675`.
- Right: balance 16px/800/ls −.3px (`#103863`, or `#12833C` when zero) over "balance"
  10.5px/700 `#6B7684`.
- Progress row: 7px `#EEF2F7` track with a `#16A34A` fill, percentage 11.5px/800 `#3F7355`,
  min-width 42, right-aligned.
- Footer above a 1px `#F1F4F8` rule: "Credit" (13px/800 `#103863`) and "Paid"
  (13px/800 `#12833C`) with 10.5px/700 `#6B7684` captions, then a CTA chip
  (`#EAF3FB`, radius 9, padding `6px 11px`, 12px/800 `#1668A6` + chevron):
  **Customers** at supervisor level, **Statement** at customer level.
- Tapping a supervisor row opens their customers; tapping a customer row opens the **statement page** (Screen 4).
- Empty result: "No match for that name or phone" 14px/700 `#6B7684`, padding `44px 24px`.

---

# Screen 4 — Customer statement

Reached by tapping a customer row. Page `#F2F5F9`; app bar as 3.1 with the `STATEMENT` kicker.
Column: app bar → scrolling body → **action bar** → bottom nav.

### 4.1 Balances card
White, radius 20, padding 16, big card shadow.
- Row 1: "Balance at period start" 12.5px/700 `#5C6675`, value 14px/800 `#334155`.
  Derived as `currentBalance − periodMovement` (payments inside the period count negative), so it
  changes with the period preset. **It must not simply repeat the current balance.**
- Below a 1px `#F1F4F8` rule: `CURRENT BALANCE` 11.5px/800/ls 1px `#6B7684` with a status
  sub-line 12px/600 `#5C6675` ("Outstanding · 87% collected" / "Fully settled");
  right the amount 27px/800/ls −1.1px `#103863` + `TSh` 13px/700 `#6B7684`.
- Split row: `CREDIT GIVEN` (`#F5F8FC`, value `#103863`) and `PAID` (`#EEF9F2`,
  label `#3F7355`, value `#12833C`), radius 13, padding `10px 12px`.

### 4.2 Period row + presets
Row: 14px calendar glyph `#1668A6` + the resolved range 12.5px/700 `#334155` `nowrap`;
right a **Refresh** button (14px refresh glyph + 12.5px/800 `#1668A6`).
Below, three flex-1 preset buttons — **Today · This week · This month** — height 38, radius 11,
12.5px/800, selected `#103863`/white, unselected white/`#5C6675`/border `#E6EBF2`.

### 4.3 Transactions
- **Empty:** white card, radius 20, padding `34px 24px`, centred — 60×60 radius-20 `#F1F5FB`
  square with a 28px receipt glyph `#9AA5B4`; "No transactions in this period" 15px/800
  `#103863`; explanation 12.5px/600 `#5C6675` (max-width 240, line-height 1.5); then a
  **See last 3 months** button (height 42, radius 13, `#F1F4F8`, 13.5px/800 `#334155`)
  that widens the period rather than dead-ending.
- **Populated:** a count label ("N transactions" 11px/800/ls 1.1px `#6B7684`), then a white card
  radius 18, padding `4px 14px`. Each row: padding `13px 0`, 1px `#F1F4F8` divider,
  34×34 radius-11 `#E7F6EE` square with a 16px green check, title 14px/800 `#103863`
  ("Debt payment"), sub-line 11.5px/600 `#5C6675` (time · stock location · description),
  amount 15px/800 `#12833C` prefixed `−`. Newest first.

### 4.4 Action bar (fixed, above the bottom nav)
White, 1px `#EEF1F5` top border, padding `10px 14px`, 9px gap.
- 54×52 radius-15 `#F1F4F8` **call** button (dials the customer's number).
- **Record payment** — expanded, height 52, radius 15,
  `linear-gradient(135deg,#1D7DC4,#103863)`, shadow `0 8px 18px rgba(16,56,99,.26)`,
  white 15.5px/800 with a plus glyph.
This replaces the floating green FAB, which sat over the transaction list.

### 4.5 Record-payment sheet
Replaces the old centre dialog. Scrim `rgba(4,26,61,.45)`; sheet white, radius `26px 26px 0 0`,
padding `10px 16px 26px`, shadow `0 -10px 34px rgba(4,26,61,.22)`, slide-up 240ms
`cubic-bezier(.2,.8,.3,1)`, grabber 42×4 `#E2E8F1`.
- **Header** — 38×38 radius-13 `#1D7DC4` avatar with initials; name 15px/800 `#103863`;
  sub "Balance N TSh" 12px/600 `#5C6675`; 32×32 close button `#F1F4F8`.
- **Amount block** — `#F5F8FC`, radius 16, padding `12px 14px`:
  `PAYMENT AMOUNT` 10.5px/800/ls .8px `#6B7684` with a live sub-line 12px/600 `#5C6675`
  ("Leaves N TSh" / "Clears the full balance"); right the entered amount 30px/800/ls −1.1px
  (`#103863`, `#9AA5B4` while zero) + `TSh`.
- **Presets** — three flex-1 buttons, height 36, radius 10, `#EAF3FB`, 12.5px/800 `#1668A6`,
  pressed `#DCEBF8`: **Full {balance} · Half · 500,000**.
- **Stock location** — label 10.5px/800/ls .9px `#6B7684`, then chips: height 44, radius 12,
  13px/800, selected `#EAF3FB`/`#1668A6`/border `#1D7DC4`, unselected white/`#5C6675`/`#E6EBF2`.
  (Replaces the dropdown; use a bottom-sheet picker if there are more than ~4 locations.)
- **Keypad** — 3-column grid, 8px gap, keys `1..9, 000, 0, ⌫`, height 48, radius 12,
  `#F4F6F9`, 20px/700 `#103863`, pressed `#E4EAF2`. Max 12 digits.
- **Description** — optional single-line field: `#F7F9FC`, 1.5px `#E6EBF2`, radius 13,
  height 46, 16px lines glyph, text 14px/600.
- **Actions** — **Cancel** (96×54, radius 15, `#F1F4F8`, 14.5px/800 `#334155`) and
  **Submit {amount}** (expanded, height 54, radius 15, the navy gradient, white 15.5px/800 with a
  check glyph). Submit is **disabled** (`#C3CBD8`, no shadow, label "Enter amount") until the
  amount is greater than zero; the payment is capped at the outstanding balance.
- On submit: close the sheet, append the payment, and show a **confirmation toast** —
  `#103863`, radius 14, padding `13px 15px`, inset 14px left/right, 168px from the bottom
  (clear of the action bar), 24×24 `rgba(255,255,255,.16)` check chip + message 13px/700 white,
  auto-dismiss after ~2.6s.

**Ledger rule (important):** one recorded payment must update *every* level — the customer's
balance/paid/percentage and transaction list, the supervisor's aggregate totals and progress, the
"Daily debt collection" amount, and the collection screen's total, count and list. In the
prototype each entry carries `{customer, supervisor, amount, note, location, when}` and all
figures are derived from that list; in Flutter, post the payment and refresh from the API rather
than mutating one screen's local copy.

---

# Screen 5 — Debt collection

Reached from the daily-collection card; back returns to the supervisor list.
App bar kicker `DEBT COLLECTION`, title = seller name.

- **Total card** — white, radius 20, padding 16, big card shadow.
  `COLLECTED` 11.5px/800/ls 1px `#5C6675`; amount 32px/800/ls −1.3px `#12833C` + `TSh`;
  right a 46×46 radius-15 `#E7F6EE` square with a 22px cash glyph `#12833C`.
  Below a 1px `#F1F4F8` rule: the resolved date range (14px calendar glyph `#1668A6` +
  12.5px/700 `#334155`, `nowrap`) and a count pill ("N payments" 12px/800 `#5C6675`
  on `#F1F4F8`, radius 8).
- **Period presets** — three flex-1 buttons, height 38, radius 11, 12.5px/800, `nowrap`,
  same selected/unselected treatment as the filter chips: **Today · This week · This month**.
  This replaces having to open a date picker for the common cases; keep the picker for
  a custom range.
- **Search** — same field style, placeholder "Search customer or supervisor".
- **Search** filters the payment list **and** the total and count above it; when nothing matches,
  show "No payment matches that search" (14px/700 `#6B7684`) in a white card, padding `44px 24px`.
- **Populated list** — white card, radius 20, padding `4px 14px`; each row padding `13px 0` with a
  1px `#F1F4F8` divider: 38×38 radius-13 `#E7F6EE` square with the customer initials 13px/800
  `#12833C`, name 14px/800 `#103863`, sub-line 11.5px/600 `#5C6675` (time · location · note),
  amount 15px/800 `#12833C` prefixed `+`. Newest first.
- **Empty state** — white card, radius 20, padding `34px 24px`, centred:
  60×60 radius-20 `#F1F5FB` square with a 28px receipt glyph `#9AA5B4`;
  "No collections in this period" 15px/800 `#103863`;
  explanation 12.5px/600 `#5C6675`, line-height 1.5, max-width 230;
  then a **Record payment** button — height 46, radius 14, the navy gradient,
  padding `0 20px`, white 14.5px/800, `nowrap`.
- Group by day with a sticky day header once the range spans several days.

---

## Interactions & Behavior
- One scrolling region per screen; app bar and bottom nav are fixed.
- Every secondary action is a bottom sheet with a scrim — no dialogs.
- Drill-down is in-place navigation (list → customers → sheet), with the app bar title carrying
  the context and back always returning one level.
- Animations: drawer slide-in and sheets 240ms `cubic-bezier(.2,.8,.3,1)`; scrims and overlays
  fade 180–200ms.
- Pressed states are flat colour changes (listed per component). Flutter: `InkWell` with the
  listed `highlightColor`.
- Minimum tap target 44×44; primary buttons 46–58.
- Currency: thousands-separated with `,`, ` TSh` suffix where shown, tabular figures for money
  columns (`FontFeature.tabularFigures()`). Large aggregates may be abbreviated (12.66M).
- Percentages are one decimal (93.8%).

## State Management
Dashboard controller: `menuOpen` (bool), `tab` (`'mine' | 'team'`).

Credit controller:

| State | Type | Notes |
|---|---|---|
| `view` | `'supervisors' \| 'customers' \| 'collection'` | which level is showing |
| `parent` | String? | supervisor name for the customers view |
| `query` | String | search, reset on navigation |
| `filter` | `'all' \| 'balance' \| 'clear'` | list chips |
| `range` | `'today' \| 'week' \| 'month'` | collection presets |
| `statement` | int? | index of the customer whose statement is open |
| `sheet` | int? | index of the customer whose payment sheet is open |
| `location` | String | selected stock location |
| `payBuf` / `payNote` | String | payment keypad buffer and description |
| `ledger` | List | recorded payments `{customer, supervisor, amount, note, location, when}` |
| `toast` | String | confirmation message, cleared after ~2.6s |

Derived: `paid = basePaid + ledgerFor(name)`, `balance = credit − paid`, `pct = paid / credit`,
totals summed over the visible list, `openAccounts = count(balance > 0)`,
`periodMovement = −Σ(payments in the period)`. A ledger entry matches a row when its customer
**or** its supervisor equals the row — that is what keeps the three levels in agreement.

Data needed: seller profile, dashboard aggregates, commission levels (own + team),
supervisor list with credit/paid, customers per supervisor, debt-collection payments by period,
and endpoints to record a payment and to place a call.

## Design Tokens
**Colours**
| Token | Hex | Use |
|---|---|---|
| Brand navy | `#103863` | app bars, headings, gradient end, selected chips |
| Brand blue | `#1D7DC4` | accents, avatars, today's bar, gradient start |
| Brand blue deep | `#1668A6` | blue text and active nav (contrast-safe) |
| Page background | `#F2F5F9` | |
| Surface | `#FFFFFF` | |
| Surface tint | `#F5F8FC`, `#F7F9FC`, `#F1F5FB`, `#EAF3FB` | inner blocks, chips, drawer |
| Neutral fill | `#F1F4F8` (pressed `#E4EAF2`), `#EEF2F7`, `#EAEFF5` | tracks, secondary buttons |
| Border | `#E6EBF2`, `#E7ECF3`, `#EEF1F5`, `#F1F4F8` | |
| Text primary | `#0F172A` / `#103863` | |
| Text secondary | `#334155`, `#475569`, `#5C6675` | |
| Text muted | `#64748B`, `#6B7684` | smallest labels — do not go lighter |
| Icon faint | `#9AA5B4`, `#B6C0CD` | chevrons, empty-state glyphs (non-text only) |
| Success | `#16A34A` bars, `#12833C` text, `#3F7355` captions, tints `#E7F6EE` / `#EEF9F2` | payments, collected |
| Warning | `#E5A227` bars, `#8A5F0B` text, `#C4820E` glyphs, tints `#FDF1DC` / `#FFF8EC` / `#FBEDD2` | level II, discipline |
| Purple | `#7A57C9` glyph, `#5E3FA8` text, tint `#F0EBFA` | shops-served stat |
| Danger | `#D14343`, tint `#FDECEC` | logout, badges, real errors only |

**Typography** — Plus Jakarta Sans (400–800).
Sizes: 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5, 16, 16.5, 20, 24, 32, 34 px.
Uppercase micro-labels ls .6–1.1px; large numerals ls −.3 to −1.4px.
**Contrast rule:** all text ≥ 4.5:1 on its background. `#94A0B0`, `#A3ADBC`, `#C3CBD8` and
`#8A94A6` are icon-only values — never use them for text.

**Spacing** — 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 16, 22, 26, 34, 54 px. Gutter 14px.

**Radius** — 4 (grabber), 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 26 (sheet top), 999 (pills).

**Shadows**
- Card: `0 1px 2px rgba(16,56,99,.05), 0 5px 14px rgba(16,56,99,.04)`
- Hero card: `0 1px 2px rgba(16,56,99,.05), 0 8px 22px rgba(16,56,99,.07)`
- Sheet: `0 -10px 34px rgba(4,26,61,.22)`
- Drawer: `8px 0 30px rgba(4,26,61,.25)`
- Primary button: `0 8px 18px rgba(16,56,99,.24–.26)`
- Segmented selection: `0 2px 6px rgba(16,56,99,.12)`

**Heights** — search field 48, filter/preset chip 36–38, list avatar 42, drawer row 46,
primary button 46–54, app-bar button 40, bottom nav icon 20.

## Assets
No image assets. All icons are inline stroke SVGs (2px stroke, round caps/joins) from a standard
outline set: menu, moon, chevrons, people, store, cart, shield, home, chart, document, person,
box, truck, bank, tag, nfc, inbox, gear, logout, calendar, search, phone, cash, receipt, plus,
check, warning, close. Map them to the icon set the app already uses — match weight and size,
not exact paths.

## Files
| File | What it is |
|---|---|
| `Leruma Home.dc.html` | Dashboard + drawer. Interactive. |
| `Leruma Credit.dc.html` | Credit & debt, customers drill-down, debt collection. Interactive. |
| `ios-frame.jsx` | Presentation-only iPhone bezel. Not part of the design. |
| `support.js` | Runtime for the prototypes. Not part of the design. |

Related handoffs from the same system, if they are in the repo: `design_handoff_sale_screen/`
(sale screen) and `design_handoff_login/` (login + the production `leruma-logo.svg`).
