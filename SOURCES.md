# Источники и зависимости

## Скрипты Criminality и справочные реализации

- [Trojankill/Criminality — CriminalityV2.lua](https://github.com/Trojankill/Criminality/blob/main/CriminalityV2.lua). Основной публичный пример, использованный при исследовании Criminality: stamina через GC-таблицы с полем `S`, горизонтальная AssemblyLinearVelocity для Speed, Scrap/Dealer ESP по структуре объектов, ускорение ProximityPrompt через `HoldDuration`, маркер Downed и сравнение подходов к Silent Aim / Melee. Исходник изучался, целиком не загружается и не выполняется нашим скриптом. Наличие реализации в этом репозитории не доказывает её работу в текущей игре.
- [Averiias/Universal-SilentAim — main.lua](https://github.com/Averiias/Universal-SilentAim/blob/main/main.lua). Дополнительный справочный пример разных методов raycast / mouse silent aim. Не является подключаемой зависимостью Legit и не подтверждает совместимость с Criminality.

Адаптер Gun / Effects / FastCast также написан по локальным выгрузкам клиентских модулей текущей игры. Эти выгрузки не публикуются в репозитории. Фильтры друзей, порог HP, управление состоянием, восстановление свойств, диагностика и интеграция UI реализованы в Legit отдельно.

## UI и запускаемые инструменты

- [B5RLAS/Neverlose](https://github.com/B5RLAS/Neverlose/blob/main/NeverLose.lua) — текущая библиотека UI; исходник и описание локальных изменений находятся в `vendor/Neverlose`. Obsidian сохранён в истории/архиве и больше не загружается.
- [FusionWTF/DeX-Explorer](https://github.com/FusionWTF/DeX-Explorer) — внешний Dex Explorer, загружается только кнопкой в Misc.
- [78n/SimpleSpy](https://github.com/78n/SimpleSpy) — внешний Remote Spy, загружается только кнопкой в Misc; URL в коде закреплён на конкретном коммите.

## Документация

- [Roblox: ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt) — свойства удержания и события взаимодействия.
- [Roblox: Proximity prompts](https://create.roblox.com/docs/ui/proximity-prompts) — управление prompts и ProximityPromptService.

Ссылки выше разделяют изученные примеры и реально подключённые зависимости. Работоспособность функций в живой игре отмечается отдельно от локальных тестов.

Crate ESP в Legit использует собственную классификацию по имени, атрибутам и цветам: открытого подтверждённого адаптера актуальных кейсов в просмотренном примере не найдено. Это явно отделено от Scrap/Dealer и требует проверки на текущей карте.
