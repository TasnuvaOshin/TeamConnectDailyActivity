# ACI Team Connect — Full Project Documentation

**Product:** Team Connect — ACI Motors Marketing
**Purpose:** A single command center for daily activity, tasks, attendance, KPIs and performance tracking across all **17 levels** of ACI Motors Bangladesh's marketing team — from Managing Director down to Product Executive.

**Stack:** React 19 + TanStack Start (Vite 7) · TailwindCSS v4 · shadcn/ui · TanStack Router + Query · Lovable Cloud (Supabase) for auth, Postgres, RLS · Recharts for graphs · lucide-react icons.
**Delivered clients:** Web (React) + Flutter (Web/Android/iOS) mirror repo.

---

## 1. Concept & Core Idea

ACI Motors' marketing chain has **17 designations**. Not everyone in the chain does the same job:

- **Levels 13–17 (Field roles — Product Manager → Product Executive):** These are the "doers." They log daily activities, mark attendance via GPS at the ACI Centre, complete assigned tasks, and submit reports.
- **Levels 1–12 (Observer / Boss roles — Managing Director → Senior Product Manager):** They do **not** log personal daily activity. Instead they **observe, analyse, assign work, remind and evaluate** their entire downline. Their whole UI is analytics-first.

The app auto-detects a user's `role_level` and renders the correct experience.

### The 17 Levels (`src/lib/hierarchy.ts`)

| Lvl | Designation | Mode |
|-----|-------------|------|
| 1 | Managing Director | Observer |
| 2 | Deputy Managing Director | Observer |
| 3 | Executive Director | Observer |
| 4 | Chief Business Officer | Observer |
| 5 | Business Director | Observer |
| 6 | Deputy Business Director | Observer |
| 7 | Business Manager | Observer |
| 8 | Senior GM | Observer |
| 9 | GM | Observer |
| 10 | Marketing Manager / DGM | Observer |
| 11 | Assistant Marketing Manager | Observer |
| 12 | Senior Product Manager | Observer |
| 13 | Product Manager | Field |
| 14 | Deputy Product Manager | Field |
| 15 | Assistant Product Manager | Field |
| 16 | Senior Product Executive | Field |
| 17 | Product Executive | Field |

Rule in code:
```ts
export const OBSERVER_MAX_LEVEL = 12;
export const isObserver = (level) => level > 0 && level <= 12;
```

Each level maps to a color on a navy → teal → green gradient (`levelColor()`), used everywhere avatars/badges appear so hierarchy is visually obvious.

---

## 2. Data Model (Lovable Cloud / Postgres)

All tables live in `public`, RLS-enabled, with explicit GRANTs.

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `profiles` | One row per employee | `id`, `full_name`, `employee_id`, `email`, `role_level` (1–17), `designation`, `department`, `zone`, `manager_id` (self-FK → chain), `photo_url`, `phone`, `is_active` |
| `user_roles` | Separate role table (prevents privilege-escalation) | `user_id`, `role` (`admin` / `manager` / `employee`) |
| `activities` | Time-boxed daily activity log | `user_id`, `activity_date`, `start_time`, `end_time`, `category` (reporting / market_visit / sales_call / meeting / service_followup / other), `title`, `location`, `break_minutes` |
| `attendance` | GPS check-in / check-out | `user_id`, `date`, `check_in_at`, `check_out_at`, `check_in_lat/lng`, `check_out_lat/lng`, `source` (`auto_gps` / `manual`) |
| `tasks` | Assigned work | `assigned_to`, `assigned_by`, `title`, `description`, `priority`, `status` (`todo` / `in_progress` / `done`), `deadline` |
| `task_comments` | Threaded task chat | `task_id`, `user_id`, `body` |
| `kpis` | Monthly targets vs achieved | `user_id`, `period` (YYYY-MM), `metric_name`, `target`, `achieved` |
| `feedback` | Reminders / nudges bosses send down | `from_user`, `to_user`, `body`, `severity` |
| `trainings` | Training records | `user_id`, `title`, `date`, `status` |

**Access control model**
- `has_role(uuid, app_role)` — SECURITY DEFINER function used inside every RLS policy (no recursion).
- Every user reads their own rows.
- Managers/observers read rows for anyone in their downline (walked via `manager_id`).
- `admin` (level 1) sees everything.

### The seeder (`supabase/functions/seed-demo-org/index.ts`)
Creates 17 demo accounts (`aci-001@teamconnect.demo` … `aci-017@teamconnect.demo`, password `Demo@1234`) — one per level, linked as a manager chain, plus:
- 8-slot **timed day** for today + yesterday (09:00 → 18:00, 45m lunch + 15m tea = 1h break, 9h duty).
- 6 months of monthly KPIs in BDT.
- A cascading chain of sample tasks (each level assigns down to the next).

---

## 3. Duty & Attendance Rules

- **Standard duty:** 09:00 → 18:00 (9 hours).
- **Break allowance:** 1 hour total (45 min lunch + 15 min tea).
- **ACI Centre geofence:** ~150 m radius around HQ coordinates. Entering the fence triggers an **auto check-in**; leaving triggers **auto check-out**. Stored in `attendance` with `source='auto_gps'`.
- Manual override is available on the dashboard for edge cases (GPS denied, etc.).
- Late / early / on-time is derived from `check_in_at` vs 09:00.

---

## 4. Routing & App Shell

File-based routing (TanStack Start). All authenticated pages sit under `src/routes/_authenticated/` behind an `ssr:false` auth gate that redirects unauthenticated users to `/auth`.

```
/                → redirect (auth or /dashboard)
/auth            → sign-in card + demo account picker
/_authenticated  → layout: sidebar (desktop) / bottom nav (mobile) + forest ribbon
  /dashboard     → role-aware landing page
  /activities    → my day / team activities
  /tasks         → task inbox + assign
  /team          → org tree · teams · roster · member drill-down
  /team/$userId  → individual member dashboard
  /reports       → charts & exports
  /growth        → KPI trends & performance curves
  /admin         → admin-only (level 1)
```

### Shell (`src/routes/_authenticated/route.tsx`)
- Desktop: fixed `AppSidebar` with logo, role badge, nav, sign-out.
- Mobile: `MobileTopBar` + `MobileBottomNav`.
- A 1-px **forest gradient ribbon** (deep-green → moss → lime) sits under the top bar as the ACI brand accent.
- `Toaster` (sonner) mounted globally for feedback.

---

## 5. Screen-by-Screen Walkthrough

### 5.1 `/auth` — Sign-in
Split layout:
- **Left panel (desktop only):** dark navy gradient, brand block (Car icon + "Team Connect · ACI Motors · Marketing"), tagline "Daily activity, tasks and performance across all 17 levels."
- **Right panel:** email + password form. Below it a **"Try a demo account"** list with 4 pre-filled buttons (L1 MD, L9 GM, L13 PM, L17 Executive) — clicking one auto-fills the form.
- After sign-in → `/dashboard`.

### 5.2 `/dashboard` — Role-Aware Landing
Reads `useMyProfile()` → branches:

#### If `isObserver(level)` → renders `<ObserverDashboard/>` (`src/components/observer-dashboard.tsx`)
Analytics command center for bosses:
- **Header:** greeting, current designation, downline size, "as of today" timestamp.
- **KPI ribbon:** 4 tiles — On duty now / Late today / Open tasks / Avg KPI achievement %.
- **Team pulse:** live grid of direct reports — avatar (level color), name, live status dot (checked-in / on break / off), today's log count.
- **Attention list:** who hasn't checked in yet, who has overdue tasks, who missed reports.
- **Quick actions:** "Assign task", "Send reminder", "Broadcast note" (writes to `tasks` / `feedback`).
- **KPI heatmap:** last 6 months × direct reports, colored by achievement %.
- **Recent activity feed:** streaming of latest activity rows from downline.

#### If field role (L13–17) → renders the field dashboard
- **Attendance card:** GPS status pill (Inside ACI Centre / Outside), Check-in time, elapsed duty, break used vs 60m remaining. Manual check-in/out fallback.
- **Today's timeline:** vertical strip of 8 activity slots — reporting, dealer visit, sales calls, lunch, meeting, service follow-up, tea, EOD report. Each slot is add/edit-able.
- **My tasks:** compact list of open items with priority chip + deadline.
- **My KPI card:** current month target vs achieved with progress bar.
- **Reminders from boss:** unread feedback entries.

### 5.3 `/activities`
- **Field users:** manage their own timed day — add, edit, delete slots. Category dropdown, start/end pickers, location, break minutes. Validation guarantees ≤ 60 min of breaks and total duty ≥ 9h.
- **Observers:** filter view — pick a downline member or a whole team, pick a date, see everyone's day laid out. Category filter, zone filter, CSV export.

### 5.4 `/tasks`
- **Inbox tab:** tasks assigned to me (todo / in_progress / done tabs, priority badges, deadline countdown).
- **Assigned tab:** tasks I created — status per assignee, follow-up button.
- **Compose:** modal to pick assignee(s) from downline, title, description, priority, deadline. On save: inserts into `tasks`, sends a reminder feedback row.
- **Task detail:** side sheet with description, status changer, threaded `task_comments`.

### 5.5 `/team` — the boss's team explorer
Three tabs (Observers see all three; field users see only Roster):

1. **Teams** (default for observers)
   - Iterates over direct-report leads; for each lead a `TeamCard` shows: avatar, name, role, level, district, live status, and aggregated **team stats** (Size / On duty / Logs today / Open tasks / Avg KPI).
   - "View" toggle expands to show every subordinate in that team as a `PersonCard` sorted by role level, with their own MiniStats.
   - Uses `collectDownline()` helper to iteratively walk `manager_id` chains.
2. **Org tree** — full 17-level hierarchical tree, collapsible branches, color-coded avatars.
3. **Roster** — flat searchable table (name, ID, role, department, zone, status, phone, email).

### 5.6 `/team/$userId` — Member Drill-down
An "individual dashboard" the boss opens by clicking anyone in the team:
- **Header:** big avatar, level color ring, name, designation, employee ID, department, zone, live status.
- **Contact strip:** Call / SMS / Email / WhatsApp buttons (uses `tel:` / `sms:` / `mailto:` / `wa.me`).
- **Attendance strip:** last-7-days check-in/out timeline with punctuality badges.
- **Today's activities:** the full 8-slot timeline for this member.
- **Task board:** their open + recently closed tasks; "Assign new task" here writes directly to them.
- **KPI charts:** last 6 months, target vs achieved bars.
- **Feedback thread:** reminders / notes the boss has sent + their responses.
- **Downline mini-tree:** if this member is also a manager, shows their team below.

### 5.7 `/reports`
- Date-range picker + zone/department filters.
- Charts (Recharts): daily activity counts, category mix (pie), attendance punctuality, task completion rate, KPI progress.
- Export as CSV.

### 5.8 `/growth`
- Trailing 6-month KPI trend per user or team (line chart).
- Achievement % vs target curve, moving average.
- Rank table — top movers, biggest drops.
- Used by observers for talent decisions and by field staff to see their own trajectory.

### 5.9 `/admin` (level 1 only, `admin` role)
- Seed / reset demo data.
- Manage roles (grant/revoke admin / manager).
- Deactivate a profile.
- View auth accounts and last-sign-in.

---

## 6. Component Library

- **`AppSidebar` / `MobileTopBar` / `MobileBottomNav`** — the adaptive shell.
- **`ObserverDashboard`** — the boss analytics screen.
- **`TeamCard` / `PersonCard` / `MiniStat`** — reusable cards for team & roster views.
- **`Toaster`** (sonner) — global toast notifications.
- **shadcn primitives** — Card, Button, Input, Label, Tabs, Sheet, Dialog, Select, Badge, Avatar, Progress used everywhere.

All colors, gradients, shadows are **design tokens** in `src/styles.css` (e.g. `--navy-deep`, `--navy`, `--forest-deep`, `--moss`, `--lime`, `--brand-red`). No hardcoded hex in components.

---

## 7. Workflows End-to-End

### 7.1 A Product Executive's day (L17)
1. Walks into ACI Centre → phone GPS detects geofence → auto check-in written to `attendance`.
2. Opens `/dashboard` — sees timeline seeded with 8 slots; edits actuals as the day unfolds.
3. Opens `/tasks` inbox — completes items, marks status, comments.
4. Leaves the building → auto check-out. Duty hours + break usage calculated.
5. Submits EOD report as the final activity slot.

### 7.2 A GM's day (L9, observer)
1. Opens `/dashboard` → observer view. Sees which of the ~200 downline members haven't checked in, who's late, who has overdue tasks.
2. Opens `/team` → "Teams" tab → picks a team lead → expands and clicks a struggling executive.
3. On the drill-down, reviews their 7-day punctuality, task board and KPI trend.
4. Uses "Assign task" or "Send reminder" — writes to `tasks` / `feedback`.
5. `/reports` for zone-level rollups; `/growth` for talent review.

### 7.3 Task cascade
`assigned_by → assigned_to` with priority + deadline. Assignee gets it in `/tasks` inbox and dashboard preview; status changes flow back into the boss's observer dashboard KPI ribbon in real time (TanStack Query invalidations).

---

## 8. Security

- Supabase Auth (email + password; social providers optional).
- RLS on **every** table; policies use `has_role()` (SECURITY DEFINER) to avoid recursion.
- `user_roles` is a separate table — never a column on `profiles`.
- Service role key is server-only; the browser only ever holds the publishable key.
- Server functions that touch privileged data go through `requireSupabaseAuth` middleware.

---

## 9. Flutter Mirror App

A parallel Flutter project (`/mnt/documents/aci_team_connect_flutter.zip`) mirrors this exact UX for Web + Android + iOS:
- **State:** Riverpod. **Routing:** go_router with auth guards. **Backend:** `supabase_flutter` pointed at the same Lovable Cloud project.
- Reuses the same tables and RLS — no separate backend.
- GPS geofencing implemented in `lib/util/geo.dart` (150 m ACI Centre radius).
- Adaptive shell: sidebar on desktop/web, bottom nav on mobile.
- Same 10+ screens including multi-tab Team view and member drill-down with tap-to-call/SMS/email/WhatsApp actions.

Run:
```bash
unzip aci_team_connect_flutter.zip && cd aci_team_connect
flutter pub get
flutter run -d chrome   # or android / ios
```

---

## 10. Demo Accounts

Password for all: `Demo@1234`

| Email | Level | Role | View |
|-------|-------|------|------|
| `aci-001@teamconnect.demo` | 1 | Managing Director | Observer + admin |
| `aci-009@teamconnect.demo` | 9 | GM | Observer |
| `aci-012@teamconnect.demo` | 12 | Senior Product Manager | Observer (lowest boss) |
| `aci-013@teamconnect.demo` | 13 | Product Manager | Field (top of field) |
| `aci-017@teamconnect.demo` | 17 | Product Executive | Field (bottom) |

Log in as different levels to see how the whole app re-shapes itself around role.

---

## 11. Extensibility

- **New activity category:** add to the `category` enum + seeder + category dropdown.
- **New role level:** the code is capped at 17 by design; changing means updating `DESIGNATIONS`, `levelColor()`'s interpolation, and RLS downline walks.
- **Push notifications / email reminders:** wire a Lovable Cloud edge trigger on `tasks` / `feedback` inserts.
- **Multi-centre geofences:** promote the single ACI Centre coordinate to a `centres` table and match user's zone → centre.
