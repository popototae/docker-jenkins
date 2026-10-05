# VPS investigation and patched deployment

## What the available evidence means

The frontend log contains an unexpected `Error: x` digest whose Base64 content is the
container environment. This project does not intentionally generate that output. Together
with the deployed Next.js 15.5.0 App Router vulnerability, this strongly suggests exploitation
inside the frontend container. It does not establish that the VPS host was taken over or
that this specific request caused the observed 145-second HTTP response.

`docker compose down` removes the stack's containers and network. Without `-v`, named
database volumes normally remain. Removing a container also normally removes its local
logs and writable filesystem, so some incident evidence is now unavailable. It does not
remove host persistence, processes outside these containers, or stolen credentials.

Do not bring up the old frontend image. Keep the suspected app inaccessible from the
Internet while investigating. Preserve a provider disk snapshot before cleanup where
possible. Do not purge logs, prune Docker resources, or run unknown discovered scripts.

## Collect host evidence

Copy the script from the trusted local checkout to the VPS. From Windows PowerShell:

```powershell
scp "D:\Work\docker jenkins\scripts\collect-vps-evidence.sh" ubuntu@138.2.70.183:~/collect-vps-evidence.sh
```

On the Ubuntu VPS:

```bash
sudo bash ~/collect-vps-evidence.sh
```

The script writes a private directory and `.tar.gz` under `/var/tmp`, prints their actual
paths, and leaves services, firewall rules, credentials, and existing files unchanged.
Each command is limited to 30 seconds. Check exit-status markers: skipped/timed-out checks
need follow-up. The report is sensitive; share privately and redact credentials before
pasting excerpts. Use the archive's printed path when copying it with `sudo cp`, then
`sudo chown ubuntu:ubuntu` and `chmod 600` if downloading through the Ubuntu account.

Investigate these report files first:

| Report | Warning signs | Expected context |
| --- | --- | --- |
| `ssh-journal.txt`, `recent-logins.txt` | Successful SSH login from an unrecognized address/time | Compare with your own access, VPN, automation, and cloud console |
| `ssh-key-fingerprints.txt` | An authorized key you did not install | Match fingerprints with your own public keys and known automation |
| `privileged-accounts.txt`, `accounts.txt` | Unknown UID 0 account or unexpected `sudo`/`docker` membership | Docker group access is effectively host administration |
| `processes.txt`, `connections.txt` | Unknown process running on the host or unexplained external connections | Coolify, Jenkins, databases, container processes, and cloud agents can be normal |
| `user-crontabs.txt`, `system-cron.txt`, `systemd-local-files.txt` | Unknown persistence, especially downloads/commands from temporary paths | Compare with services and jobs you configured |
| `recent-tmp-files.txt` | Recently created unexplained executables/scripts | Record paths and hashes; do not execute the files |
| `docker-host-access.txt` | Suspected app with `privileged`, host PID/network, host mounts, or `/var/run/docker.sock` | Coolify may legitimately mount the socket; remaining containers do not describe a removed frontend |
| `binary-package-integrity.txt` | Unexpected changes to SSH, sudo, shell, process/network binaries | Configuration changes can be legitimate; investigate each mismatch |

This repository's frontend configuration has no host filesystem bind mount, Docker socket,
host PID namespace, or privileged mode. That reduces obvious paths to the host; it does not
prove what the removed deployed container used or exclude a kernel/runtime escape.

If there are host compromise indicators, isolate the VPS using provider controls, preserve
a snapshot, and rebuild on a fresh trusted OS image. Restore reviewed application source
and necessary database data; do not restore unknown services, cron jobs, host scripts, or
old container images. Clean live checks cannot prove a host is safe because an attacker
with host privileges can alter both logs and the tools used to inspect it. A fresh VPS is
the highest-assurance recovery when host integrity cannot be established.

Rotate credentials accessible to the compromised application. If host takeover is suspected,
also rotate VPS/provider, Jenkins, Git/registry, Coolify, database, and application credentials
from a trusted device after isolating the old host. Update existing-database credentials with
SQL as well as Jenkins: changing Compose `MYSQL_PASSWORD` does not change an existing user's
password in the persistent MySQL volume.

`01_api/.env.local` was previously tracked in Git. It is now removed from tracking while
the local working file is preserved, and `01_api/.env.example` contains placeholders.
Removing a tracked secret does not remove it from old commits. Rotate the database password
that was committed, even if the repository is private; do not restore that password on the
recovered VPS. Repository history cleanup is a separate coordinated operation.

## Deploy the reviewed patched source

Do this on a host whose trust has been assessed. The checked-in pipeline no longer has a
database-reset parameter or any volume-deletion command, including when Jenkins retains an
old `CLEAN_VOLUMES=true` parameter value. Automatic global Docker prune commands are removed.

The frontend dependency versions are Next.js 15.5.27 and React 19.1.9. Compatible PostCSS 8
is overridden to 8.5.29 and the lockfile resolves patched Sharp. Application images use Node
22 LTS, run as non-root, drop Linux capabilities, prevent new privileges, and use read-only
application filesystems. These controls reduce exposure; they do not make a vulnerable
application safe or clean an already-compromised host.

Review and commit the local files, then push through your normal trusted Git workflow. Run
Jenkins with `FORCE_BUILD_ALL=true` for the first remediation deployment. Both Docker builds
pull supported base images and avoid previous build caches. Compose waits for database,
API, frontend, and proxied data readiness. Docker Compose v2.20+ is recommended for these
readiness options; verify the VPS with `docker compose version`.

To verify on the VPS from the Jenkins checkout:

```bash
cd /var/lib/jenkins/workspace/docker-jenkins-pipeline
docker compose ps
docker compose exec -T frontend node -p "require('next/package.json').version"
docker compose exec -T frontend id
sh scripts/check-deployment.sh
docker compose logs --since=10m frontend api
```

The frontend should be healthy, Next.js should report `15.5.27`, the application user should
be non-root, and three rounds of HTTP checks should complete within each request's five-second
limit. Check from a browser/public network too: local health does not verify provider firewall,
external routes, or user-browser behavior. If delays remain, correlate a slow request's time
with host/container/network logs rather than raising the timeout again.

Production `npm audit --omit=dev` is clean after these dependency changes. Full dependency
audit still reports five high-severity development-tool findings stemming from the same
unpatched `braces` nested-pattern stack-exhaustion advisory through Next's ESLint plugin.
Those packages are build/lint tools, not dependencies included in the standalone runtime.
Do not feed untrusted glob patterns to them. The registry has no patched `braces` release
at the time of verification; a forced downgrade of the Next ESLint stack is not applied.

## Primary references

- [Next.js React2Shell advisory and credential rotation](https://nextjs.org/blog/CVE-2025-66478)
- [React security follow-up](https://react.dev/blog/2025/12/11/denial-of-service-and-source-code-exposure-in-react-server-components)
- [Docker Compose startup readiness](https://docs.docker.com/compose/how-tos/startup-order/)
- [Node.js release support](https://nodejs.org/en/about/previous-releases)
