#!/bin/sh
set -eu

: "${MYSQL_ROOT_PASS:?Set MYSQL_ROOT_PASS in the CI credentials store}"
: "${MYSQL_PASS:?Set MYSQL_PASS in the CI credentials store}"
export MYSQL_ROOT_PASS MYSQL_PASS

# Use the same writer on both CI systems, without putting secrets into shell source.
docker run --rm -i --user "$(id -u):$(id -g)" \
    -e MYSQL_ROOT_PASS -e MYSQL_PASS \
    -v "$(pwd):/workspace" -w /workspace node:22-alpine node <<'NODE'
const fs = require('node:fs');
const values = {
    MYSQL_ROOT_PASSWORD: process.env.MYSQL_ROOT_PASS,
    MYSQL_DATABASE: 'attractions_db',
    MYSQL_USER: 'attractions_user',
    MYSQL_PASSWORD: process.env.MYSQL_PASS,
    MYSQL_PORT: '3306',
    API_PORT: '3001',
    DB_PORT: '3306',
    FRONTEND_PORT: '3000',
    NODE_ENV: 'production',
    API_HOST_INTERNAL: 'http://api:3001',
};
const quote = value => {
    if (!value || /[\r\n\0]/.test(value)) throw new Error('Invalid single-line environment value');
    return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '$$$$') + '"';
};
const text = Object.entries(values).map(([key, value]) => `${key}=${quote(value)}`).join('\n') + '\n';
fs.writeFileSync('.env', text, { mode: 0o600 });
fs.chmodSync('.env', 0o600);
console.log('Compose environment prepared.');
NODE
