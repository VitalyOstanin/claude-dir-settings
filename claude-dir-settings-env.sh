#!/usr/bin/env bash
# Парсинг .claude-dir-settings.yaml — sourced-файл.
# Выставляет: claude_args=(), TWEAKCC_SESSION_COLOR, переменные из env.
# НЕ запускает claude.

SETTINGS_FILE=".claude-dir-settings.yaml"

# Поиск файла вверх по дереву каталогов
_cds_find_upward() {
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

if _cds_settings_path="$(_cds_find_upward "$SETTINGS_FILE")"; then
    _cds_json="$(yq -o json "$_cds_settings_path")"

    # Цвет сессии
    _cds_color="$(echo "$_cds_json" | jq -r '.color // empty')"
    [[ -n "$_cds_color" ]] && export TWEAKCC_SESSION_COLOR="$_cds_color"

    # Собираем единый --settings JSON из plugins, sandbox, permissions
    _cds_flag_json="$(echo "$_cds_json" | jq -c '
        {}
        + (if (.plugins // []) | length > 0
           then { enabledPlugins: (.plugins | map({(.): true}) | add) }
           else {} end)
        + (if .sandbox then { sandbox: .sandbox } else {} end)
        + (if .permissions then { permissions: .permissions } else {} end)
        | if . == {} then empty else . end
    ')"
    [[ -n "$_cds_flag_json" ]] && claude_args+=(--settings "$_cds_flag_json")

    # Переменные окружения
    eval "$(echo "$_cds_json" | jq -r '.env // {} | to_entries[] | "export \(.key)=\(.value | @sh)"')"
fi

unset _cds_settings_path _cds_json _cds_color _cds_flag_json
unset -f _cds_find_upward
