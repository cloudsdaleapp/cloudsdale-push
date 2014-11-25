#!/bin/sh
set -e

APP_HOME=${APP_HOME:-.}

echo "Step 1: Install dependencies"
echo "---> Running $(which npm)"
npm install --silent

echo "Step 2: Start application"
exec "$@"