# Comparing Jenkins and GitHub Actions

See the [Thai Jenkins setup guide](jenkins-simple-th.md) and [pipeline walkthrough](pipeline-guide-th.md).

| Item | Jenkins | GitHub Actions |
| --- | --- | --- |
| Entry point | Two jobs: API and frontend, SCM polling | One manually triggered workflow |
| Definition | `Jenkinsfile`, `Jenkinsfile.frontend` | `.github/workflows/deploy.yml` |
| Tests | On the VPS agent, NodeJS tool named `Node22` | Hosted runner, setup-node 22 |
| Dependency installation | `npm ci --include=dev` | `npm ci --include=dev` |
| Deployment | Each job deploys its own application | SSH to VPS, build/deploy both applications |
| Environment | Jenkins credentials → workspace `.env` | `/var/lib/jenkins/docker-jenkins.env`, readable by checkout owner |
| Compose project | `docker-jenkins-pipeline` | `docker-jenkins-pipeline` |
| Readiness | Compose health checks, then curl | Compose health checks, then curl |

No external `.sh` files or deployment markers are used. Jenkins stages contain short commands and Jenkins steps directly. NodeJS plugin and a Node 22 installation named `Node22` are required for Jenkins.

GitHub secrets: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_HOST_KEY_FINGERPRINT`, and optional `VPS_APP_DIR`. GitHub reads database settings from the server-side environment file. Jenkins uses Secret text credentials `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD`; both stores must match the existing database.

The checkout must already exist on the VPS. If the SSH account differs from its owner, GitHub uses noninteractive sudo to run deployment as that owner. That account must be able to read the shared environment file, use Docker, and fetch the repository.

Run the API Jenkins job before the frontend job on the first deployment. Run one CI deployment at a time: neither platform locks deployments in the other platform. Use the same commit when comparing. Both systems use the same Dockerfiles, but test machines and caches differ, so total times need not match.

Default HTTP checks use ports 3001 and 3000. Update the pipeline URLs if using other ports. The Compose file fixes the project name to `docker-jenkins-pipeline`. Existing MySQL volumes are retained; neither pipeline implements automatic rollback.
