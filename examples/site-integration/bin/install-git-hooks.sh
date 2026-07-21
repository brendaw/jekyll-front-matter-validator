#!/usr/bin/env bash
set -e

ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$ROOT/.githooks/pre-commit"
git config core.hooksPath .githooks

echo "✅ Git hooks instalados (core.hooksPath = .githooks)."
echo "   Rode 'git config --unset core.hooksPath' para desativar."
