#!/bin/sh
set -eu

case "${1:-}: ${2:-}" in
    'true: true'|'true: false'|'false: true'|'false: false') ;;
    *) echo 'Usage: sh scripts/build-services.sh true|false true|false' >&2; exit 2 ;;
esac

# Keep this marker on failure/cancellation so a source revert cannot reuse failed images.
git rev-parse HEAD > "$(git rev-parse --git-path ci-deploy-in-progress)"

api_pid=''
frontend_pid=''
if [ "$1" = true ]; then
    docker compose build --pull --no-cache api &
    api_pid=$!
fi
if [ "$2" = true ]; then
    docker compose build --pull --no-cache frontend &
    frontend_pid=$!
fi

failed=false
if [ -n "$api_pid" ] && ! wait "$api_pid"; then failed=true; fi
if [ -n "$frontend_pid" ] && ! wait "$frontend_pid"; then failed=true; fi
if [ "$failed" = true ]; then
    echo 'A service build failed; deployment was not started.' >&2
    exit 1
fi
