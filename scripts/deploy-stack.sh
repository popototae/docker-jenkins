#!/bin/sh
set -eu

trap 'status=$?; if [ "$status" -ne 0 ]; then docker compose logs --tail=50 frontend api >&2 || true; fi' EXIT

docker compose up -d --remove-orphans --wait --wait-timeout 180
sh scripts/check-deployment.sh
docker compose logs --tail=20

# Both orchestrators compare against the last deployment that passed real HTTP checks.
git rev-parse HEAD > "$(git rev-parse --git-path ci-last-success)"
rm -f "$(git rev-parse --git-path ci-deploy-in-progress)"
echo 'Deployment and response checks passed.'
