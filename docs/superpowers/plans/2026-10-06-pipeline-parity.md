# Pipeline Parity Implementation Plan

> **For agentic workers:** Use executing-plans inline, then requesting-code-review for a read-only review.

**Goal:** Make Jenkins and GitHub Actions run the same application test, build-selection, build, deployment, and response checks for comparison.

**Architecture:** Both orchestrators call shared shell scripts. Jenkins executes on its agent; GitHub Actions tests on its runner and executes the deployment scripts over SSH on the VPS. The successful-deployment baseline is stored in Git metadata rather than derived differently by each CI system.

**Tech Stack:** Node 22, POSIX shell, Docker Compose, Jenkins, GitHub Actions.

## Global Constraints

- Keep existing application and database data; never delete named volumes.
- Use Node 22 and `npm ci --include=dev` for both test paths.
- Use the same Compose file, `--pull --no-cache` builds, readiness timeout, and frontend/API response checker.
- Keep the user's GitHub SSH secret names. Do not hardcode credentials or interpolate their values into shell source.
- Make GitHub Actions manually triggered for sequential comparison with the existing automatic Jenkins job.
- Preserve prior changes and push the reviewed result to `main`, as authorized by the user in this session.

### Task 1: Shared pipeline commands

**Files:** `scripts/test-service.sh`, `scripts/prepare-environment.sh`, `scripts/select-builds.sh`, `scripts/build-services.sh`, `scripts/deploy-stack.sh`.

- [x] Add a service-test command that uses host Node only at major version 22, otherwise a Node 22 Docker container with the caller's UID/GID.
- [x] Generate the same private Compose environment for both orchestrators from `MYSQL_ROOT_PASS` and `MYSQL_PASS`, quoting special characters through Node in Docker.
- [x] Select builds from missing images, force-build input, shared/core paths, and the last successful deployed commit. Build both when the baseline is unavailable or unchanged.
- [x] Build selected services concurrently with `docker compose build --pull --no-cache`, waiting for both and failing before deployment if either build fails.
- [x] Deploy with `--wait --wait-timeout 180`, run the existing response checker, print logs, and record the successful commit only after all checks pass.

### Task 2: Orchestrator parity and comparison guide

**Files:** `Jenkinsfile`, `.github/workflows/deploy.yml`, `docs/pipeline-comparison.md`.

- [x] Replace duplicate Jenkins commands with the shared scripts and retain Jenkins credentials, parallel tests, force-build input, and serialized runs.
- [x] Set GitHub test Node to 22, call the same test scripts, pass secrets as SSH environment variables, checkout the tested commit, and call the same environment/build/deploy scripts.
- [x] Explain required GitHub secrets, workspace permissions, sequential full-build comparisons, and the differences in runner hardware and login method.

### Task 3: Verification and integration

- [x] Validate workflow structure with actionlint and syntax-check shared shell scripts.
- [x] Exercise build selection in a disposable Git repo and verify a failed build prevents deployment.
- [x] Verify generated credentials round-trip through Compose without shell evaluation or value changes, including dollar signs, quotes, and trailing backslashes.
- [x] Run both application suites through the shared test command and deployment checks against the existing healthy local stack.
- [x] Obtain read-only code review and address material findings.
- [x] Commit, fast-forward into `main`, push without force, and verify the remote commit.

## Verification record

- Both service suites ran through `scripts/test-service.sh` on Node 22.23.3 in a clean Linux container: 5 API and 4 frontend tests passed.
- Actionlint passed, including its available shell checks; all shared shell scripts passed POSIX shell syntax validation.
- Disposable Git/Docker-command behavior checks covered missing baseline, unchanged commit, application/core changes, force-build, missing images, invalid baseline, concurrent build failure, and failed response checks.
- A failed API build followed by a source revert and a documentation-only change forced both rebuilds; unsuccessful checks preserved the old successful baseline, while successful checks updated it and cleared the unfinished-attempt marker.
- Five credential cases (dollar signs, quotes and shell punctuation, trailing backslash, backslash/quote combinations, spaces) round-tripped through the actual Node writer and Docker Compose into a disposable container without changing values.
- The existing healthy local stack passed three rounds of HTML/API response checks and JSON validation at approximately 3-6 ms. No database volumes were deleted or replaced.
- Independent read-only code review completed; both material findings were fixed and re-reviewed.
- Live Jenkins/GitHub controller execution and VPS workspace permissions were not verified; the comparison guide documents the required credentials, trusted SSH fingerprint, and sequential execution.
