# Freakbear 3 Co-op — 0.8.5

Unofficial Co-op Modification for Freakbear 3. (Five Nights at Frickbear's 3 + Four Layers Down v2.1.5)

### What's New

- Real Windows installer: `Freakbear3Coop-0.8.5-Setup.exe` (Inno Setup). Wizard with game-folder selection and validation, base-version check by SHA-256, Standard / Unlock All variant choice, progress display, clear error messages, cancel support, install log (`coop_install_log.txt` in the game folder).
- Safe by design: your original `data.win` is backed up as `data.win.coop-original` (an existing backup is never overwritten); the xdelta patch is applied to a staged copy and SHA-256-verified before `data.win` is replaced; uninstalling restores the original from the backup.
- Multi-base upgrades: clean v2.1.5, Coop_Install 0.7.2 (2.1.5), co-op 0.8.2 and 0.8.2 UnlockAll are all supported, plus reinstall / variant switch on an existing 0.8.5 install. Repeat installs are idempotent.
- The legacy zip mechanism (`install.bat` / `install.ps1`, copies the game to a sibling folder) now uses the same base matrix and a `-Variant unlock` option.
- No original game files are distributed: the installer and the zip contain only xdelta patches, the official xdelta3 tool, launchers, docs and co-op character art.

### Bug Fixes

- Scraptrap night crash: when the host's task list arrived, the client's `TaskRunning` index could point past the end of the new list (`oControlPanel` reads `Tasks[TaskRunning]` every frame). The running task is now remapped by title before the list is replaced.
- Scraptrap desync on a second night in the same session: the task list and the shared task total are now reset and re-synchronized on Office entry.
- Returning from a maze or from SalvageResults no longer wipes same-night boss state (enrage, shared HP, revive counter).
- Wrong "Boss enraged" reason on host death: the enrage message now correctly reports the host down instead of the partner.
- Retained and re-verified in this build (fixed in 0.8.4): `oGameOver_Create` "illegal array use" crash on Endless (`Deaths` array/number handling) and the `oTextBox_Fredbear.CGPFunction not set` crash in textbox forwarding.
- Network protocol unchanged (proto 8). Both players must run 0.8.5.

### Installer

- Bases are identified by SHA-256 of `data.win`; unsupported versions produce a clear error listing the supported bases. Owners of the old tester base `988a…` should first apply the official v0.8.2 patch (it converts 988a to 0.8.2), then run this installer.
- Install steps: backup (once) → stage base → xdelta decode → SHA-256 verify → atomic replace → add `Host.bat`, `Join.bat`, docs and `Addons/CoopChars` (existing user files are never overwritten).
- Uninstall (Windows "Apps & features" or `unins000.exe` in the game folder) restores `data.win` from `data.win.coop-original` and removes only the files the installer added.
- Silent mode for automation: `Setup.exe /SILENT /SUPPRESSMSGBOXES /DIR="<game folder>" /VARIANT=std|unlock /LOG="<file>"`.

### Installation

1. Download `Freakbear3Coop-0.8.5-Setup.exe` from this release (both players).
2. Close the game and run the installer; choose Standard or Unlock All (same variant on both PCs).
3. Select your game folder (the one containing `Frickbears3.exe` and `data.win`, v2.1.5).
4. Finish the wizard; the installer verifies the patched file by SHA-256 and keeps your original as `data.win.coop-original`.
5. Launch via `Host.bat` (host) / `Join.bat` (join), or the in-game Co-op menu (F8). See `CONNECT_RU.md` for playing over the internet with Porthole.

### Testing

- All 8 build targets (4 bases × Standard/UnlockAll) pass the static verification suite (`tests/verify.csx`, `VERIFY OK full`), including checks for every fix listed above.
- All 8 xdelta patches round-trip verified: decode(base, patch) SHA-256 equals the verified build hash.
- Installer tested on a copy of the game: clean-base install (both variants), upgrade from 0.8.2 UnlockAll, repeat install, variant switch, uninstall restore (hash-exact), wrong-folder and unsupported-base rejection, added-file cleanup, and a boot test of the patched copy (title screen reached, no Code Error).
- Not tested: a live two-player co-op session (requires two game instances and a network link); boss-fight fixes are verified statically and by single-instance boot only.

---

# Freakbear 3 Co-op — 0.8.5 (Русский)

Неофициальная кооперативная модификация для Freakbear 3. (Five Nights at Frickbear's 3 + Four Layers Down v2.1.5)

### Что нового

- Настоящий установщик для Windows: `Freakbear3Coop-0.8.5-Setup.exe` (Inno Setup). Мастер с выбором и проверкой папки игры, проверкой версии базы по SHA-256, выбором варианта Standard / Unlock All, отображением прогресса, понятными ошибками, поддержкой отмены и логом установки (`coop_install_log.txt` в папке игры).
- Безопасность по умолчанию: оригинальный `data.win` сохраняется как `data.win.coop-original` (существующая резервная копия никогда не перезаписывается); xdelta-патч применяется к копии файла и проверяется по SHA-256 до замены `data.win`; удаление возвращает оригинал из резервной копии.
- Обновление с разных баз: чистая v2.1.5, Coop_Install 0.7.2 (2.1.5), кооп 0.8.2 и 0.8.2 UnlockAll — все поддерживаются, плюс переустановка / смена варианта поверх уже установленного 0.8.5. Повторные установки идемпотентны.
- Прежний zip-механизм (`install.bat` / `install.ps1`, копирует игру в соседнюю папку) теперь использует ту же матрицу баз и опцию `-Variant unlock`.
- Оригинальные файлы игры не распространяются: установщик и zip содержат только xdelta-патчи, официальный инструмент xdelta3, лаунчеры, документы и арты кооп-персонажей.

### Исправления

- Краш ночи Scraptrap: при получении списка задач хоста индекс `TaskRunning` клиента мог указывать за конец нового списка (`oControlPanel` каждый кадр читает `Tasks[TaskRunning]`). Теперь выполняемая задача переназначается по названию до замены списка.
- Рассинхрон Scraptrap на второй ночи в той же сессии: список задач и общий счётчик задач теперь сбрасываются и заново синхронизируются при входе в офис.
- Возврат из лабиринта или из SalvageResults больше не стирает состояние босса текущей ночи (enrage, общее HP, счётчик revive).
- Неверная причина «Boss enraged» при смерти хоста: сообщение теперь корректно сообщает о хосте, а не о партнёре.
- Сохранены и перепроверены в этой сборке (исправлены в 0.8.4): краш `oGameOver_Create` «illegal array use» на Endless (обработка массива/числа `Deaths`) и краш `oTextBox_Fredbear.CGPFunction not set` при пересылке текстовых боксов.
- Сетевой протокол не изменён (proto 8). Оба игрока должны использовать 0.8.5.

### Установщик

- Базы определяются по SHA-256 файла `data.win`; неподдерживаемая версия даёт понятную ошибку со списком поддерживаемых баз. Владельцам старой тестовой базы `988a…` нужно сначала применить официальный патч v0.8.2 (он превращает 988a в 0.8.2), затем запустить этот установщик.
- Шаги установки: резервная копия (один раз) → копия базы → xdelta-распаковка → проверка SHA-256 → атомарная замена → добавление `Host.bat`, `Join.bat`, документов и `Addons/CoopChars` (существующие файлы пользователя никогда не перезаписываются).
- Удаление (Windows «Приложения и возможности» или `unins000.exe` в папке игры) восстанавливает `data.win` из `data.win.coop-original` и убирает только файлы, добавленные установщиком.
- Тихий режим для автоматизации: `Setup.exe /SILENT /SUPPRESSMSGBOXES /DIR="<папка игры>" /VARIANT=std|unlock /LOG="<файл>"`.

### Установка

1. Скачайте `Freakbear3Coop-0.8.5-Setup.exe` из этого релиза (оба игрока).
2. Закройте игру и запустите установщик; выберите Standard или Unlock All (одинаковый вариант на обоих ПК).
3. Укажите папку игры (ту, где лежат `Frickbears3.exe` и `data.win`, v2.1.5).
4. Завершите мастер; установщик проверит пропатченный файл по SHA-256 и сохранит оригинал как `data.win.coop-original`.
5. Запускайте через `Host.bat` (хост) / `Join.bat` (подключение) или через внутриигровое меню Co-op (F8). Игра по интернету через Porthole описана в `CONNECT_RU.md`.

### Проверки

- Все 8 целей сборки (4 базы × Standard/UnlockAll) проходят статический набор проверок (`tests/verify.csx`, `VERIFY OK full`), включая проверки каждого исправления выше.
- Все 8 xdelta-патчей проверены обратным применением: SHA-256 результата decode(base, patch) равен хешу проверенной сборки.
- Установщик протестирован на копии игры: установка на чистую базу (оба варианта), обновление с 0.8.2 UnlockAll, повторная установка, смена варианта, удаление с восстановлением оригинала (хеш-в-хеш), отказ на неверной папке и неподдерживаемой базе, очистка добавленных файлов и boot-тест патченной копии (титульный экран достигнут, без Code Error).
- Не проверено: живая кооп-сессия с двумя игроками (нужны два экземпляра игры и сетевое соединение); исправления босс-файта проверены статически и одиночным запуском.