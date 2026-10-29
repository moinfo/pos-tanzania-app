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
