# Handoff: Login Screen Redesign (Flutter POS)

## Overview
A redesign of the **login screen** of the existing Flutter POS app used by Leruma Distribution
Centre (Tanzania, TSh, English UI).

What changed from the current screen:
- The flat dark-blue background and translucent "glass" login card are gone. The screen is now
  **light**: a soft blue-tinted hero at the top and a **white sheet** carrying the form.
- The real **Leruma Enterprises logo** (vector, supplied by the client) sits on a floating white
  card, over an **orbit motif** derived from the logo's own elliptical rings.
- Title copy is now **Leruma Distribution Centre** with the tagline
  **Always make customer's rights**.
- Added a **fingerprint (biometric) login** button beside the primary Login button.
- Added field labels, focus states, an inline error state, **Remember me**, and a loading state.
- "Change Client" is no longer a small link at the bottom — it is a **chip in the form header**
  that opens a client-picker bottom sheet.

## About the Design Files
These files are a **design reference built in HTML** — a working prototype of the intended look
and behaviour. They are **not production code to copy**.

Recreate this design inside the existing Flutter app using its established patterns: existing
widgets, theme, state management, auth repository and API calls. Do not introduce a new
architecture. Take only the **visual design, layout, hierarchy and interaction model** from the
prototype.

Open `Leruma Login.dc.html` in a browser to interact with it (type, reveal the password, trigger
the error, use the fingerprint button, switch client, sign in).

## Fidelity
**High fidelity.** Colors, typography, spacing, radii and interactions below are final and should
be matched closely. Where the app already has an equivalent theme token, prefer the app's token.

The iPhone bezel, iOS status bar and home indicator are presentation only — the app is Flutter,
Android-first. Use `SafeArea`.

---

## Screen anatomy

Single `Stack` + `Column`, top to bottom:

| Region | Sizing | Notes |
|---|---|---|
| Background wash + orbit motif | 330px tall, behind everything | decorative |
| Top bar (ONLINE pill, theme button) | content | overlays the hero |
| Hero (logo card, title, tagline) | `Expanded`, centered | |
| Form sheet | content, pinned to bottom | white, rounded top, elevated |

Page background: `#F4F7FA`.

### 1. Background
1. A gradient block, full width, height 330: `linear-gradient(180deg, #EAF2FA 0%, #F4F7FA 78%)`.
2. **Orbit motif** — an SVG, full width, height 300, `preserveAspectRatio: slice`,
   `viewBox="0 0 402 300"`, three concentric rotated ellipse *strokes* centered at (201, 150):
   - `rx 188, ry 78`, stroke `#1D7DC4`, width 30, opacity .18, rotated −18°
   - `rx 188, ry 78`, stroke `#103863`, width 9, opacity .16, rotated −11°
   - `rx 142, ry 52`, stroke `#1D7DC4`, width 1.5, opacity .35, rotated −25°
3. A fade block from y=150 to y=330: `linear-gradient(180deg, rgba(244,247,250,0), #F4F7FA 78%)`,
   so the rings dissolve into the page before reaching the sheet.

In Flutter: a `CustomPainter` (three `canvas.drawOval` with `PaintingStyle.stroke` under a
rotation transform) plus two gradient `Container`s. The motif must sit **behind** the logo card.

### 2. Top bar
Padding `52px` top (status bar), `18px` horizontal, `0` bottom; row, space-between.
- **Left — status pill:** white, 1px `#E4EAF2` border, radius 999, padding `6px 12px 6px 8px`,
  shadow `0 2px 8px rgba(16,56,99,.06)`. Inside: a 7px green dot `#16A34A` with a
  `0 0 0 3px rgba(22,163,74,.15)` halo, then `ONLINE` — 11.5px / 800 / ls .4px / `#5A6577`.
  (Should reflect real connectivity; show an amber/`OFFLINE` variant when there is no network.)
- **Right — theme toggle:** 38×38, radius 12, white, 1px `#E4EAF2`, same shadow, 18px moon
  glyph `#5A6577`. Pressed `#EEF2F7`.

### 3. Hero
Centered column, gap 16, padding `0 26px 22px`.
- **Logo card** — white, radius 24, padding `14px 20px`,
  shadow `0 14px 36px rgba(16,56,99,.14), 0 2px 6px rgba(16,56,99,.06)`.
  Contains `assets/leruma-logo.svg` at **158px wide**, height auto.
- **Title** — "Leruma Distribution Centre", 23px / 800 / ls −0.5px / `#103863`,
  centered, line-height 1.15.
- **Tagline chip** — background `rgba(29,125,196,.1)`, radius 999, padding `7px 15px`,
  text "Always make customer's rights" 12.5px / 700 / ls .2px / `#1668A6`.

### 4. Form sheet
White, radius `32px 32px 0 0`, padding `22px 18px 0`,
shadow `0 -16px 44px rgba(16,56,99,.13)`, above the background layers.
- **Grabber** — 44×4, radius 4, `#E7ECF3`, centered, 16px bottom margin. Decorative
  (the sheet is not draggable).
- **Header row** — space-between:
  - Left: "Karibu tena" 23px / 800 / ls −0.5px / `#103863`;
    below it "Sign in to start selling" 12.5px / 600 / `#8A94A6`.
  - Right: **client chip** — background `#EAF3FB`, 1.5px `#CFE3F4`, radius 999,
    padding `8px 13px`, a 13px swap-arrows glyph + the client name, 12.5px / 800 / `#1D7DC4`.
    Pressed `#DCEBF8`. Opens the client sheet.
- **Fields** — 10px gap between them; each is a label + input row:
  - Label: 11px / 800 / ls 1px / `#8A94A6`, uppercase (`USERNAME`, `PASSWORD`), 6px below.
  - Input row: height **56**, radius 16, padding `0 14px`, gap 10.
    - Resting: fill `#F6F8FC`, 1.5px border `#E6EBF2`.
    - Focused: fill `#FFFFFF`, border `#1D7DC4`, plus glow `0 0 0 4px rgba(29,125,196,.13)`
      (160ms transition).
    - Error: border `#F3C4C4` on both fields.
    - Leading glyph 18px `#8A94A6` (person / padlock).
    - Text 15.5px / 700 `#0F172A`; placeholder `#A3ADBC` 600
      (`e.g. anzwari.m`, `••••••••`).
    - Username trailing: 28×28 clear button, radius 9, `#E7ECF3`, 12px ✕ `#5A6577` (only when
      the field has text).
    - Password trailing: 38×38 reveal button — eye `#7A8699` when hidden, struck-through eye
      `#1D7DC4` when revealed.
- **Error banner** (only when set) — `#FDECEC`, 1px `#F3C4C4`, radius 12, padding `9px 11px`,
  16px alert glyph `#D14343`, message 12.5px / 700 `#C33B3B`.
  Animation: a 350ms horizontal shake (−2px / +3px / −3px).
  Copy used: "Enter both username and password".
- **Options row** — space-between, both items **44px minimum tap height**:
  - Remember me — 22×22 box, radius 7; checked `#1D7DC4` fill + white tick;
    unchecked white with 1.5px `#D5DCE6`. Label 13px / 700 `#475569`, `nowrap`.
  - "Forgot?" — 13px / 700 `#1D7DC4`, `nowrap`.
- **Action row** — 10px gap:
  - **Login** — expanded, height 58, radius 18,
    `linear-gradient(135deg, #1D7DC4 0%, #103863 100%)`,
    shadow `0 10px 22px rgba(16,56,99,.28)`, pressed = 90% opacity.
    Label 16.5px / 800 white + an 18px arrow-right glyph.
    While loading: gradient dims to `#4E93C8 → #2A5C8F`, label "Signing in…", and an
    19px white spinner (2.5px ring, 700ms linear) replaces the arrow position (leading).
  - **Fingerprint** — 58×58 circle, white, 2px `#CFE3F4`,
    shadow `0 4px 14px rgba(29,125,196,.16)`, 26px fingerprint glyph `#1D7DC4`
    (`#103863` while prompting). Pressed `#EAF3FB`.
- **Biometric prompt line** (while awaiting the sensor) — centered, 13px spinner +
  "Touch the sensor to sign in" 12.5px / 700 `#1D7DC4`, fade-in 200ms.
- **Footer** — 1px `#F1F4F8` top rule, margin-top 14, padding `18px 0 34px`, centered:
  "Powered by **Moinfotech**" 11.5px / 600 `#A3ADBC` (brand word 800 `#5A6577`), and
  "Version 1.0.0+10" 10.5px / 600 `#C3CBD8`. Pull the version from the app's package info.

### 5. Client sheet (bottom sheet)
Scrim `rgba(4,26,61,.5)`, fade 180ms, tap to dismiss.
Sheet: white, radius `24px 24px 0 0`, padding `10px 16px 30px`,
shadow `0 -8px 30px rgba(15,23,42,.2)`, slide-up 240ms `cubic-bezier(.2,.8,.3,1)`.
- Grabber 38×4 `#E2E8F1`.
- "Change client" 18px / 800; sub "Pick the business this device sells for" 12.5px / 600 `#8A94A6`.
- Rows, 8px gap: padding 12, radius 14, 1.5px border.
  Selected `#F1F5FB` / border `#D5E3F7`; unselected `#F7F9FC` / border `#EEF1F5`; pressed `#E9F0FA`.
  38×38 navy `#103863` avatar with the initial (15px / 800 white), name 15px / 700,
  host 12px / 600 `#7A8699`, and an 18px blue check on the active one.
- Picking a client closes the sheet. In the real app this switches the API base host and should
  clear any cached session.

### 6. Signed-in confirmation
Full-screen white overlay **below the status bar** (z-index under it), padding `64px 30px 30px`,
fade-in 200ms. In production this is where the app navigates Home — the overlay exists so the
prototype can show the end state.
- 78×78 `#E7F6EE` circle with a 38px green check `#16A34A`,
  pop-in 300ms `cubic-bezier(.2,.9,.3,1.4)`.
- "Karibu, {username}" 19px / 800; sub "{client} · signed in on this device" 13.5px / 600 `#7A8699`.
- "Back to login" — height 50, radius 14, `#F1F4F8`, `#334155` 15px / 700.

---

## Interactions & Behavior
- Submitting with an empty username **or** password shows the inline error and shakes it; no
  network call. Typing in either field clears the error.
- Valid submit → loading state (prototype waits 1.1s) → signed in.
- Fingerprint → prompt line for ~1.4s → signed in. Guard against double-taps while prompting.
  Only show the fingerprint button when the device actually has biometrics enrolled **and** the
  user has logged in on this device before (otherwise hide it — the prototype exposes this as the
  `showBiometric` flag).
- Password is obscured by default; the reveal toggle switches the field, not the value.
- Remember me defaults **on**; it should persist the username (never the password).
- Minimum tap target 44×44 for Remember me and "Forgot?"; 56–58px for the primary controls.
- Animations: sheet 240ms `cubic-bezier(.2,.8,.3,1)`; scrim/prompt fade 180–200ms;
  error shake 350ms; success pop 300ms `cubic-bezier(.2,.9,.3,1.4)`; spinner 700ms linear;
  field focus glow 160ms.

## State Management
One login controller scoped to the screen:

| State | Type | Notes |
|---|---|---|
| `username` | String | |
| `password` | String | |
| `reveal` | bool | password visibility |
| `remember` | bool | defaults true |
| `focus` | `null \| 'user' \| 'pass'` | drives the focus styling |
| `error` | String | "" = no error |
| `loading` | bool | primary submit in flight |
| `bioPrompt` | bool | biometric sheet/prompt showing |
| `signedIn` | bool | success state |
| `clientOpen` | bool | client sheet |
| `client` | String | active client / API host |

Real integrations needed: auth endpoint, biometric plugin (`local_auth`), secure storage for the
remembered username and the biometric token, package-info for the version string, and
connectivity for the ONLINE pill.

## Design Tokens
**Colors**
| Token | Hex | Use |
|---|---|---|
| Brand blue (logo) | `#1D7DC4` | primary accent, focus, links |
| Brand blue deep | `#1668A6` | tagline text, pressed |
| Brand navy (logo) | `#103863` | headings, gradient end, avatars |
| Gradient (primary button) | `#1D7DC4 → #103863` 135° | |
| Gradient (loading) | `#4E93C8 → #2A5C8F` 135° | |
| Hero wash | `#EAF2FA → #F4F7FA` | |
| Page background | `#F4F7FA` | |
| Surface | `#FFFFFF` | |
| Field fill | `#F6F8FC` | |
| Blue tint | `#EAF3FB` (border `#CFE3F4`, pressed `#DCEBF8`) | client chip, fingerprint |
| Blue tint alt | `#F1F5FB` (border `#D5E3F7`) | selected client row |
| Neutral fill | `#F1F4F8` (pressed `#E4EAF2`), `#E7ECF3`, `#EEF2F7` | |
| Border | `#E4EAF2`, `#E6EBF2`, `#EEF1F5`, `#F1F4F8`, `#E2E8F1` | |
| Text primary | `#0F172A` | |
| Text secondary | `#475569`, `#5A6577` | |
| Text muted | `#7A8699`, `#8A94A6` | |
| Text faint | `#A3ADBC`, `#C3CBD8` | |
| Success | `#16A34A` (tint `#E7F6EE`) | ONLINE dot, sign-in confirmation |
| Danger | `#D14343` / `#C33B3B`, fill `#FDECEC`, border `#F3C4C4` | error banner |

**Typography** — Plus Jakarta Sans (400/500/600/700/800).
Sizes used: 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 15, 15.5, 16.5, 18, 19, 23 px.
Uppercase micro-labels: ls 1px. Large headings: ls −0.5px.

**Spacing** — 4, 6, 7, 8, 10, 13, 14, 16, 18, 22, 26, 34, 52 px. Screen gutter 18px.

**Radius** — 4 (grabber), 7, 9, 12, 14, 16, 18, 24, 32 (sheet top), 999 (pills), 50% (fingerprint).

**Shadows**
- Logo card: `0 14px 36px rgba(16,56,99,.14), 0 2px 6px rgba(16,56,99,.06)`
- Form sheet: `0 -16px 44px rgba(16,56,99,.13)`
- Client sheet: `0 -8px 30px rgba(15,23,42,.2)`
- Primary button: `0 10px 22px rgba(16,56,99,.28)`
- Fingerprint: `0 4px 14px rgba(29,125,196,.16)`
- Small chips/buttons: `0 2px 8px rgba(16,56,99,.06)`
- Focus glow: `0 0 0 4px rgba(29,125,196,.13)`

**Heights** — field 56, primary button 58, fingerprint 58, theme button 38, secondary button 50.

## Assets
| File | Notes |
|---|---|
| `assets/leruma-logo.svg` | The Leruma Enterprises logo, rebuilt as clean vector from the client's PDF. Two colors only: `#103863` and `#1D7DC4`. Transparent background. Drop it into the Flutter app's asset folder and render with `flutter_svg`. |

All other icons are inline stroke SVGs (person, padlock, eye, eye-off, swap-arrows, check, alert,
arrow-right, fingerprint, moon). Map them to the icon set the app already uses — match weight and
size, not exact paths.

## Files
| File | What it is |
|---|---|
| `Leruma Login.dc.html` | The design. Open in a browser; fully interactive. |
| `assets/leruma-logo.svg` | Production-ready logo asset. |
| `ios-frame.jsx` | Presentation-only iPhone bezel. Not part of the design. |
| `support.js` | Runtime for the prototype. Not part of the design. |

Sample clients in the prototype (Leruma, Mvungi Distributors, Demo store) are illustrative —
wire the picker to the app's real client/host configuration.
