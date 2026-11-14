# Obsidian

`vendor/Obsidian/Library.lua`: [deividcomsono/Obsidian](https://github.com/deividcomsono/Obsidian), commit `bed842eabdec1a3c087748d061c169d7848a47be`, MIT, copyright 2025 deividcomsono. License: `vendor/Obsidian/LICENSE`.

`vendor/Obsidian/Lucide.lua`: [notpoiu/lucide-roblox-direct](https://github.com/notpoiu/lucide-roblox-direct), commit `04f2bbae632268b1c165b4e477340b1566606958`, MIT. License: `vendor/Obsidian/Lucide.LICENSE`.

Local integration changes: Obsidian receives the bundled Lucide module as its chunk argument instead of fetching Molto/Lucide over HTTP. Both files locally disable `getcustomasset` to use their upstream Roblox asset ID fallback, avoiding image/font downloads and executor cache maintenance. The widget and layout code remains upstream Obsidian.

## Optional external tools (not vendored or run at startup)

- Dex: [FusionWTF/DeX-Explorer](https://github.com/FusionWTF/DeX-Explorer), the `Beta/out.lua` release linked by that project's README. This release URL may change upstream.
- Remote Spy: [78n/SimpleSpy](https://github.com/78n/SimpleSpy), `SimpleSpySource.lua` at commit `de04922e7b26d932111a04a18ee8d3341523ee5c`. Its own dependencies / update controls use upstream URLs.

These tools are fetched only through their explicit launch buttons. They retain their own interfaces and cleanup. Source URLs are defined in `src/UniversalTools.lua`; copies downloaded to `.test-work/` for compile-only validation are not committed or bundled.

## Tokyo Lib (legacy, not bundled)

Основа `vendor/Tokyo.lua` — файл **Tokyo Lib Source.lua**, предоставленный пользователем. Исходная копия сохранена первым коммитом `chore: vendor supplied Tokyo UI library`. Имена и комментарии исходника сохранены. Лицензия в приложенном файле не указана; авторство библиотеки этому проекту не приписывается.

Локальные изменения:

- Встроенная реализация Signal вместо внешнего `loadstring` с drillygzzly/Other.
- Изображения перенесены из ссылок portallol/luna и встроенного base64 в `assets/`.
- Удалена необходимость `crypt.base64decode` при создании окна.
- Защита повторной выгрузки; очистка Drawing-деревьев без повторного удаления дочерних объектов; освобождение FreezeMovement.
- Отложенные задачи проверяют, что библиотека ещё загружена.
- Исправлено сравнение клавиши мыши при отпускании bind.
- Исправлены условия копирования параметров toggle/list, проверка `syn.protect_gui`, сообщения диагностики и свойства прозрачности служебного ImageButton.
- Color picker сохраняет точные RGB, включая чёрный и белый; прозрачность ограничивается диапазоном 0–1.
- Добавлены необязательные `startupArgs.drawing` и `startupArgs.image`, чтобы Tokyo могла использовать GUI-рендерер и зарегистрированные локальные изображения без изменения глобального Drawing API.
- Native Remove защищён; при его сбое пробуется Destroy и скрытие объекта. Старая аварийная копия UI не блокирует загрузку следующей.

Встроенная функция `CreateSettingsTab` из исходника не вызывается приложением. Вместо неё Profiles создаётся через стандартные методы Tokyo: AddTab, AddSection, AddBox, AddButton и AddColor.
