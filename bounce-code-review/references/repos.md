# Repos and dependencies

Snapshot from each repo's `package.json` on 2026-10-21. Pins and versions drift, so **re-read the consumer's `package.json` before relying on any row**. A stale row makes a check silently pass.

## Shared packages

| Package | Kind | Consumed by |
|---|---|---|
| `ts-types` | TypeScript types and runtime enums/constants | dashboard, dashboard-api, api, admin-api, api-core, cron-api, ai-server, firestore-functions, fieldwork-processing |
| `api-core` | Backend behaviour: helpers, defaults, thresholds | dashboard, dashboard-api, api, admin-api, cron-api, ai-server, firestore-functions, fieldwork-processing, bounce-tools |
| `dashboard-core` | Shared React components (JS) | dashboard, admin-v2 |
| `config-manager`, `bounce-logger` | Config/secrets and logging | Most services |

- `web-surveys` depends on **neither** `ts-types` nor `api-core`. Sweeping it for them is noise.
- `admin-v2` has no direct `ts-types` or `api-core` dependency. It sees them only through `dashboard-core`, one hop later.
- **Two pinning styles.** dashboard, dashboard-api, api and admin-api pin `ts-types`/`api-core` as local `file:` tarballs (e.g. `file:../ts-types/bounceinsights-ts-types-1.489.0.tgz`). A consumer PR using a new shared symbol must bump that tarball version. cron-api, ai-server, firestore-functions and fieldwork-processing use registry caret ranges, which can lag far behind. Check which style the consumer uses before deciding whether it even sees the change.

## Frontend↔backend pairs

| Changed repo | Grep these consumers |
|---|---|
| ts-types | every repo in its row above |
| api-core | every repo in its row above |
| dashboard-core | dashboard, admin-v2 |
| dashboard-api | dashboard |
| dashboard | dashboard-api |
| api | web-surveys, app |
| web-surveys | api |
| admin-api | admin-v2 |
| admin-v2 | admin-api |
| cron-api | dashboard-api |

Pairs are listed both ways because a contract can break from either side. Any repo not in this table is still covered by the org-wide `gh search code` sweep.

## Frontend stacks

| Repo | React | Language | Data layer | Router |
|---|---|---|---|---|
| dashboard | 17 | JavaScript | Redux Toolkit 1.9 + axios, React Query **v4** in places | react-router-dom 5 |
| web-surveys | 16 | JavaScript | Redux Toolkit 1.6 + axios | react-router-dom 5 |
| admin-v2 | 16 | JavaScript | axios, no store library | react-router-dom 5 |
| dashboard-core | (peer) | JavaScript | none | none |
| app | React Native 17 | JavaScript | redux 4 + redux-thunk, axios 0.18 | react-native-navigation 7 (Wix) |
| fieldwork-dashboard | 18 | TypeScript | check `package.json` | check `package.json` |

Most frontends have **no typechecker**. `fieldwork-dashboard` is the exception.

dashboard, web-surveys and admin-v2 use `i18next` + `react-i18next` 11 with locale folders under `src/locales/` (dashboard and admin-v2: `de`, `en`, `es`, `fr`).

## Backends

TypeScript on Express (TS 4.7–5.x; check `tsconfig` target before suggesting newer built-ins), Firestore for persistence, Redis for caching. Python services: retrieval-engine-v2, py-types, ingestion-lambdas.

Active repos without a row above include orchestrator, survey-ingestion-engine, exports-api, response-engine, auth, survey-verifier, client-projects, imports-api and bounce-crons. They may consume the shared packages. Check their `package.json` when a change could reach them.
