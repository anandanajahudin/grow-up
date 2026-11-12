#!/bin/bash
# Deploy grow-up ke grow-up.my.id (public_html)
# Pakai: bash ~/repositories/grow-up/deploy.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYPATH="$HOME/public_html"

cd "$REPO_DIR"
git pull --ff-only origin main

cp -R assets forms "$DEPLOYPATH"/
cp ./*.html .htaccess "$DEPLOYPATH"/

echo "Deployed: $(git log --oneline -1)"
