#!/bin/sh
set -eu

case "${1:-}" in
    01_api|02_frontend) cd "$1" ;;
    *) echo 'Usage: sh scripts/test-service.sh 01_api|02_frontend' >&2; exit 2 ;;
esac

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 &&
    [ "$(node -p 'process.versions.node.split(".")[0]')" = 22 ]; then
    node --version
    npm ci --include=dev
    npm test
else
    docker run --rm --user "$(id -u):$(id -g)" \
        -e HOME=/tmp -e npm_config_cache=/tmp/npm-cache \
        -v "$(pwd):/app" -w /app node:22-alpine \
        sh -c 'node --version && npm ci --include=dev && npm test'
fi
