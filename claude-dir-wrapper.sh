#!/usr/bin/env bash
# Wrapper для claude с поиском .claude-dir-settings.yaml
# вверх по дереву каталогов (аналогично .nvmrc, .gitignore).
#
# Найденный файл определяет:
#   color   — цвет сессии (TWEAKCC_SESSION_COLOR)
#   plugins — список плагинов → --settings '{"enabledPlugins":{...}}'
#   env     — переменные окружения

set -euo pipefail

SETTINGS_FILE=".claude-dir-settings.yaml"

# Поиск файла вверх по дереву каталогов
find_upward() {
    local name="$1" dir
    dir="$(pwd -P)"
    while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/$name" ]] && echo "$dir/$name" && return 0
        dir="$(dirname "$dir")"
    done
    [[ -f "/$name" ]] && echo "/$name" && return 0
    return 1
}

claude_args=()

if settings_path="$(find_upward "$SETTINGS_FILE")"; then
    echo "[claude-wrapper] Найден: $settings_path" >&2

    settings_json="$(yq -o json "$settings_path")"

    # Цвет сессии
    color="$(echo "$settings_json" | jq -r '.color // empty')"
    [[ -n "$color" ]] && export TWEAKCC_SESSION_COLOR="$color"

    # Плагины → --settings JSON
    plugins_json="$(echo "$settings_json" | jq -c '
        .plugins // [] | if length > 0 then
            { enabledPlugins: (map({(.): true}) | add) }
        else empty end
    ')"
    [[ -n "$plugins_json" ]] && claude_args+=(--settings "$plugins_json")

    # Переменные окружения
    echo "$settings_json" | jq -r '.env // empty | to_entries[]? | "\(.key)=\(.value)"' |
    while IFS='=' read -r key value; do
        export "$key=$value"
    done
fi

exec claude "${claude_args[@]}" "$@"
