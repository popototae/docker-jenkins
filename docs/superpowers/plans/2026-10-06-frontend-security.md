# Frontend Security and Deployment Implementation Plan

> **For agentic workers:** Execute in this session with executing-plans and a read-only review using requesting-code-review. Keep the user's existing dependency updates.

**Goal:** Prepare patched local images and a deployment that preserves the database, checks the actual frontend data path, and provides a read-only VPS investigation script.

**Architecture:** Retain Next.js 15.5 and React 19.1, fix vulnerable transitive dependencies, use a supported Node LTS image, and gate Compose startup on health checks. Collect host evidence without executing or deleting suspicious files.

**Tech Stack:** Next.js, React, Express, MySQL, Docker Compose, Jenkins, Bash.

## Global Constraints

- Preserve existing edits to frontend package files.
- Initial scope was local work only, with reviewable uncommitted changes. On 6 October 2026 the user explicitly authorized committing and pushing the fixes so Jenkins can build and deploy them.
- Integrate the reviewed changes into `main` and push to `origin/main` without rewriting history. Do not rotate credentials or delete database volumes.
- Do not claim that clean live-host checks prove a VPS is uncompromised.
- Use an isolated Compose project and disposable credentials for integration verification.

### Task 1: Patch dependencies and container runtime

**Files:** `02_frontend/package.json`, `02_frontend/package-lock.json`, both Dockerfiles, `02_frontend/.dockerignore`.

- [x] Keep `next`/`eslint-config-next` at `15.5.27` and `react`/`react-dom` at `19.1.9`.
- [x] Resolve patched Sharp within Next's supported optional range and override pinned PostCSS with compatible patched PostCSS 8.
- [x] Run `npm.cmd --prefix 02_frontend audit --omit=dev --json`; address production vulnerabilities without a forced major framework upgrade.
- [x] Change build/runtime images from `node:20-alpine` to supported `node:22-alpine`; run the API as `node`.
- [x] Exclude `.env*` from frontend Docker context and retain `.env.example`; set internal API host explicitly during production build.
- [x] Stop tracking the API credential file while keeping the local file; provide a placeholder example and document rotation of the previously committed password.

### Task 2: Make deployment preserve data and check readiness

**Files:** `Jenkinsfile`, `docker-compose.yml`, `scripts/check-deployment.sh`.

- [x] Remove the database-reset parameter and `docker compose down -v` from the pipeline; serialize deployments using `disableConcurrentBuilds()`.
- [x] Install test dependencies with `npm ci --include=dev`; use Node 22 in fallback test containers.
- [x] Prepare environment before `docker compose config --quiet`.
- [x] Add MySQL SQL readiness, API DB health, and frontend HTML plus proxied JSON checks; use `condition: service_healthy`.
- [x] Reduce application container permissions with non-root users, dropped capabilities, no-new-privileges, and read-only filesystems with bounded temporary storage.
- [x] Deploy using `docker compose up -d --remove-orphans --wait --wait-timeout 180`.
- [x] Repeat bounded HTTP checks three times and validate proxied attractions are JSON arrays. Retain logs on failure and remove global Docker prune operations.

### Task 3: Provide VPS evidence collection and recovery guidance

**Files:** `scripts/collect-vps-evidence.sh`, `docs/vps-incident-response.md`.

- [x] Collect process/network, login, accounts, SSH authorized-key fingerprints, cron/systemd persistence, recent temporary files, remaining container privilege/mount metadata, and Docker event evidence.
- [x] Store results in a private temporary directory/archive; do not alter services, credentials, firewall rules, or suspicious files.
- [x] Document limitations after `compose down`, warning signs, expected Coolify/Jenkins privileges, secret rotation scope, and when to rebuild the VPS from a trusted image.
- [x] Document `sudo bash scripts/collect-vps-evidence.sh` and patched deployment verification commands.

### Task 4: Verify and review

- [x] Run API tests and frontend tests/lint; investigate failures rather than masking them.
- [x] Run shell syntax checks and Compose validation without printing credentials.
- [x] Build the two application images using the changed Dockerfiles.
- [x] Start a separate `codex-security-check` Compose project on unused test ports with disposable credentials; verify health, the frontend HTML, and `/api/attractions`.
- [x] Verify the frontend is non-root with a read-only application filesystem and production dependency versions match the lockfile.
- [x] Remove only disposable test resources created during this session.
- [x] Request read-only code review, resolve material findings, and report local changes, validation, and VPS actions still required.


## Verification record

- API unit tests: 5 passed; frontend unit tests: 4 passed.
- Frontend lint: 0 errors, 1 pre-existing raw-image warning.
- Production audits: frontend and API report 0 vulnerabilities. Full frontend audit retains 5 development-only findings from unpatched braces; absent from standalone runtime and documented.
- Compose config and both shell syntax checks passed; independent read-only review completed with material findings fixed.
- Both Node 22 application images built successfully; isolated MySQL/API/frontend startup reached healthy status.
- Three rounds of real HTTP checks passed at approximately 3-14 ms; proxied JSON validated.
- Runtime UID 1001, read-only filesystem EROFS, writable cache, and no braces/Jest/Next ESLint plugin in standalone runtime verified.
- Negative integration test: frontend HTML still returned 200 after stopping the disposable API, while the actual frontend health check and deployment checker both failed as required.
- Collector executed successfully in a disposable network-disabled Ubuntu 24 container and created private directory/archive/checksum; unavailable tools were recorded without aborting collection.
- Only disposable test project resources were removed. Existing local stack was then rebuilt and updated to patched images using its original database volume, which was created before this session.
- Existing API credential file remains locally present but is ignored; its removal from tracking is recorded in commit `452e5f6`. No secret contents were printed.
- The initial verification involved no remote VPS action, push, or commit. Jenkins DSL was reviewed locally; no live Jenkins controller validation was available.
- Before the authorized integration, API and frontend tests were rerun: 5 API tests and 4 frontend tests passed. `origin/main` was fetched and remained at `346946f`; the earlier read-only review reported no remaining issues.
