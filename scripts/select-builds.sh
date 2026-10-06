#!/bin/sh
set -eu

case "${1:-false}" in
    true) build_api=true; build_frontend=true ;;
    false) build_api=false; build_frontend=false ;;
    *) echo 'Force-build input must be true or false' >&2; exit 2 ;;
esac

if [ -z "$(docker compose images -q api)" ]; then build_api=true; fi
if [ -z "$(docker compose images -q frontend)" ]; then build_frontend=true; fi

marker=$(git rev-parse --git-path ci-last-success)
if [ -f "$(git rev-parse --git-path ci-deploy-in-progress)" ]; then
    # A failed/cancelled attempt may have retagged images without passing checks.
    build_api=true
    build_frontend=true
fi
previous=''
if [ -f "$marker" ]; then previous=$(cat "$marker"); fi
case "$previous" in
    ''|*[!0-9a-fA-F]*) previous='' ;;
esac

if [ -z "$previous" ] || ! git cat-file -e "${previous}^{commit}" 2>/dev/null; then
    build_api=true
    build_frontend=true
else
    changed=$(git diff --name-only "$previous" HEAD)
    if [ -z "$changed" ]; then
        # A rerun on the same commit should perform a real build in both systems.
        build_api=true
        build_frontend=true
    else
        if printf '%s\n' "$changed" | grep -Eq '^(docker-compose\.yml|Jenkinsfile|package\.json|\.gitattributes|\.env[^/]*|scripts/.*|\.github/workflows/.*)$'; then
            build_api=true
            build_frontend=true
        fi
        if printf '%s\n' "$changed" | grep -q '^01_api/'; then build_api=true; fi
        if printf '%s\n' "$changed" | grep -q '^02_frontend/'; then build_frontend=true; fi
    fi
fi

printf 'BUILD_API=%s\nBUILD_FRONTEND=%s\n' "$build_api" "$build_frontend"
