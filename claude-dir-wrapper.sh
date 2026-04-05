#!/usr/bin/env bash
# Wrapper для claude с поиском .claude-dir-settings.yaml
# вверх по дереву каталогов (аналогично .nvmrc, .gitignore).

set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/claude-dir-settings-env.sh"

exec claude "${claude_args[@]}" "$@"
