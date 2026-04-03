# claude-dir-settings

Настройки Claude Code, привязанные к каталогу. Файл `.claude-dir-settings.yaml` ищется вверх по дереву каталогов от текущего до `/` (аналогично `.nvmrc`, `.gitignore`, `tsconfig.json`).

## Содержание

- [Зачем](#зачем)
- [Как это работает](#как-это-работает)
- [Формат файла настроек](#формат-файла-настроек)
- [Wrapper-скрипт](#wrapper-скрипт)
- [Механизм merge в Claude Code](#механизм-merge-в-claude-code)
- [Добавление настроек для нового каталога](#добавление-настроек-для-нового-каталога)
- [Связанные issues в Claude Code](#связанные-issues-в-claude-code)

## Зачем

При работе с Claude Code в разных проектах нужны разные наборы плагинов и MCP-серверов. Без привязки к каталогу все плагины загружаются в каждой сессии -- лишние MCP-серверы стартуют, занимают ресурсы, засоряют список инструментов и замедляют запуск.

Ещё одна проблема -- подкаталоги. Реальный проект содержит вложенные каталоги: git worktrees, документация, сервисы. Claude Code нужно запускать из любого из них, а настройки должны подхватываться автоматически от ближайшего родительского каталога.

Claude Code пока не поддерживает поиск настроек вверх по дереву каталогов (см. [связанные issues](#связанные-issues-в-claude-code)). Этот проект реализует эту функциональность через wrapper-скрипт.

## Как это работает

1. Wrapper-скрипт ищет файл `.claude-dir-settings.yaml` в текущем каталоге, затем в каждом родительском вплоть до `/`
2. Первый найденный файл читается через `yq` (конвертация в JSON) и `jq` (обработка)
3. Из настроек извлекаются:
   - **color** -- цвет сессии, передаётся через `TWEAKCC_SESSION_COLOR`
   - **plugins** -- список плагинов, передаётся через `--settings '{"enabledPlugins":{...}}'`
   - **env** -- переменные окружения, экспортируются в процесс
4. Claude Code запускается с полученными параметрами
5. `--settings` делает deep merge поверх user/project settings -- указанные плагины включаются, остальные остаются нетронутыми

## Формат файла настроек

Файл `.claude-dir-settings.yaml` размещается в корневом каталоге проекта:

```yaml
color: yellow
plugins:
  - my-plugin@local
  - project-mcp@marketplace
env:
  SOME_VAR: value
```

| Ключ      | Тип          | Описание                                            |
|-----------|--------------|-----------------------------------------------------|
| `color`   | строка       | Цвет сессии (передаётся в `TWEAKCC_SESSION_COLOR`)  |
| `plugins` | список строк | Плагины, включаемые через `--settings`              |
| `env`     | объект       | Переменные окружения, экспортируемые перед запуском  |

Все ключи опциональны.

## Wrapper-скрипт

Пример: `claude-dir-wrapper.sh` в корне этого репозитория.

Зависимости:
- [yq](https://github.com/mikefarah/yq) (mikefarah/yq, Go) -- конвертация YAML в JSON
- [jq](https://github.com/jqlang/jq) -- обработка JSON

Ключевая функция -- поиск файла вверх по дереву каталогов:

```bash
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
```

## Механизм merge в Claude Code

Claude Code мержит settings из источников в порядке приоритета:

```
plugin settings -> userSettings -> projectSettings -> localSettings -> flagSettings -> policySettings
```

`--settings` = `flagSettings`, приоритет выше user/project. Deep merge через `lodash mergeWith`:
- Неупомянутые ключи остаются как есть
- Явно указанные ключи перезаписываются

## Добавление настроек для нового каталога

Создать файл `.claude-dir-settings.yaml` в корне проекта:

```yaml
color: magenta
plugins:
  - some-plugin@marketplace
```

Если плагин специфичен для проекта -- убедиться, что он выключен в `~/.claude/settings.json`:

```json
"enabledPlugins": {
  "some-plugin@marketplace": false
}
```

Wrapper автоматически включит его через `--settings` при запуске из этого каталога или любого подкаталога.

## Связанные issues в Claude Code

| Issue                                                                                               | Описание                                                              |
|-----------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| [anthropics/claude-code#12962](https://github.com/anthropics/claude-code/issues/12962)              | Settings.json parent directory traversal for monorepos                |
| [anthropics/claude-code#35561](https://github.com/anthropics/claude-code/issues/35561)              | Hierarchical `.claude/` discovery past git boundaries                 |
| [anthropics/claude-code#26489](https://github.com/anthropics/claude-code/issues/26489)              | skills/, agents/, commands/ should traverse parent directories        |
| [anthropics/claude-code#20218](https://github.com/anthropics/claude-code/issues/20218)              | Nested settings.local.json shadows parent settings without warning    |
