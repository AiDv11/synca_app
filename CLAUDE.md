# Synca

University group project coordination app. Built for **CT124-3-2-MAE, Group 17, APU**.

Synca helps student groups plan, assign and track coursework tasks, keep evidence of who
actually did what, and give module staff a high-level view of how each group is doing —
without exposing the group's private working content.

## Stack

- **Flutter** (Dart) — mobile app
- **Firebase Authentication** — sign in / sign up
- **Cloud Firestore** — data store
- **MVVM** — Model / View / ViewModel architecture
- Firebase project: `synca-app-a7809`

## Roles

The app has three roles. Every screen and every Firestore read should be written with the
current user's role in mind.

**Group Member**
- Claim tasks from the group's task list
- Upload proof of work (evidence for a completed task)
- See their own contribution timeline

**Group Leader**
- Assign and reassign tasks to members
- Group dashboard (progress, workload spread)
- At-risk flags (tasks or members falling behind)

**Module Coordinator**
- View-only submission health across groups
- **Never sees private group content** — no task details, no uploaded proof, no chat.
  Only aggregate/health-level information. This is a hard rule, not a preference.

## Colours

| Name        | Hex       | Use                          |
| ----------- | --------- | ---------------------------- |
| Navy        | `#0D1B3D` | Primary / headers            |
| Teal        | `#00B7B3` | Accent / actions             |
| Sky blue    | `#5BAEF5` | Secondary highlights         |
| Light       | `#F5F7FA` | Backgrounds / surfaces       |
| Charcoal    | `#1F2937` | Body text                    |

Defined in `lib/src/core/theme/app_colors.dart`. Use those constants — do not hardcode hex
values in widgets.

## Wireframes (from approved proposal, section 3.3.2)

These four screens were signed off in the proposal. **All UI must match them** — the same
sections, in the same order, with the same copy and controls. Text in quotes is the exact
wording. A deviation is a change to the approved proposal, not just a code change, so
raise it before building it.

Anything not specified here (spacing, corner radius, icon choice) is free, as long as it
uses the brand colours above.

### Figure 1 — Landing page

Public screen, shown before sign-in.

```
┌──────────────────────────────────┐
│              Synca               │  title
│                                  │
│   Coordinate group projects,     │  headline
│       without the chaos          │
│                                  │
│   <subtext: task ownership,      │
│    progress tracking,            │
│    deadline visibility>          │
│                                  │
│  ┌────────────────────────────┐  │
│  │          Log In            │  │  filled
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │          Register          │  │  outlined
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ For Group Members          │  │
│  │ claim tasks, upload proof, │  │
│  │ track your contribution    │  │
│  ├────────────────────────────┤  │
│  │ For Group Leaders          │  │
│  │ live dashboard, at-risk    │  │
│  │ task alerts, reassignment  │  │
│  ├────────────────────────────┤  │
│  │ For Module Coordinators    │  │
│  │ high-level submission      │  │
│  │ health across all groups   │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

- Title: "Synca"
- Headline: "Coordinate group projects, without the chaos"
- Subtext covers task ownership, progress tracking and deadline visibility
- "Log In" (filled) above "Register" (outlined) — that order
- Three role cards, in the order Members → Leaders → Coordinators

### Figure 2 — Group Member

```
┌──────────────────────────────────┐
│ My Tasks                         │  header
├──────────────────────────────────┤
│ ┌──────────────────────────────┐ │
│ │ My contribution this project │ │
│ │ ████████████░░░░░░░░░░░░░░░░ │ │  progress bar
│ │ X of Y tasks completed       │ │
│ │                View Timeline │ │
│ └──────────────────────────────┘ │
│                                  │
│ My Claimed Tasks                 │  section heading
│ ┌──────────────────────────────┐ │
│ │ Task title        [ chip ]   │ │
│ │ due text                     │ │
│ ├──────────────────────────────┤ │
│ │ Task title        [ chip ]   │ │
│ │ due text                     │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │       + Claim a Task         │ │
│ └──────────────────────────────┘ │
├──────────────────────────────────┤
│  Tasks   Group  Timeline Profile │  bottom nav
└──────────────────────────────────┘
```

- Header: "My Tasks"
- Contribution card: "My contribution this project", progress bar,
  "X of Y tasks completed" and a "View Timeline" link
- Section heading: "My Claimed Tasks"
- Each row: title, due text, status chip on the right
- Button: "+ Claim a Task"
- Bottom nav: Tasks, Group, Timeline, Profile

### Figure 3 — Group Leader

```
┌──────────────────────────────────┐
│ Team Dashboard                   │  header
├──────────────────────────────────┤
│ ┌────────┐ ┌────────┐ ┌────────┐ │
│ │  68%   │ │   3    │ │   5    │ │  summary cards
│ │progress│ │at risk │ │members │ │
│ └────────┘ └────────┘ └────────┘ │
│                                  │
│ Task Overview                    │
│ ┌──────────────────────────────┐ │
│ │ Task title        [ chip ]   │ │
│ │ owner - status detail        │ │
│ ├──────────────────────────────┤ │
│ │ Task title        [ chip ]   │ │  at-risk rows
│ │ owner - status detail        │ │  emphasised
│ └──────────────────────────────┘ │
│                                  │
│ ┌─────────────┐ ┌──────────────┐ │
│ │Reassign Task│ │  + Add Task  │ │
│ └─────────────┘ └──────────────┘ │
├──────────────────────────────────┤
│ Dashboard Tasks Members  Profile │  bottom nav
└──────────────────────────────────┘
```

- Header: "Team Dashboard"
- Three summary cards: overall progress %, at-risk task count, member count
- Section heading: "Task Overview"
- Each row: title, "owner - status detail", status chip; at-risk rows are visually
  emphasised (they must stand out from the rest of the list)
- Buttons: "Reassign Task" and "+ Add Task"
- Bottom nav: Dashboard, Tasks, Members, Profile

### Figure 4 — Module Coordinator

Read-only. See the hard rule under **Roles** — this screen shows health signals only.

```
┌──────────────────────────────────┐
│ Module Overview                  │  header
├──────────────────────────────────┤
│ Sorted by risk level    N groups │
│                                  │
│ ( On Track )( At Risk )(Critical)│  filter chips
│                                  │
│ ┌──────────────────────────────┐ │
│ │ Group name          On Track │ │
│ │ high-level reason            │ │
│ ├──────────────────────────────┤ │
│ │ Group name          At Risk  │ │
│ │ 3 tasks overdue              │ │
│ ├──────────────────────────────┤ │
│ │ Group name          Critical │ │
│ │ no activity for 8 days       │ │
│ └──────────────────────────────┘ │
│                                  │
│ Tap a group to view progress %   │
│ and overdue count only.          │
├──────────────────────────────────┤
│    Overview   Flagged   Profile  │  bottom nav
└──────────────────────────────────┘
```

- Header: "Module Overview"
- Sorted by risk level; group count shown
- Filter chips: On Track / At Risk / Critical
- Each row: group name, high-level reason (overdue count or inactivity), status label
- Note on screen: "Tap a group to view progress % and overdue count only"
- Bottom nav: Overview, Flagged, Profile

The "reason" text is the boundary in practice: "3 tasks overdue" is a health signal and is
allowed; "Literature Review is overdue" names private group content and is not.

## Project structure

```
lib/
  main.dart                    app entry point + Firebase init
  firebase_options.dart        generated by FlutterFire CLI — do not edit by hand
  src/
    core/
      theme/                   colours, text styles, ThemeData
      constants/               fixed values (route names, collection names, enums)
      services/                Firebase wrappers (auth service, firestore service)
      utils/                   small helpers (validators, formatters)
    modules/
      common/
        auth/                  login, register, forgot password
        onboarding/            first-run screens, role selection
      role/
        member/                Group Member screens + view models
        leader/                Group Leader screens + view models
        coordinator/           Module Coordinator screens + view models
```

Empty folders hold a `.gitkeep` file so git tracks them. Delete the `.gitkeep` once real
files land in that folder.

## MVVM in this project

- **Model** — a plain Dart class matching a Firestore document (e.g. `Task`, `AppUser`),
  with `fromMap` / `toMap`.
- **View** — the widget. Builds UI, sends user actions to the ViewModel. No Firestore
  calls inside a View.
- **ViewModel** — holds screen state, calls services, tells the View to rebuild.
- **Service** — the only layer that talks to Firebase directly, lives in `core/services`.

Rule of thumb: if a widget file imports `cloud_firestore`, something is in the wrong layer.

## Current status

**Group Member module — built, run and verified end to end.** Tested in Chrome and on an
Android Pixel 6 API 34 emulator.

Verified journey:

1. Register a new account
2. Join a group by code from the Group tab
3. Claim a task from the claim sheet
4. Move that task through its statuses to Completed
5. Timeline renders the created / claimed / completed rows with correct relative times

**Firestore indexes.** Two composite indexes exist on `/tasks`:

| Fields | Used by |
| ------------------- | ---------------------- |
| `ownerUid`+`deadline` | `streamTasksForUser` |
| `groupId`+`deadline`  | `streamTasksForGroup` |

**Not done yet:**

- **Group Leader** and **Module Coordinator** modules are still unbuilt — placeholder
  dashboards only.
- `firestore.rules` is written and committed but **not deployed and not tested**. The
  live database is still running whatever rules preceded it.

## Working notes

- The developer is **new to Flutter**. Explain what new code does and why — especially
  Flutter/Dart concepts (widgets, state, `Future`/`async`, streams, `const`) — rather than
  just handing over finished files.
- Do not modify `main.dart` unless asked.
- Do not edit `firebase_options.dart` by hand; it is regenerated by `flutterfire configure`.

## Commands

```bash
flutter pub get      # install dependencies
flutter run          # run on connected device / emulator
flutter analyze      # static analysis (lint errors)
flutter test         # run tests
```
