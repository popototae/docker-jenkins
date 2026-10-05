#!/usr/bin/env bash
# Ubuntu host triage. Collects evidence; does not stop services or execute discovered files.
set -u
umask 077

if [ "${EUID}" -ne 0 ]; then
    echo "Run with sudo: sudo bash scripts/collect-vps-evidence.sh" >&2
    exit 1
fi

private_dir=$(mktemp -d /var/tmp/vps-evidence.XXXXXXXX) || exit 1
chmod 700 "${private_dir}"
report_dir="${private_dir}/report"
mkdir -m 700 "${report_dir}" || exit 1

capture() {
    local name=$1
    shift
    printf 'Collecting %s\n' "${name}"
    timeout 30 "$@" > "${report_dir}/${name}.txt" 2>&1
    local result=$?
    printf '\n[collector exit status: %s]\n' "${result}" >> "${report_dir}/${name}.txt"
}

capture host bash -c 'date -u; uname -a; uptime; cat /etc/os-release; who -a'
capture processes ps auxww
capture sockets ss -lntup
capture connections ss -ntup
capture recent-logins last -Fai -n 100
capture failed-logins lastb -Fai -n 100
capture ssh-journal journalctl -u ssh -u sshd --since '7 days ago' --no-pager
capture auth-journal journalctl _COMM=sudo --since '7 days ago' --no-pager
capture auth-files bash -c 'for file in /var/log/auth.log /var/log/auth.log.1; do if [ -f "$file" ]; then echo "FILE: $file"; tail -n 3000 "$file"; fi; done'
capture accounts getent passwd
capture privileged-accounts bash -c 'awk -F: '\''$3 == 0 {print $1 ": UID=" $3 ", home=" $6 ", shell=" $7}'\'' /etc/passwd; getent group sudo; getent group docker'
capture ssh-key-fingerprints bash -c 'find /root /home -xdev -type f -name authorized_keys -print -exec stat -c "%y %U %G %a %n" {} \; -exec ssh-keygen -lf {} \;'
capture systemd-services systemctl list-unit-files --type=service --no-pager
capture systemd-running systemctl list-units --type=service --state=running --no-pager
capture systemd-timers systemctl list-timers --all --no-pager
capture systemd-local-files bash -c 'find /etc/systemd/system -xdev -type f -print -exec stat -c "%y %U %G %a %n" {} \; -exec head -c 32768 {} \;'
capture user-crontabs bash -c 'while IFS=: read -r account rest; do result=$(crontab -u "$account" -l 2>/dev/null) || continue; printf "USER: %s\n%s\n" "$account" "$result"; done < /etc/passwd'
capture system-cron bash -c 'for path in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/rc.local /var/spool/cron/crontabs; do if [ -e "$path" ]; then find "$path" -xdev -type f -print -exec head -c 32768 {} \;; fi; done'
capture recent-tmp-files bash -c 'find /tmp /var/tmp /dev/shm -xdev -maxdepth 3 -type f -mtime -14 -printf "%TY-%Tm-%TdT%TH:%TM:%TS %u %m %s %p\n"'
capture binary-package-integrity dpkg -V bash coreutils openssh-server openssh-client sudo systemd procps iproute2
capture docker-containers docker ps -a --no-trunc
capture docker-images docker images --digests --no-trunc
capture docker-host-access bash -c 'for id in $(docker ps -aq); do docker inspect --format '\''name={{.Name}} image={{.Config.Image}} created={{.Created}} user={{.Config.User}} privileged={{.HostConfig.Privileged}} pid_mode={{.HostConfig.PidMode}} network={{.HostConfig.NetworkMode}} cap_add={{json .HostConfig.CapAdd}} security={{json .HostConfig.SecurityOpt}} mounts={{json .Mounts}}'\'' "$id"; done'
capture docker-processes bash -c 'for id in $(docker ps -q); do echo "CONTAINER: $id"; docker top "$id"; done'
capture docker-events docker events --since 168h --until "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
capture docker-journal journalctl -u docker --since '7 days ago' --no-pager

cat > "${report_dir}/README.txt" <<'TEXT'
This archive contains live-host triage data and may contain sensitive command arguments,
addresses, account names, service configuration, and credentials in cron/service files.
Share privately and redact credentials before pasting excerpts.

Exit status 124 means a check exceeded 30 seconds. Missing commands/logs are not evidence
of a clean host. Compose down removes containers and normally their container-local logs
and files; Docker events retain limited history. Current container configuration cannot
prove the removed frontend container had the same privileges or mounts.

Unexpected SSH logins/keys, privileged accounts, cron/systemd persistence, or suspicious
host processes are evidence requiring investigation. Known Jenkins/Coolify services,
Docker socket mounts, and agent processes can be legitimate; compare with known setup.

A compromised host can falsify these results. Clean output is NOT proof of no compromise.
Preserve a provider disk snapshot and inspect it from a trusted machine when needed.
Do not execute, kill, or delete suspicious files/processes before preserving evidence.
TEXT

archive="${private_dir}/evidence.tar.gz"
if ! tar -czf "${archive}" -C "${report_dir}" .; then
    echo "Could not create archive. Evidence remains at ${report_dir}" >&2
    exit 1
fi
sha256sum "${archive}" > "${archive}.sha256"
chmod 600 "${archive}" "${archive}.sha256"
printf '\nEvidence directory: %s\nArchive: %s\nChecksum: %s.sha256\n' "${report_dir}" "${archive}" "${archive}"
echo "Share privately. Review/redact sensitive data before pasting any output."
