# ACI Team Connect — UI/UX Replication Guide

Screen-by-screen blueprint for **pixel-perfect replication** of the app in any framework (React, Flutter, native, etc.). Every colour, spacing, radius, font, icon, layout region, interaction, state and micro-behaviour is documented.

---

## 0. Global Design System

### 0.1 Colour tokens (ACI Forest palette — `src/styles.css`)

All colours are OKLCH; hex approximations shown for convenience.

| Token | OKLCH | ≈ Hex | Usage |
|---|---|---|---|
| `--background` | `0.985 0.008 145` | `#F5F8F3` | App body |
| `--foreground` | `0.20 0.04 155` | `#0F2A1E` | Body text |
| `--forest-deep` | `0.28 0.07 152` | `#173A2A` | Primary CTA, sidebar bg, headings, gradients |
| `--forest` | `0.38 0.10 150` | `#22563E` | Icon accent, gradient stop, hover |
| `--forest-soft` | `0.55 0.11 148` | `#4C8863` | Mid-tone accents |
| `--moss` | `0.62 0.12 152` | `#5D9E75` | Chips, secondary bars |
| `--lime` | `0.78 0.17 138` | `#A6E663` | Highlight/CTA-on-dark, active pill |
| `--amber-accent` | `0.72 0.15 78` | `#D8A24A` | Break/warning accent |
| `--card` | `#FFFFFF` | white cards |
| `--muted` | `0.96 0.015 145` | `#F1F5EE` | Zebra/quiet fills |
| `--muted-foreground` | `0.48 0.03 150` | `#617369` | Secondary text |
| `--border` | `0.90 0.02 145` | `#E1E7DD` | 1px hairlines |
| `--destructive` | `0.58 0.20 25` | `#D64228` | Error / overdue |
| `--sidebar` | `--forest-deep` | | Left rail |
| `--sidebar-accent` | `0.34 0.09 152` | `#204C36` | Active nav pill bg |

**Legacy aliases** (still referenced in some files, resolve to greens):
`--navy-deep → --forest-deep`, `--navy → --forest`, `--navy-soft → --forest-soft`, `--brand-red → --amber-accent`, `--brand-teal → --moss`, `--brand-green → --lime`.

### 0.2 Level colour ramp (`levelColor(1..17)`)
Interpolated HSL along **navy → teal → green**:

```
hue = 220 + (155-220) * (L-1)/16
lightness = 22 + (52-22) * (L-1)/16
saturation = 55 + 10 * sin(π * (L-1)/16)
```
→ L1 `hsl(220 55% 22%)` (deep navy) · L9 `hsl(191 65% 37%)` (teal) · L17 `hsl(155 55% 52%)` (fresh green).

### 0.3 Typography
- **Display**: `Manrope`, weights 600–800, letter-spacing `-0.01em`. Used on `h1–h4`, headline stats, greeting labels.
- **Sans (body)**: `Inter`, 400–500. Applied to `body`, form inputs, meta text.
- **Mono**: system mono (`font-mono`) — timestamps, IDs, demo emails.

Sizes (Tailwind):
- Page title: `text-xl md:text-2xl font-bold` (`~20/24px`)
- Section title (`h3`): `font-semibold text-sm–base`
- Body: `text-sm` (14 px)
- Meta / muted: `text-xs` (12 px)
- Micro caption / uppercase labels: `text-[11px]` or `text-[10px]`, `uppercase tracking-widest`
- Big stat number: `font-display text-3xl font-bold` (attendance clock, command %)

### 0.4 Radius & elevation
- Radius scale: `--radius: 0.875rem` (14 px); `sm=10`, `md=12`, `lg=14`, `xl=18`.
- Cards default `rounded-2xl` (16), banner/attendance cards `rounded-3xl` (24), chips `rounded-full`, buttons `rounded-xl` (12).
- Shadows: `shadow-sm` for stat chips, `shadow-md` for CTA buttons, `shadow-lg` for the forest gradient banners.

### 0.5 Spacing rhythm
- Page container: `p-4 md:p-8`, max width `1400px`, centered.
- Vertical section gap: `space-y-5` on mobile-first views, `space-y-6` on desktop-heavy pages (Reports/Admin/Growth).
- Card padding: `p-3` (compact list items), `p-4` (secondary cards), `p-5` (primary cards).
- Grid gaps: `gap-2` micro strips, `gap-3` cards, `gap-4/6` desktop grids.

### 0.6 Iconography
Everything is `lucide-react` at `h-3 → h-6`. Common mapping:
- Home → `LayoutDashboard` · Activity → `CalendarClock` · Tasks → `ListChecks` / `ListTodo`
- Team → `Users` · Reports → `BarChart3` · Growth → `TrendingUp` · Admin → `Shield`
- Check-in → `LogIn` · Check-out → `LogOut` · Break → `Coffee` · GPS → `Navigation` / `ShieldCheck`
- Assign → `Plus` · Reminder → `Bell` · Feedback → `Star`
- Brand mark → `Leaf` (auth: `Car`)

### 0.7 Layout shell (`_authenticated/route.tsx`)
```
┌───────────────────────────────────────────────────────────────┐
│ AppSidebar (desktop, w-64, --forest-deep)  │  <main>          │
│  ├─ Brand block (Leaf on lime tile)         │ ┌──────────────┐│
│  ├─ Nav list                                │ │Ribbon: 1 px  ││
│  └─ Profile footer + Sign out               │ │gradient      ││
│                                             │ │forest→moss   ││
│                                             │ │→lime         ││
│                                             │ └──────────────┘│
│                                             │  Route Outlet   │
│                                             │  (padded, max   │
│                                             │  1400 centered) │
└───────────────────────────────────────────────────────────────┘
```
Mobile (< 768 px): sidebar hidden; `MobileTopBar` (sticky, forest-deep) + `MobileBottomNav` (5 tabs, white on forest bottom bar with safe-area padding).

### 0.8 Motion & feedback
- Colour transitions on hover: `transition-colors` (150 ms default).
- Toasts: `sonner` bottom-right/bottom-center; success uses green ✓, error red.
- Loading buttons show `Loader2` spinning icon.
- Auto check-in/out toasts include emoji: *"Auto check-in — welcome to ACI Centre 🌿"*, *"Auto check-out — safe travels 🏁"*.

### 0.9 Bangla greeting (used on both dashboards)
`h < 12 → "Shuprobhat"`; `12–16 → "Shubho ohporahno"`; `≥17 → "Shubho shondha"`. Prefixed with `Sparkles` icon in forest-green tracked-widest uppercase.

---

## 1. Sign-in — `/auth`

**Purpose**: only public route. Split brand+form panel.

**Layout** (desktop): full-viewport gradient background `bg-gradient-to-br from-[--forest-deep] via-[--forest] to-[--forest-soft]`, centred `max-w-5xl` two-column grid.

**Left column (hidden on mobile)** — glass card `bg-black/20 backdrop-blur border-white/10 rounded-xl p-10`:
- Row: `11×11` `--amber-accent` tile with `Car` icon → **Team Connect** display, subtitle "ACI MOTORS • MARKETING" (uppercase tracked-widest, opacity 70).
- Hero headline (`text-3xl display`): *"Daily activity, tasks and performance across all 17 levels."* — last clause coloured `--amber-accent`.
- Supporting paragraph, opacity-80.
- Footer: `© {year} ACI Motors Ltd.`, opacity 60, `text-xs`.

**Right column** — white `Card p-8 space-y-6`:
- `h2` "Sign in" (display 2xl) + subtitle "Use your ACI Motors credentials." (muted).
- Form: two `Label + Input` groups (Email, Password) then full-width Button `bg-[--forest-deep] hover:bg-[--forest]` labelled **Sign in**; shows spinner while pending.
- Divider (`border-t pt-4`) then a demo-account picker: label "Try a demo account · password `Demo@1234`", followed by 4 rows (L1 MD, L9 GM, L13 PM, L17 PE). Each row: monospace email left, level+role right, hover `bg-accent`.
- Submit success → `nav({ to: "/dashboard" })`. Errors → `toast.error(error.message)`.

Meta: `<title>Sign in — Team Connect</title>`.

---

## 2. Dashboard — `/dashboard`

Route auto-branches by role level:
- `isObserver(profile.role_level)` (levels 1–12) → **Observer Dashboard** (§2.B)
- Otherwise (levels 13–17) → **Field Dashboard** (§2.A)

### 2.A Field Dashboard (L13–L17)

Vertical stack, `space-y-5`.

1. **Greeting header** — two-column flex:
   - Left: uppercase `Sparkles` + Bangla greeting (`--forest`); `h1` "{FirstName}, {Designation}"; sub-line `{employee_id} · {department} · {zone}` (muted 11 px).
   - Right: `12×12 rounded-2xl` avatar filled with `levelColor(role_level)` showing initials.

2. **Attendance banner** — `rounded-3xl p-5 shadow-lg`, `bg-gradient from-[--forest-deep] to-[--forest]`, white text:
   - Top row: date `Weekday, D Month` (11 px uppercase, opacity 80) + big `HH:MM` clock (display 3xl) + line "9h duty · 1h break expected".
   - Action button (right):
     - No check-in → `bg-[--lime] text-[--forest-deep]` **Check in** (`LogIn` icon).
     - Checked in, no check-out → white bg **Check out** (`LogOut`).
     - Both set → chip `bg-white/15` with `CheckCircle2` + "Day closed".
   - **Geofence strip** `rounded-xl bg-white/10 px-3 py-2 mt-4`:
     - `Inside ACI Centre` (ShieldCheck lime) when within 150 m.
     - `Location off — enable for auto check-in` (amber) when denied.
     - `GPS unavailable` on unsupported/error.
     - `Locating…` pulsing until first fix.
     - Otherwise `{dist} km from ACI Centre` + right-side accuracy `±{m}m`.
   - **Duty progress** row: three inline stats *In: HH:MM · Elapsed Xh Ym · Out: HH:MM*; 2.5 px height progress bar `bg-white/15` filled `--lime` at `dutyPct%`; footer row with Coffee "Break xx/60m" and "{pct}% of shift".

3. **Mini stats strip** — 3 `MiniStat` cards (rounded-2xl, small icon square top-left, big value, uppercase label):
   - Open tasks (forest) · Logs today (moss) · This month `{kpiPct}%` (lime).

4. **Quick actions** — 2-column grid; each pill card `rounded-2xl border` with square icon tile + title + subtitle:
   - Log activity → `/activities` (forest-deep tile + `Plus`)
   - My tasks → `/tasks` (lime tile + `ListTodo`, subtitle "{n} open")

5. **Achievement trend** card — `h-40` Recharts `LineChart` of last 6 KPI periods, line `--forest-deep` 2.5 px, dots `--lime`, axes muted 10 px, Y suffix `%`.

6. **Your open tasks** (if any) — max 4 rows: circular check button (border-forest, hover fills lime) → marks done; title, priority pill (amber/forest), deadline `d Mon` with clock icon.

7. **Today's timeline** (if activities logged) — up to 5 rows: 14 px mono start-time, 1 px vertical bar (`moss` normal, `amber-accent` if break), title + location.

8. **Team is working on…** — up to 6 recent activities from other users: coloured level dot + title + `name · category · location`.

### 2.B Observer Dashboard (L1–L12) — `observer-dashboard.tsx`

Identical greeting header, but sub-line reads **"Command view · {N} people in your chain"**.

1. **Command banner** — same gradient/rounded-3xl:
   - Big `{currentPct}%` display + subtitle "Team achievement this month".
   - Right: **Assign** button (lime pill w/ `Plus`) opens `QuickAssignDialog`.
   - 3-column `StatChip` grid: **On duty** `{n}/{total}` · **Logs today** `{n}` · **Open tasks** `{n}`.

2. **Team achievement trend** — `h-44` line chart with grid, same styling.

3. **Top performers this month** — `h-40` bar chart, `--forest` bars, tick formatter shows first name only, right link "Leaderboard →".

4. **Team open tasks** (up to 6): title, `{owner} · {designation}`, due date; per-row `ReminderButton` (bell icon in forest tint) that inserts a `task_comments` reminder row and toasts "Reminder sent".

5. **Team activity — today** feed (up to 8): each row is a `<Link to="/team/$userId">` — level dot + title + `{name · category · HH:MM · location}`, `ChevronRight` appears on hover.

**Quick Assign dialog** (shadcn `Dialog`):
- Title "Assign a task".
- Fields (stacked): **Assign to** (`Select` from full downline, options `L{lvl} · {name} — {designation}`), **Title** (required), **Description** (Textarea rows=3), 2-col grid **Priority** (Low/Medium/High/Urgent) + **Deadline** (date input).
- Submit button full-width forest-deep. Disabled until title+assignee set.

---

## 3. Daily Activity — `/activities`

**Observer branch** (levels 1–12): render empty-state card only — centred eye icon on forest tint, "Observer mode", copy explaining they don't log, CTA **Open team feed** → `/team`. No log button.

**Field branch** (13–17):

1. **Header row**: title "Daily Activity" (display 2xl forest-deep) + subtitle "9-hour duty · includes 1-hour break". Right-aligned **Log** button (forest-deep, `Plus`) opens dialog.

2. **Filter pill row** — horizontally scrollable chips (`overflow-x-auto`): All · Market Visit · Meeting · Sales Call · Service Follow-up · Reporting · Other/Break. Active chip is forest-deep filled; others white outline.

3. **Empty state**: centred card "No activities yet. Log your first one."

4. **Day groups** (sorted desc): each group has an uppercase forest heading (`Today` or `Thu, 3 Jul`) and, on the right, a computed strip:
   `Duty {H h M m}  ·  Coffee {break}  ·  Work {duty − break}` (forest-deep bold on the last).

5. **Activity cards** (`rounded-2xl border-l-4`; break rows use `--amber-accent` border + `amber-50/40` bg, normal rows `--moss`):
   - Left column: 14 px mono `start` over 10 px muted `end`.
   - Body: title, category chip (uppercase 9 px, forest-deep 10% bg), optional `Break · {m}m` chip (amber), description muted, location line with `MapPin`.

**Log dialog** (max-w-md):
Title "Log a new activity". Fields:
- Title (required, placeholder "e.g. Dealer visit — Bashundhara").
- 2-col: Start / End time inputs.
- 2-col: Category select / Break minutes (0–120).
- Live "Duration: {H h M m}" caption.
- Description (Textarea rows=2), Location, Date. Save button forest-deep full-width.

---

## 4. Tasks — `/tasks`

1. **Header**: "My Tasks" (2xl) + "Track your work and delegate to your team." If user has assignable reports (direct reports, or entire downline for observers), show **Assign task** button in `--brand-red` (=amber) with `Plus`.

2. **Tabs** (`Tabs`): *Assigned to me* / *Delegated by me* (second tab only when `canAssign`).

3. **Assigned to me** — vertical list of `Card p-4`:
   - Row: title + Priority pill + Status pill (fixed palette: low slate · medium blue · high orange · urgent red; status todo slate · in_progress blue · done green · overdue red).
   - Description muted, meta line "From {assigner}" + clock deadline.
   - Right: `Select` (w-36) changing status → To do / In progress / Done.

4. **Delegated by me** — compact single-row cards: title (truncated), `→ {assignee}`, priority + status pills.

5. **Assign dialog**:
   Fields Assign to (Select), Title (required), Description (rows=3), Priority + Deadline (2-col). Submit button `--navy-deep` (forest-deep) full-width.

**Assignment scope**:
- Observer: everyone in `get_descendants(me)`.
- Non-observer manager: direct reports (`manager_id = me`).

---

## 5. Team — `/team`

Header "My Team" (2xl forest-deep) + subtitle switches: observers see "Command view — everyone reporting under you.", others "Drill down through your team."

1. **Snapshot strip** (4-col `Snap` cards, rounded-2xl, tiny 7×7 icon tile in tone tint, big number, uppercase 9 px label):
   - Team (forest) · On duty (lime) · Logging (moss) · Avg KPI (forest).

2. **Search input** — full-width, leading `Search` icon, placeholder "Search name, role, or zone…", `rounded-xl`. Typing collapses tabs and shows a filtered `PersonCard` list.

3. **Tabs** (visible when search is empty):
   - Observers see: **Teams** · **Org tree** · **Roster** (grid-cols-3).
   - Others: **Org tree** · **Roster** (grid-cols-2). Default tab: observers → Teams; others → Org tree.

**Teams view (observers)** — one `TeamCard` per direct report (team lead):
- Forest-gradient header (rounded-2xl, no border): 11×11 white/15 initials tile linking to the lead; name + tiny lime dot when on-duty; sub-line `Layers L{lvl} · {designation} · {zone}` (with `MapPin`).
- Right: **View / Hide** toggle pill (white/15 bg, `ChevronRight` / `ChevronDown`).
- 4-col mini stats: **Size** `members+1` · **On duty** · **Logs** · **KPI** (`—` when null).
- Optional footer chip "{n} open tasks across team" (`ListTodo`).
- When expanded → white body listing `PersonCard`s for every member (sorted by level).

**Org tree** — dashed `border-l` recursive list, chevron toggles children (open by default while `depth<3`):
- Row: chevron (5×5), 2 px `levelColor` dot, name (13 px medium), designation (10 px muted), then right-aligned status:
  - On-duty pulse dot (`--lime`, ring).
  - KPI pill coloured by band: ≥100% lime · ≥80% moss · else amber.
  - Open-tasks count pill.
- Row is a `<Link>` to `/team/{userId}` with hover reveal `ChevronRight`.

**Roster** — flat list of `PersonCard`s (rounded-2xl, `levelColor` avatar 10×10, name + on-duty dot, `L{lvl} · designation · zone`, right-aligned KPI + tasks + logs counts).

---

## 6. Team member drill-down — `/team/$userId`

Rich per-employee page. Vertical stack.

1. **Back link** `← Team` (11 px muted).

2. **Profile hero** — rounded-3xl gradient card (`--forest-deep → --forest`), white text:
   - 14×14 initials tile (white/15 bg, ring 2 px white/25).
   - Name (display lg), `L{lvl} · designation`, meta line `ID {empId} · dept · MapPin zone`.
   - 4-col `BossStat` grid: **KPI %** · **Done %** · **Open** (amber tint if overdue>0) · **Present {n}/14**.
   - Contact row: Email button (`mailto:`) + Call button (`tel:`) if fields present — `bg-white/15` rounded-xl.

3. **Boss actions** (only when viewer is observer and not self): 2-col grid — **AssignTaskDialog** button + **QuickNudge** (nudge type dropdown: check-in / update / meeting; inserts a task_comments-like nudge).

4. **Attendance · last 14 days** card:
   - Right-aligned "{present} present" caption.
   - 14 vertical bars (one per day, `flex-1`): filled `--forest-deep` when present, `bg-slate-200` weekend (Fri/Sat), `bg-red-200` absent. Tooltip on hover shows date + status.

5. **Target vs Achieved** card — Recharts `BarChart` (Target `--moss`, Achieved `--forest-deep`, rounded corners) with legend, followed by a tiny `LineChart` showing % achievement (line `--lime`, dots `--forest-deep`).

6. **Open tasks** list (only if any):
   - Header "Open tasks · N" + red "N overdue" pill if applicable.
   - Rows show title, priority coloured (urgent red, high amber), deadline (red when past). Observer sees a `Bell` button per row → sends reminder comment.

7. **Today's timeline** (same styling as Dashboard timeline).

8. **Recent activity** — 12-row compact list: date (`MM-DD` muted), category chip, title, location.

9. **Leave feedback** card:
   - Star row (1–5) tapping to set rating; stars fill `--lime` when selected.
   - Textarea placeholder "Your feedback…".
   - **Send feedback** button forest-deep full-width; disabled until comment typed.

---

## 7. Reports — `/reports`

1. **Header** row: "Reports" (2xl forest-deep) + subtitle. Right: **Export CSV** outline button.

2. **Top performers card**:
   - Trophy icon (amber) + title.
   - 5-column header: `# · Employee · KPI % · Tasks % · Score` (11 px muted, border-b).
   - Up to 20 rows: rank, `levelColor` dot + name + designation, right-aligned tabular numbers, **Score** in bold amber.
   - Score formula: `round(pct * 0.7 + completionRate * 0.3)`.
   - Empty state: "No team members visible yet."

CSV export downloads `team-report.csv` with header `Name, Designation, Level, Department, Zone, KPI %, Task Completion %, Score`.

---

## 8. Growth — `/growth`

1. **Header** "My Growth" + subtitle.

2. **3-column stat grid** (`Card p-4 flex items-center gap-3`): each has a coloured 10×10 icon tile + label + big display number:
   - Average achievement (green tint · `Award`)
   - Trainings completed (teal tint · `GraduationCap`)
   - Feedback received (red tint · `Star`)

3. **Target vs achievement** — `h-64` `BarChart` (Target `--navy-soft`, Achieved `--brand-red`) with grid + legend.

4. **Two-column area** (lg):
   - **Trainings** — list of `{name} · {completed_date}` rows.
   - **Recent feedback** — for each feedback: bold sender name + `★` repeated `rating` times (red), then comment muted.

---

## 9. Admin — `/admin`

Visible only to `admin` role.

1. **Header**: red `Shield` + "Admin" title + subtitle.

2. **Employee directory** table (`Card p-5`, horizontally scrollable):
   Columns: Level (dot + `L{n}`) · Employee (name + employee_id) · Designation · Department · Zone · Email. Zebra-less rows with `border-b`.

3. **Role structure** card: 17 rows showing `L{n} · dot · Designation`, listing the entire `DESIGNATIONS` map. Explanatory line about navy→teal→green gradient.

---

## 10. Navigation logic

`useNav()` in `app-sidebar.tsx`:

**Observer (L1–L12)**:
`Home / Team / Assign (tasks) / Reports / Growth / [Admin]`

**Field (L13–L17)**:
`Home / Activity / Tasks / Growth / [Team]* / [Reports]* / [Admin]`
*Team/Reports appear only when user has `manager` or `admin` role.*

Active state: nav row `bg-sidebar-accent text-sidebar-accent-foreground font-medium` + right-side 1.5×4 rounded lime dot.

Mobile bottom nav shows the **first 5** items only; hidden nav items reachable via top-right `MoreHorizontal` sheet which slides in from the right with forest-deep bg.

---

## 11. State, data & interactions summary

| Event | Trigger | Backend effect |
|---|---|---|
| Auto check-in | GPS `watchPosition` reports inside 150 m of `(23.7639, 90.3934)` and no `check_in` today | `upsert attendance {check_in, status:'present'}`, toast "Auto check-in — welcome…" |
| Manual check-in/out | Banner buttons | same upsert / update |
| Auto check-out | User was inside, now outside | `update attendance {check_out}` |
| Log activity | Field user submits dialog | `insert activities` |
| Assign task | Observer/manager submits dialog | `insert tasks {status:'todo'}` |
| Change status | `Select` on task | `update tasks {status}` |
| Reminder | `Bell` button on team task | `insert task_comments {comment:'🔔 Reminder…'}` |
| Feedback | Member page Send feedback | `insert feedback {rating, comment}` |
| Sign out | Sidebar footer | `supabase.auth.signOut()` → `/auth` |

---

## 12. Replication checklist (per screen)

For each screen verify in order:
1. ✅ Route path + meta title exact (per §1–9).
2. ✅ Correct role branching (observer vs field).
3. ✅ Palette tokens only — no hard-coded hex.
4. ✅ Radii: 2xl for cards, 3xl for hero banners, xl for buttons/inputs, full for chips/pills.
5. ✅ Forest gradient uses `from-[--forest-deep] to-[--forest]` (or auth's `via-[--forest] to-[--forest-soft]`).
6. ✅ Level avatars filled with `levelColor(role_level)`, initials = first-two words' first letters.
7. ✅ Bangla greeting per hour band.
8. ✅ Bottom nav pinned with safe-area padding, top ribbon 1 px forest→moss→lime gradient present.
9. ✅ All toasts use `sonner` and copy strings match §11.
10. ✅ Iconography from `lucide-react` at sizes noted.

Match those and the app is a 1:1 replica.
