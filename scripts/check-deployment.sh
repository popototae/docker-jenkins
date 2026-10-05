#!/bin/sh
set -eu

# Resolve actual published ports, including settings supplied only through Compose's .env.
published_port() {
    port=$(docker compose port "$1" "$2" | awk -F: 'NR == 1 {print $NF}')
    case "${port}" in
        ''|*[!0-9]*) echo "No published TCP port found for $1:$2" >&2; return 1 ;;
    esac
    printf '%s\n' "${port}"
}

api_port=$(published_port api 3001)
frontend_port=$(published_port frontend 3000)

docker compose ps

for round in 1 2 3; do
    echo "Deployment response check ${round}/3"
    for url in \
        "http://127.0.0.1:${api_port}/health" \
        "http://127.0.0.1:${api_port}/attractions" \
        "http://127.0.0.1:${frontend_port}/" \
        "http://127.0.0.1:${frontend_port}/api/attractions"; do
        echo "Checking ${url}"
        curl -4 -fsS --connect-timeout 3 --max-time 5 -o /dev/null \
            -w 'status=%{http_code} first_byte=%{time_starttransfer}s total=%{time_total}s\n' \
            "${url}" || {
                docker compose logs --tail=50 frontend api
                exit 1
            }
    done
done

# An HTML error page returning 200 must not count as a working API proxy.
docker compose exec -T frontend node <<'NODE'
(async () => {
    const response = await fetch('http://127.0.0.1:3000/api/attractions', {
        signal: AbortSignal.timeout(5000),
    });
    if (!response.ok || !Array.isArray(await response.json())) {
        throw new Error('Frontend API proxy did not return an attractions array');
    }
    console.log('Frontend API proxy returned valid JSON.');
})().catch(error => {
    console.error(error.message);
    process.exit(1);
});
NODE

echo "All deployment checks passed."
