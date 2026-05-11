# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Monorepo for "拾光视频" (Memo Video) — an AI-powered short video creation app targeting elderly users. Contains four co-located projects without a formal monorepo tool:

| Project | Directory | Stack | Dev Port |
|---|---|---|---|
| Flutter mobile app | `lib/` (root) | Flutter 3.x / Dart 3.6.x / GetX | — |
| Backend API | `backend/` | Python 3.11 / FastAPI / Tortoise ORM | 9999 |
| Admin dashboard | `frontend/` | Vue 3 / Vite / Naive UI / Pinia | 3100 |
| H5 web app | `elderly-video-app/` | Vue 3 / Vite / Pinia | 3000 |

Production: `api.cylonai.cn` (backend), `cylonai.cn` (H5 + admin). Deployed on Tencent CVM via systemd + Nginx.

## Common Commands

### Flutter App (run from repo root)

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=AUTH_SERVER_BASE_URL=https://api.cylonai.cn
flutter build apk --release --dart-define=AUTH_SERVER_BASE_URL=https://api.cylonai.cn
```

### Backend (run from `backend/`)

```bash
python run.py                              # Start dev server (port 9999, hot reload)
ruff check ./app                           # Lint
black ./ && isort ./ --profile black       # Format
black ./ --check && isort ./ --profile black --check  # Format check
pytest -vv -s --cache-clear ./             # Test
aerich migrate                             # Generate DB migration
aerich upgrade                             # Apply DB migrations
```

### Admin Frontend (run from `frontend/`)

```bash
pnpm i
pnpm dev
pnpm build
eslint --ext .js,.vue .
```

### H5 Web App (run from `elderly-video-app/`)

```bash
npm install
npm run dev
npm run build
```

## Flutter App Architecture

Clean Architecture with GetX. State management via GetX controllers + reactive bindings. Networking via Dio with Bearer token auth. Tokens stored in `flutter_secure_storage`, general data in `GetStorage`.

```
lib/
├── app/                  # Routes, theme, constants, global binding
├── core/                 # Errors, services (storage, download), utils
├── data/                 # ApiClient (Dio), ApiService, models, repository impls
├── domain/               # Abstract repository interfaces
├── presentation/         # Feature pages with controllers + bindings
└── shared/widgets/       # Shared UI components
```

**Startup flow**: `main()` → `GetStorage.init()` → `GetMaterialApp` with `AppBinding` (registers services, repos, auth controller) → LaunchPage checks login state → routes to login or home.

**Server URL injection**: Always via `--dart-define=AUTH_SERVER_BASE_URL=...` at build time. Default in `lib/app/constants.dart` points to production. The `.env.example` is for backend deployment reference only — Flutter never reads it.

**Third-party code**: `third_party/chewie/` is a forked/customized video player.

## Backend Architecture

FastAPI with Tortoise ORM. SQLite locally, MySQL in production. Auth via JWT Bearer tokens.

- `app/api/` — Route handlers (v1 auth, tasks, points, voice, releases)
- `app/controllers/` — Business logic (task controller is the largest at ~49KB)
- `app/models/` — Tortoise ORM models
- `app/services/` — External integrations: video gateway, LLM (Moonshot/Kimi), speech (Xunfei), Tencent COS storage, model catalog
- `app/schemas/` — Pydantic request/response schemas

External services: Moonshot/Kimi LLM, video generation API, Tencent COS (object storage), Xunfei ASR (speech recognition).

## Deployment

`build-deploy-stage.ps1` packages backend + H5 + admin dist into `.deploy-stage/` for server upload. Production backend runs as a systemd service (`deploy/tencent-cvm/momenta-backend.service`). Nginx config at `deploy/tencent-cvm/nginx.momenta.conf`.

## Key Files

- `lib/app/constants.dart` — App version, server URL, polling intervals
- `lib/app/routes.dart` — All named routes
- `lib/app/app_binding.dart` — Global DI registration
- `lib/data/api/api_service.dart` — All API endpoint definitions
- `backend/app/controllers/task.py` — Core video task business logic
- `backend/app/services/` — All external service integrations
- `backend/app/settings/config.py` — Backend configuration
