#!/usr/bin/env bash
set -e

ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$ROOT/.githooks/pre-commit"
git config core.hooksPath .githooks

echo "✅ Git hooks installed (core.hooksPath = .githooks)."
echo "   Run 'git config --unset core.hooksPath' to disable."
