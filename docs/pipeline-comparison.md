# Comparing Jenkins and GitHub Actions

Both pipelines use the same scripts:

| Step | Shared command |
| --- | --- |
| Test API and frontend in parallel | `sh scripts/test-service.sh 01_api` / `02_frontend` |
| Prepare the same private Compose environment | `sh scripts/prepare-environment.sh` |
| Validate Compose | `docker compose config --quiet` |
| Select services from the last successful deployment | `sh scripts/select-builds.sh true\|false` |
| Build selected services in parallel | `sh scripts/build-services.sh true\|false true\|false` |
| Deploy, wait for readiness, and verify real HTTP responses | `sh scripts/deploy-stack.sh` |

Tests use Node 22 and `npm ci --include=dev`. The test helper uses host Node only when its
major version is 22; otherwise it uses `node:22-alpine` with the caller's UID/GID. Both
application builds use the same Dockerfiles and `--pull --no-cache` on the VPS. Deployment
waits up to 180 seconds for readiness, then checks HTML and actual frontend/API JSON.
Database volumes are preserved.

The successful-deployment commit is stored at `git rev-parse --git-path ci-last-success`.
Both CI systems use it to select services with the same rules. Missing/invalid baseline or
an unchanged commit causes a full build; missing service images cause that service to build.
Changes to either application's directory select that service. Compose, environment,
pipeline, root package, attributes, or shared script changes select both. A failed build or
failed response check does not advance the baseline.
An unfinished attempt is tracked in Git metadata too; the next run rebuilds both services
after failure/cancellation, since an unsuccessful build may already have changed image tags.

## Configure credentials

Jenkins requires string credentials `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD`.
GitHub Actions requires repository secrets:

- `VPS_HOST`: the VPS IP or hostname.
- `VPS_USER`: the SSH account that has Docker access and read/write access to the checkout,
  its Git metadata, and `.env`.
- `VPS_SSH_KEY`: the private SSH key for that account.
- `VPS_HOST_KEY_FINGERPRINT`: the trusted SSH server key fingerprint (`SHA256:...`),
  verified through the VPS console or an existing trusted connection. The workflow requires
  it before forwarding credentials. On the VPS, `ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
  -E sha256` prints the ECDSA server fingerprint; verify the fingerprint for the host key
  algorithm negotiated by the SSH action if the server has multiple key types.
- `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD`: the same database passwords used by Jenkins
  and by the existing database. Updating `.env` does not rotate an existing MySQL user's password.
- `VPS_APP_DIR` (optional): an existing Git checkout, default
  `/var/lib/jenkins/workspace/docker-jenkins-pipeline`.

Using the same checkout path also preserves the existing Compose project name and volume
selection. If changing directories, set `COMPOSE_PROJECT_NAME` to the existing project name
in the SSH account's environment before running the shared scripts; otherwise Compose may
create a separate stack and database volume.

If Jenkins owns the checkout and private `.env`, a different SSH account needs appropriate
access. Do not make `.env` world-readable to work around that. The SSH account must also be
able to fetch this Git repository. The workflow does not create a checkout or install SSH keys.

## Run a comparison

1. Finish one pipeline run before starting the other; neither CI platform's concurrency
   setting locks jobs in the other platform, and both can access the same workspace.
2. In Jenkins, use **Build with Parameters** and set `FORCE_BUILD_ALL=true`.
3. In GitHub, open **Actions → CI/CD Pipeline (GitHub Actions) → Run workflow**, select
   `main`, and set `force_build_all=true`.
4. Use the same commit for both runs. The Actions deployment checks out the commit that was
   tested, rather than whichever commit happens to be newest when SSH connects.
5. Compare test, build, and deploy/check durations as separate parts, plus the response
   times printed by `scripts/check-deployment.sh`.

GitHub Actions is manually triggered for this comparison; Jenkins retains its SCM polling.
Pause Jenkins's SCM trigger or temporarily disable the Jenkins job while testing Actions,
then finish the Actions run before enabling Jenkins again. This avoids automatic workspace
updates during the Actions deployment. To use Actions automatically later, add a `push`
trigger for `main` and disable the Jenkins deployment job.

The orchestration and login method remain different: GitHub tests on its hosted runner and
deploys over SSH; Jenkins tests and deploys on its selected agent. Both must target the same
VPS Docker daemon for build/deploy comparisons. Runner architecture, CPU, npm cache, and
network can affect test times, so matching Node versions and commands does not establish
identical benchmark hardware.
