# What is new in this Taiga fork

This repository is a fork of [Taiga 6.8](https://taiga.io), maintained by Centro de Tecnologias Aplicadas - Itaipu Parquetec, a technology center in Brazil that uses Taiga to manage its software and IoT projects. The original code belongs to [Kaleidos and the taigaio project](https://github.com/taigaio), to whom we are grateful; this fork remains under the AGPL-3 license, with credits preserved.

We started from Taiga because it handles the agile day-to-day well. We adapted a few things for the institution's portfolio management:
* Split login screen to support corporate login;
* Epics now display completed progress and work in progress;
* Progress percentage on tasks, rolling up into stories and epics;
* Dependencies between cards;
* Start date, expected end date and actual end date on epics and projects;
* Planning percentage and impact on epics, snapshotted once a month;
* Story Points definition;
* T·IA: our intelligent agent;
* Emoji reactions.

This document lists, as topics, what was added. It lives in the front-end repository; the back-end one ([taiga-back](https://github.com/ta-iot/taiga-back)) carries a summary and points here.

Rules that guide everything that was done: the server decides (percentage, blocking, permission and dates are computed and validated in the back-end; the interface only reflects them); the percentage is computed, never typed in; a card blocked by a relation cannot be completed or deleted until the relation is resolved.

## What this fork adds

### Epics and progress

- **Partial progress per task status.** The project administrator sets, for each task status, a weight from 0 to 100 (or empty). A closed status counts as 100; an open status set to 100 is stored as 99 by the server, so that only closing counts as completed.
- **Percentage computed from task up to epic.** Every task, story and epic shows two percentages, completed and in progress, computed on the server: the task from its status, the story from the average of its tasks, the epic from the average of its stories. Creating, moving or deleting cards recomputes in cascade; no percentage is editable through the API.
- **Dates on the epic.** Every epic has a mandatory start date and expected end date; the completion date appears by itself when the epic is closed. An end date earlier than the start date is rejected by the server. The epic list gained the date columns and a progress bar with numbers.
- **Epic schedule with monthly snapshot.** A project menu shows the month-by-month evolution of the completed percentage, for planned and unplanned epics. Planned epics have a 100% ceiling on their sum; unplanned ones are open-ended. The administrator marks which epics enter the schedule and the impact of each one. A server command records a monthly snapshot of each epic; past months are never rewritten.

### Relations between cards

- **Dependencies between activities.** Issues, tasks, stories and epics in the same project relate to each other through fixed types: related to; blocks / blocked by; depends on / depended on by me; duplicated by / duplicate of; discovered while testing / led to discovery while testing. A card cannot relate to itself, each combination has only one active relation, and every creation, change, resolution and deletion enters the history of both cards. Permission is role-based; the API covers create, list, resolve and delete.
- **Blocking with real effect.** A card blocked by a relation is flagged on the boards, cannot move to a closed status (the server refuses and the interface returns the card to its original column) and cannot be deleted until the relation is marked as resolved. Taiga's original padlock does not undo a block created by a relation.

### Comments

- **Emoji reactions.** Project members react to comments on epics, stories, tasks and issues; each comment shows the emojis with their count and who reacted. One reaction per emoji per person; only whoever reacted can remove it; non-members get a 403.

### Sprint and boards

- **Totals and percentages on the sprint board.** Each column shows the total of tasks and the status percentage; a collapsed column shows the total per story; cards display partial progress. Along with it came: a button to clear filters, a sprint column and filter in the issue list, a checkbox custom field with autosave, the closing date on the sprint chart and a button to close the sprint faster.
- **Tasks do not change story by dragging.** On the sprint board, dropping a task on another story's row is blocked and the task returns to its origin, with a translated warning. Changing the story is still possible from the task detail, where it is recorded.

### Project and identity

- **Project dates.** The project has a start date, an expected end date and an end date, edited in the settings and shown on the timeline (with elapsed and remaining time) and in the project list. An end date earlier than the start date is rejected by the server.
- **Project list with status and dates** right on the screen, without opening each project.
- **Restricted project creation.** Only administrators and superusers create projects; a project is born private; the edit and delete status icons appear only to the project administrator. The server refuses anyone without permission.
- **Own identity.** Institutional logo and favicon on every screen and e-mail; a visual tag identifies the test and staging environments and never shows in production.
- **Default language pt-BR, with EN and ES.** The interface opens in Brazilian Portuguese, every new text exists in the three languages and the inherited texts were reviewed.

### Access

- **Login with two paths.** The login screen has the Corporate and External tabs. A corporate account authenticates against the institutional directory (LDAP) and the tool does not store that credential; an external account authenticates with a local credential. Both tabs go through reCAPTCHA when it is enabled, and each path refuses the other's account type.
- **Corporate account managed by the directory.** A corporate user cannot change e-mail or access credential in the tool; the server refuses even those who bypass the interface. An external user can change both.

### What the latest release delivered (home, carousel, guide and footer)

- **Translated public home, with language selector.** The landing page for unauthenticated visitors presents the instance and its features in the browser's language;
- **Manageable news carousel.** The home news can be added by the administrator through an interface in the header (next to the story points);
- **Story points guide.** A public route shows the team's scoring scale (Fibonacci), with examples per score and a shortcut in the header; the guide's translation was completed in the three languages.
- **Footer** on the home and on the login screen, with the institutional logos.

## Why there is no project discovery

Taiga's "Discover" page was removed from the interface. In this instance every project is born private and there are no public projects, so the page would always be empty. Whoever installs the fork and wants public projects can re-enable the discovery shortcuts in the navigation bar: the route and the API remain in the code.

## How the carousel works for whoever installs

The home news carousel is born empty in any installation: there is no sample data or initial load. An admin registers the slides (image, title, description and order) on a management screen reachable through a header icon, activates the ones to publish and reorders them. Reading is public: the home shows only the active slides, in the stored order, and, when there is no active slide or the server does not respond, the space is hidden. Limits validated on the server: title up to 255 characters, description up to 500, image up to 2 MB and only recognized image formats.

## Note on corporate access

Login through the institutional directory (LDAP) and reCAPTCHA are specific to this installation and configurable by whoever installs the fork. The behavior is as described above: the corporate tab validates the user against the directory without storing the credential in the tool, the external tab uses a local credential, and both require the reCAPTCHA check when it is on. Without a configured directory, the fork behaves like the original Taiga for local accounts.
