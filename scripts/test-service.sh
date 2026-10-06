#!/bin/sh
set -eu

case "${1:-}" in
    01_api|02_frontend) service_dir=$1 ;;
    *) echo 'Usage: sh scripts/test-service.sh 01_api|02_frontend' >&2; exit 2 ;;
esac

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pipeline-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
# Complete the archive first so a producer failure cannot be hidden by tar or Docker.
git archive --output="$test_dir/source.tar" HEAD

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 &&
    [ "$(node -p 'process.versions.node.split(".")[0]')" = 22 ]; then
    mkdir "$test_dir/source"
    tar -xf "$test_dir/source.tar" -C "$test_dir/source"
    cd "$test_dir/source/$service_dir"
    node --version
    npm ci --include=dev
    npm test
else
    docker run --rm -i --user "$(id -u):$(id -g)" \
        -e HOME=/tmp -e npm_config_cache=/tmp/npm-cache \
        node:22-alpine sh -c '
            set -eu
            mkdir -p /tmp/test-source
            tar -x -C /tmp/test-source
            cd "/tmp/test-source/$1"
            node --version
            npm ci --include=dev
            npm test
        ' sh "$service_dir" < "$test_dir/source.tar"
fi
