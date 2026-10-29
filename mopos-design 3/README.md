# Mopos Lodge: Design Handover for Claude Code

Design source (open in browser, read-only reference): https://claude.ai/artifact/4aEM5eYCwQj5ZWMFTh7zLf
The designs are plain HTML under `project/*.dc.html` (one file per screen). Read the files for exact spacing/markup; this document is the summary.

Goal: restyle the existing Flutter app (Mopos) to match these 14 screens. **Do not change business logic, routes, models or API calls.** This is a visual/UI pass only. Keep the existing theme tokens (colours below are the app's own).

## 1. Visual idea: "Lodge at night"
A navy/blue night skyline of arches with an amber moon and lit windows. Arch shapes (rounded top) are the brand motif: room badges, nav active pill, header art. Amber = "lit / occupied / action". Everything else stays on the app's existing blue + grey palette.

## 2. Colours (all from the existing app theme; nothing new)
| Token | Hex | Use in design |
|---|---|---|
| primary / brandPrimary | #1565C0 | buttons (Pay, Save), links, drawer icons, arch art mid-tone |
| primaryDark | #0D47A1 | screen header band and hero cards |
| primaryLight | #42A5F5 | art accent only (opacity .45) |
| secondary | #2B2D42 | main text, floating nav, selected chips, Cash segment, today circle |
| warning | #F59E0B | FAB, active nav pill, Occupied/Checked in (lit), moon, windows, Lipa Namba segment |
| error | #EF4444 | Balance bar, logout icon |
| success | #10B981 | reserved for Vacant / fully paid states (not yet shown in screens) |
| info | #3B82F6 | Reserved status (Calendar legend) |
| lightBackground | #F8F9FA | screen background |
| lightDivider | #E9ECEF | card borders, dividers, track bars |
| lightTextLight | #6C757D | secondary text, input borders |
| card | #FFFFFF | cards |

Derived tints (small text legibility only): Occupied badge bg #FEF3C7 / text #92400E; owed/error text #B91C1C on #FEE2E2; success text #047857. Add them as extra theme constants (e.g. `warningSoft`, `onWarningSoft`, `errorText`, `errorSoft`, `successText`).

Dark theme was NOT designed. Use the app's existing dark tokens (#0D0D0D bg, #171717 surface, #1F1F1F card, #F5F5F5 text, #A3A3A3 textLight, #2E2E2E divider, #262626 accent) and the same structure; header band stays primaryDark.

## 3. Typography
- Display / titles / money figures: **Bricolage Grotesque** (w500-800). Package: `google_fonts`.
- Body / labels: **Public Sans** (or keep the app's current body font if it already uses one).
- Use tabular figures for money. Screen title 36/40 w800 letter-spacing -0.03em, white on header. Eyebrow 12px w700 uppercase +0.08em tracking, amber. Section title 20/26 w700. Card title 20/26 w700. Body 14-16. Meta 13/18 in textLight. Money hero 40-48 w700 with small "TZS" prefix 14-15 w600.

## 4. Shape, spacing, elevation
- Screen gutter 16. Card radius 20, hero cards 24, header band bottom radius 32, bottom sheets top radius 32 with 40x4 grab handle.
- Cards: white, 1px #E9ECEF border, no shadow.
- Inputs: height 48, radius 14, 1px #6C757D border, label ABOVE the field (13/18 w600), focus 2px primary outline. Primary button height 52 radius 16 (#1565C0, white text). Small buttons height 44 radius 14. Minimum touch target 44.
- FAB: amber pill, height 52, radius 999, label + plus, shadow 0 12 28 rgba(43,45,66,.3).
- Floating bottom nav: secondary #2B2D42, height 68, radius 26, inset 16 from sides and 14 from bottom. 5 items (Board, Bookings, Calendar, Rooms, Day close). Active item: amber bg, #2B2D42 text, radius 22 22 12 12 (arch top). Inactive text #E9ECEF.
- Overlay behind sheets/drawer: rgba(43,45,66,.6).

## 5. Signature components
1. **Header band** (all tab and detail screens): bg #0D47A1, bottom radius 0 0 32 32, skyline SVG bottom-right (about 170x94), eyebrow + big title bottom-left. Tab screens (Board, Bookings, Calendar, Rooms, Day close) keep the app bar row (menu, switch business, bell, theme toggle) above; detail screens show a back button instead. Main/Board header is taller (250) and the two money cards overlap its bottom edge.
2. **Skyline art SVG** (viewBox 0 0 200 110):
```
<circle cx="170" cy="20" r="11" fill="#F59E0B"/>
<path d="M14 110V86a28 28 0 0 1 56 0v24z" fill="#1565C0" fill-opacity=".55"/>
<path d="M60 110V62a36 36 0 0 1 72 0v48z" fill="#1565C0" fill-opacity=".85"/>
<path d="M122 110V84a30 30 0 0 1 60 0v26z" fill="#42A5F5" fill-opacity=".45"/>
<path d="M78 110V92a18 18 0 0 1 36 0v18z" fill="#F59E0B"/>   <!-- lit window -->
<path d="M140 110V98a12 12 0 0 1 24 0v12z" fill="#F59E0B"/>
```
Implement as a `CustomPainter` or `flutter_svg` asset (`assets/art/skyline.svg`).
3. **Arch badge** (room icon): 44x52 (cards) / 48x56 (Board), radius 22 22 10 10, amber bg, #2B2D42 **door icon** (no text). Room NAME is always shown as text next to it (names can be long: allow 2-3 line wrap, never abbreviate).
4. **Status badge**: pill, 12/16 w600, dot + label. "Lit" (Occupied/Checked in) = #FEF3C7 bg, #92400E text, #F59E0B dot. Owed = #FEE2E2 / #B91C1C.
5. **Hero card** (Day close closing cash, Expenses total, Report net): bg #0D47A1, radius 24, small skyline art bottom-right, white Bricolage figure.
6. **Segment/progress bars**: height 8-12, radius 999, 3px gaps between segments. Payments: Bank #1565C0, Lipa Namba #F59E0B, Cash #2B2D42. Collected vs balance: paid #1565C0, balance #EF4444.

## 6. Screens (14)
Layout is 390px wide; heights vary. Build responsively (these are phone widths).
1. **Board (Main)**: header "Lodge" with date eyebrow; two money cards (Today's revenue; Outstanding in red); "Tonight" stats row (Occupied / Vacant / Arriving / Departing, dividers between); "Rooms tonight" list of **full-width room cards** (arch door badge, room name, "type · rate / night", guest name + Occupied badge, then Pay (primary) and Check out (outlined) side by side); Booking FAB; floating nav.
2. **Bookings**: header, search field, horizontally scrolling filter chips (selected = #2B2D42 fill, white text), count line, booking cards (arch badge, guest + status badge, room name, dates, paid progress bar, Total / Paid / Balance trio; balance red when owed), FAB, nav.
3. **Calendar**: month switcher (prev/next round buttons) in content, legend (Reserved info, Checked in amber, Checked out grey), week grid with room-name column (88px, up to 3 lines) and 7 day columns, today = filled #2B2D42 circle, booking bars = amber pills, "Today" card listing guest, room, "Night x of y . leaves date".
4. **Rooms**: header eyebrow "N rooms . N occupied", cards (arch, room name, "type . TZS rate / night", status badge under text, three-dot menu button), overflow menu (Change status, Edit room, Maintenance, Delete red), "Room" FAB.
5. **New room** (bottom sheet over Rooms): Room name* (full width), Room number (optional), Room type, Use (select), Rate per night (TZS prefix), Description, Save room.
6. **Day close**: tab header "End of day", date chip + calendar button, summary key/value card, Takings and Expenses cards, Cash count (Banked, Cash submitted, Note), hero "Closing cash", Close day button.
7. **Payments**: back header "Money in", period chip + calendar button, total card with 3-segment bar and legend, payment rows (icon tile, type, date . user, amount, three-dot menu with Edit / Delete).
8. **Edit payment** (sheet): Amount, Payment type, Nights, Note, Save changes.
9. **Guests**: header "Directory", search, count, guest cards (navy arch avatar with initials, name, phone/details, "Owes 25K" red badge when applicable).
10. **Expenses**: header "Money out", period chip, hero total, Entries list (icon tile, description, category . date, amount, delete X), By category bars, Expense FAB.
11. **New expense** (sheet): Amount*, Description*, Category, Room (optional, "Whole lodge"), Payment type, Date, Save expense.
12. **Report**: period chip, hero Net result (Revenue, Expenses, Maintenance cost), Collected vs balance bar, tiles (Occupancy, Bookings, Nights sold), per-room cards (name, bookings . nights . occupancy, revenue, "due" badge), Guest list.
13. **Forecast**: assumed-occupancy card with slider (min 0 max 100) and "Use actual" link, tiles (Per day / month / year), key-value table (full capacity, expenses, net), per-room projected revenue, Scenarios list (selected scenario highlighted with #FEF3C7 bg and amber border).
14. **Menu (drawer)**: width 312, right radius 28. Header band (#0D47A1, skyline, white avatar circle, "Lodge Admin", email). Items (52 high, icon primary blue, 24px): Board, Bookings, Payments, Guests, Messages, Calendar, Rooms, Expenses, Report, Forecast, Day close. Active item = #E9ECEF pill (radius 0 26 26 0). Divider, then Switch Business (subtitle "Linked accounts"), Settings, Logout (text #B91C1C, icon #EF4444).

**Not designed yet:** Messages screen, Settings, Switch Business, Login, dark theme variants, empty states, loading/error states, Reserved/Vacant/Checked-out visual states beyond the legend. Follow the same rules for them.

## 7. Data and content notes
- Room names are free text and can be long. Layouts above already wrap. The sample names "Executive Garden Suite" / "Standard Single Room" are illustrative only.
- Fixes to apply in the real app while restyling: Report must show real nights sold (it showed "0 night(s)"); show status as human labels ("Checked in", not `checked_in`); Forecast slider value, tiles and scenarios must come from the same occupancy number.
- Money format: thousands separators, "TZS" prefix small; compact "25K / 1.2M" only in tiles and bars.

## 8. Suggested implementation order for Claude Code
1. Add theme constants and fonts (colours in section 2, `google_fonts`). Do not remove existing tokens.
2. Build shared widgets: `NightHeader` (band + skyline + eyebrow + title + optional back), `SkylineArt`, `ArchBadge`, `StatusBadge`, `HeroCard`, `AppCard`, `MoneyText`, `FloatingNav`, `AmberFab`, `SheetScaffold`, `LabeledField`.
3. Restyle screens in this order: Board, Bookings, Rooms (+ sheet), Calendar, Payments (+ sheet), Day close, Guests, Expenses (+ sheet), Report, Forecast, Drawer.
4. Check each at 360px width and with large system font (text scale 1.3): no clipped text, no horizontal scroll, tap targets >= 44.
5. Run existing tests; no logic changes expected.

## 9. Accessibility checklist
- Icon-only buttons need semantic labels (back, close, room actions for <room name>, delete expense <name>).
- Amber on white is not readable text: amber is for fills and dots only. Text on amber is #2B2D42; text on lit badges is #92400E.
- Do not rely on colour alone for status; always keep the label.

---

# PART 2: Contracts mode (daily-payment contracts, e.g. Bajaj boda)

Same app, same palette, same fonts and card/input rules as Part 1. Different identity so the two modes feel distinct: **"Road"** instead of "Lodge at night".

## Differences from Lodge mode
| | Lodge | Contracts |
|---|---|---|
| Header art | arch skyline, moon, lit windows | winding road with dashed centre line, sun, wheel (SVG below) |
| Badge shape | arch (door icon) | circle (initial, rank number, status icon) |
| Bottom nav | floating dark pill, amber arch pill for active | flat white bar, 76 high, 1px top border, amber 28x4 indicator on the active tab, active label primary blue |
| Signature visual | room cards | **90-day strip** (one tick per contract day: green paid, red unpaid) and a **ring gauge** (behind/active) |
| Logo mark in app bar | amber arch "M" | amber circle "M" |
| Tabs | Board, Bookings, Calendar, Rooms, Day close | Dashboard, Contracts, Requests, Inspections, Services |

Road art SVG (viewBox 0 0 200 110, place bottom-right of header, about 160x88):
```
<circle cx="168" cy="24" r="10" fill="#F59E0B"/>
<path d="M-10 104C40 104 52 66 104 72S168 60 214 36" fill="none" stroke="#1565C0" stroke-opacity=".85" stroke-width="16" stroke-linecap="round"/>
<path d="M-10 104C40 104 52 66 104 72S168 60 214 36" fill="none" stroke="#E9ECEF" stroke-opacity=".8" stroke-width="2" stroke-dasharray="5 7"/>
<circle cx="152" cy="86" r="14" fill="none" stroke="#42A5F5" stroke-opacity=".7" stroke-width="3"/>
<circle cx="152" cy="86" r="3" fill="#F59E0B"/>
```

## Status colours in this mode
Behind = error (#EF4444 fill, #B91C1C text on #FEE2E2). On track / paid / credit = success (#10B981 fill; text #047857). Reminder sent = blue tint (#DBEAFE bg, #1E40AF text). Due today = amber tint (#FEF3C7 / #92400E). Approve and Add payment buttons use #047857 with white text (success fill #10B981 fails contrast with white).

## Screens (boards 15-22 in the canvas)
15. **Dashboard**: header "Overview"; summary card with ring gauge "4/5" (red arc = behind of active), "5 of 5 Active contracts", "4 behind", then To collect now (red) and Collected (green); blue hero "Still owed on active"; "Most behind" list: rank circle, name, "N day(s) unpaid", thin red bar (days / 40, capped), amount in red on the right.
16. **Contracts**: header "Portfolio" with settings gear; search; filter chips (All, Behind, On track, Completed, Terminated with counts; selected = #2B2D42 fill with check); contract card: name, phone, vehicle type, "Behind 34d" badge, 90-day strip, Days / Paid / Unpaid figures, grey panel (Contract amount, Payments green, Balance red, Profit green), actions Renew (green outline) and Terminate (assumed; the original screenshot hid the second action, confirm); "New Contract" FAB (amber).
17. **Payment requests, empty**: icon + "All caught up" + "No payment requests awaiting review".
18. **Payment requests, list**: header "Review"; "Awaiting review" + pending count; cards with name, phone, amount (primary blue), "Submitted date", View receipt link, Reject (red outline) and Approve (#047857).
19. **Inspections**: header "Maintenance checks"; groups Overdue (red warning icon, red status text) and Upcoming (amber clock for "Due today", green check otherwise); each row: name, plate (bold, tracked), status line, "Mark" text button.
20. **Services**: header "Repairs"; blue hero total service cost (sum, computed client-side); rows with wrench icon circle, name, description, date, amount, three-dot menu; "Service" FAB.
21. **Contract detail**: back, Terminate and Renew actions in the header; summary card (type, Behind badge, "Reminder sent" tag, 90-day strip, Balance, Profit, Days paid, Days unpaid, plate chip with edit); date range buttons (from / to); statement list: opening balance row (grey), then daily rows with Credit / Debit / Balance; "Add payment" FAB (#047857).
22. **Menu (drawer)**: same layout as Lodge menu with road art and "Contract Admin"; items Contracts, Contract Payments, Contract Services, Contract Payment Requests, Contract Inspections, Contract Messages; then Switch Business, Settings, Logout.

## Data notes
- Profit differs between the Contracts card (1,800,000) and Contract detail (1,680,000) in the source screenshots. One of them is wrong in the app; verify the calculation. The design shows 1,680,000 on the detail screen.
- Unpaid bar width in "Most behind" is a visual ratio only; choose a sensible max (design used 40 days).
- Not designed: Contract Payments list, Contract Messages, New contract form, Add payment form, Add service form, Renew/Terminate confirmations, receipt viewer, dark theme.

---

# PART 3: E-Wakala mode (mobile money agent: float, tills, cash, banks)

Same palette and shared rules (Part 1 sections 2, 4: inputs, buttons, touch targets). Third identity: **"Ledger chip"**. Files are prefixed `W*.dc.html` (17 screens).

## Differences from Lodge and Contracts
| | Lodge | Contracts | E-Wakala |
|---|---|---|---|
| Header | #0D47A1, rounded bottom, skyline | #0D47A1, rounded bottom, road | **#2B2D42 charcoal, flat bottom, SIM-chip art**, 4px tri-colour stripe at the bottom (blue #1565C0, amber #F59E0B, green #10B981) |
| Display font | Bricolage Grotesque | Bricolage Grotesque | **Space Grotesk** (headings, figures, section labels), body Public Sans |
| Eyebrow colour | amber | amber | primaryLight #42A5F5 |
| Cards | radius 20, full border | radius 20-24 | **left colour rail 4px**, radius 4 16 16 4 (semantic: green deposit, red withdrawal, blue SIM/bank, amber cash) |
| Icon holders | arch / circle | circle | **rounded square 44, radius 12**, tinted bg (blue #DBEAFE/#1E40AF, amber #FEF3C7/#92400E, green #D1FAE5/#047857, red #FEE2E2/#B91C1C, grey #E9ECEF) |
| Bottom nav | floating dark pill | flat bar, amber top indicator | flat white bar 80 high, **active = blue pill 52x30 behind the icon**, label blue bold |
| FAB | amber pill | amber pill | **primary blue rounded-square (radius 16)**, 54 high |
| Two-section screens | n/a | n/a | **segmented control in the content** (not in the header): Categories | Transactions, SIM Cards | Float Transactions, Deposits | Withdrawals. Container #E9ECEF radius 14 padding 4; active segment white with a 1px soft shadow, bold #2B2D42 |

SIM-chip header art (viewBox 0 0 120 90, about 104x80 bottom-right): rounded rect outline #42A5F5 (opacity .55) with 2 horizontal + 2 vertical grid lines (opacity .35) and an amber rounded square (#F59E0B) in the centre cell.

## Shared patterns
- **Setup row** (categories, SIM cards): icon tile, name (Space Grotesk 18/24 w700), sub-label, then two 40px square buttons: edit (blue icon on #E9ECEF) and delete (red icon on #FEE2E2). Never place the amount here.
- **Transaction row**: icon tile, title (Space Grotesk 17/22 w700), date line (13, textLight), amount right-aligned (Space Grotesk 18 w700, semantic colour), three-dot button 40. Same column positions on every list.
- **Balance card**: white card with rail; account rows (name, amount w600); footer band #2B2D42 with uppercase label (#E9ECEF) and total (white, Space Grotesk 24 w700).
- **Date range bar** (Expenses, Commission, Capital): white card, 36px calendar tile (#DBEAFE), range text, "Change" button (#DBEAFE bg, #1E40AF text). Single-day filters use a small "All dates" outlined chip on transaction lists.
- **Section label**: Space Grotesk 13 uppercase, +0.08em tracking, #6C757D.
- Titles: 30/34 w700, wrap to two lines (max width ~250) so they never collide with the chip art.
- Colours for amounts: deposits/credits #047857, withdrawals/expenses #B91C1C, fees/float #1565C0, neutral #2B2D42.

## Screens (boards 23-38)
23. **Dashboard**: header "Today . 29 Oct 2026"; New deposit (green outline) and New withdrawal (red outline) side by side; three square action tiles (Record cash, Record bank, Record wakala float); Money on hand card (42px figure, "+70,000 since yesterday" green pill, 2-colour bar: wakala lines and bank blue, cash book amber, legend with figures); Movement table with fixed columns (label, Today, Yesterday, Change) so numbers align; Net balance row bold with top border.
24. **Cash basis, Categories**: segmented control, one category row (Cash in hand, Drawer), "Add Category" FAB.
25. **Cash basis, Transactions**: balance card (Cash in hand 800,000, total band), "Transactions" label + "All dates" chip, transaction row, "Add Transaction" FAB.
26. **Bank basis / Mobile money, Categories**: CRDB Bank, NMB Bank rows.
27. **Bank basis, Transactions**: balance card with grand total 3,500,000, then one row per bank transaction.
28. **SIMs, SIM cards**: M-Pesa, Tigo Pesa, Airtel Money ("Wakala line"), "Add SIM" FAB.
29. **SIMs, Float transactions**: dark "Total float" card (10,010,000), rows per float entry, "Add Float" FAB. The original list had a fifth row cut off in the screenshot; render whatever the API returns.
30. **Lipa Namba transactions**: Till select (label above), 2x2 summary tiles (Deposits count, Withdrawals count, Fees, Net), rows with direction tile (green down arrow deposit, red up arrow withdrawal), name, till name, "date . phone", amount with "+ fee" under it, delete button.
31/32. **Customer transactions, Deposits / Withdrawals**: back + calendar header, segmented control, customer search field (label above, search icon), centred empty state, FAB "Add Deposit" / "Add Withdrawal".
33. **Wakala Expenses**: date range bar, total card (red), expense card with rail, edit/delete buttons, "Expense" FAB.
34. **Wakala Report**: period row, "Money on hand" total (sum of sections) with 3-segment bar (SIM float #1565C0, bank #42A5F5, cash #F59E0B), then four balance cards: SIM cards float, Bank / Mobile money, Cash transactions, Wakala expenses (rail colours blue, light blue, amber, red). Calendar and refresh in header.
35. **Commission**: date range, total card (green percent tile, "1 entry" pill, correct singular/plural), commission row with "Wakala" tag, amount, description, date, three-dot.
36. **Capital**: date range, three KPI tiles (Capital, Commission, Total), capital entry rows.
37. **Lipa Namba tills**: card per till (SIM tile, name, till number, three-dot, Float 28px blue, "Fees earned", Deposit (green outline) and Withdraw (red outline) buttons), "Add Till" FAB.
38. **Lipa Namba fee tiers**: one white panel with divided rows: "Amount range" label + range (full text, never truncated) on the left, "Fee" + value (blue) on the right, three-dot; "Add Tier" FAB.

39. **Menu (drawer), `WDrawer`**: 324px wide panel, radius 0 20 20 0, charcoal #2B2D42 header with chip art, tri-colour stripe, rounded-square avatar, "Wakala Admin" / wakala@mopos.co.tz. Items are grouped under small uppercase labels so setup and transactions are easy to scan: **Money** (Transactions, Deposits & Withdrawals, Customer Balances), **Books** (Cash Basis, Bank Basis), **Wakala** (Wakala Float, Wakala Expenses, Wakala Report, Commission, Capital), **Lipa Namba** (Tills, Transactions, Fee Tiers). Item = 34px rounded-square tile + label, min height 48. Active item: #DBEAFE row, blue 4px left marker, solid blue tile with white icon, bold label. Footer after a divider: Switch Business (sub-label "Linked accounts"), Settings, Logout (red #B91C1C, icon #EF4444). The menu scrolls on small phones (header stays, list scrolls); group labels are design additions, the item order and names match the app.

## Data and logic notes
- Money on hand on Dashboard = wakala lines and bank (SIM float + bank) + cash book. Report must show the same total; verify (design numbers: 2.6M + 3.5M + 0.8M = 6.9M).
- Plural labels: "1 entry" / "N entries".
- Not designed: Add/Edit forms (deposit, withdrawal, till, tier, SIM, float, commission, capital, expense, category), delete confirmations, date picker, dark theme. Reuse the sheet pattern from Part 1 (radius 32 top, 40x4 handle, 48px inputs, 52px primary button) and the Wakala card/segmented rules above.

## Canvas map (for reference)
Lodge boards y=0..3400, Contracts y=3700, E-Wakala y=5300 (row 1) and y=6680 (row 2). Use Zoom to fit to see everything. Every `.dc.html` file is a standalone 390px-wide screen (no JS needed): open in a browser to inspect exact spacing.
