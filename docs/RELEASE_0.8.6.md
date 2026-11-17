# Freakbear 3 Co-op — 0.8.6

Unofficial Co-op Modification for Freakbear 3. (Five Nights at Frickbear's 3 + Four Layers Down v2.1.5)

### Bug Fixes (from live play reports)

- **Night never ended after 6 AM.** The co-op attack-token gate cancelled the vanilla end-of-night killers (Chipper, Circus Baby, Blank, Archie, Toy Freddy, Orville, VIP, Mimic and the negative-token kill) after the game had already latched its 6 AM transition block, so the clock ran past 6 AM forever. Those kills now pass without a token (and keep the killer's name for the death screen). A watchdog additionally clears a stuck transition block after 5 seconds when no jumpscare is running, so the night can always finish.
- **Partner restarted the night, you stayed dead.** Restarting the same night from the pause menu now re-syncs both players: the partner follows into a fresh night even while dead/spectating (the uncounted death stays uncounted), and alive players restart together. Works in both directions (host or client restarts).
- **Spectator: useless P/M overlay removed.** The spectator ping (P) and camera mark (M) are gone; only the win-rule hint remains.
- **Spectator: ~9 fps and no sound.** Three causes were fixed: the 2-frame ack window (capped fps at ~2/RTT, now 4), a controller that never left the top tier while zlib compression stalled the sender, and a cadence bug where the millisecond send timer lost a whole frame to game-frame jitter (the "11 fps at 360p" / "20 fps at 144p" reports). Sending is now frame-quantized (up to 60 fps at small sizes) and the controller measures achieved fps and traffic, holding the highest sustainable tier: measured 640×360 ~27–30 fps, 480×270 ~50 fps, 320×180 60 fps on the test box, ~14 fps at 360p under 220 ms ack lag. 1080p60 is not possible in this engine (single-threaded zlib, no video codec); 1080p sustains ~10 fps. Office audio is forwarded to the spectator (play/stop/stop-all), and stops cleanly when spectating ends.
- **ESC in the maze cloned the partner sprite and teleported the second player.** Pause deactivates every instance except the co-op net object, and the maze code read the missing camera as "left the maze": each resume created another partner billboard and re-applied the client's 96 px spawn offset from its current position. Both the billboard tracking and the spawn offset now survive pause; the offset is applied once per maze entry.
- **SCRAPTRAP "0 of 9 tasks" on a non-boss night.** This is vanilla behaviour, not a bug: Scraptrap is a regular night animatronic (id 63); his tasks are run on the control panel at the back of the office. The shared HUD line now says where to do them, and only appears on nights where Scraptrap is actually active (AI > 0) — previously it showed every night because the game places his object in the office even when he is inactive.
- **Version handshake enforced.** Connections between different mod versions are now rejected at handshake with a clear message (previously mismatched versions connected and silently misbehaved). Both players must run 0.8.6. Network protocol unchanged (proto 8).

### Installer

- Same safe mechanism as 0.8.5: `Freakbear3Coop-0.8.6-Setup.exe` (Inno Setup) validates the game folder and base `data.win` by SHA-256, backs up the original as `data.win.coop-original` (never overwritten), applies an xdelta patch to a staged copy, verifies the result hash, then replaces `data.win`. Uninstall restores the original.
- Supported bases: clean v2.1.5, Coop_Install 0.7.2 (2.1.5), co-op 0.8.2 / 0.8.2 UnlockAll, and reinstall / variant switch over an existing 0.8.5 / 0.8.6 install. Owners of the old tester base `988a…` must first apply the official v0.8.2 patch.
- No original game files are distributed: only xdelta patches, the official xdelta3 tool, launchers, docs and co-op character art.
- Silent mode: `Setup.exe /SILENT /SUPPRESSMSGBOXES /DIR="<game folder>" /VARIANT=std|unlock /LOG="<file>"`.

### Installation

1. Download `Freakbear3Coop-0.8.6-Setup.exe` from this release (both players).
2. Close the game and run the installer; choose Standard or Unlock All (same variant on both PCs).
3. Select your game folder (the one containing `Frickbears3.exe` and `data.win`, v2.1.5).
4. Finish the wizard; the installer verifies the patched file by SHA-256 and keeps your original as `data.win.coop-original`.
5. Launch via `Host.bat` (host) / `Join.bat` (join), or the in-game Co-op menu (F8). See `CONNECT_RU.md` for playing over the internet with Porthole.

### Testing

- All 8 build targets (4 bases × Standard/UnlockAll) pass the static verification suite (`tests/verify.csx`, `VERIFY OK full`), including a check for every fix listed above.
- All 8 xdelta patches round-trip verified: decode(base, patch) SHA-256 equals the verified build hash.
- Installer tested on a copy of the game: clean-base install (both variants), upgrade from 0.8.2 UnlockAll, repeat install, variant switch, uninstall restore (hash-exact), wrong-folder and unsupported-base rejection, added-file cleanup, and a boot test of the patched copy.
- Live pair tests on Windows (two game instances, localhost, test-bot flags): death → spectator with forwarded audio and an adaptive stream holding a sustainable tier (measured 640×360 ~27–30 fps, 480×270 ~50 fps, 320×180 60 fps on the test box; the sender's own zlib cost loads the game to ~54 fps, so 30 fps is the 360p ceiling there; a 60 s blacklist prevents tier oscillation); host restart followed by the dead partner into a fresh night; alive-partner restart follow in both directions; the 6 AM end-of-night kill passing the gate on both sides with the killer name preserved and the clock stopping at 6 AM (GameOver, no softlock); a deliberately stuck 6 AM transition block cleared by the watchdog on both sides → night won; a maze night with three real ESC pause/resume cycles: exactly one partner billboard per side, the client spawn offset applied once at maze entry, positions unchanged across resumes (pre-fix: one clone and a 96 px teleport per resume); spectator stream under 220 ms simulated ack lag holding 640×360 ~14 fps (window-limited) with forwarded audio.
- Not tested: a live human two-player session over the internet (spectator audio was verified through the protocol log and the receiver's play calls, not by ear over a real link); stream fps/quality measured on localhost.

---

# Freakbear 3 Co-op — 0.8.6 (Русский)

Неофициальная кооперативная модификация для Freakbear 3. (Five Nights at Frickbear's 3 + Four Layers Down v2.1.5)

### Исправления (по жалобам из живой игры)

- **Ночь не кончалась после 6 утра.** Кооп-гейт жетонов атаки отменял обязательные убийства «в 6 утра» (Chipper, Circus Baby, Blank, Archie, Toy Freddy, Orville, VIP, Mimic и убийство при отрицательных жетонах) уже после того, как игра залипила блокировку перехода в 6 утра, — часы шли дальше 6 AM бесконечно. Теперь эти убийства проходят без жетона (и имя убийцы сохраняется для экрана смерти). Дополнительно сторожевой таймер снимает залипшую блокировку через 5 секунд, если скример не идёт, — ночь всегда может закончиться.
- **Друг рестартнул ночь — вы остались мёртвым.** Рестарт той же ночи из паузы теперь ресинхронизирует обоих: напарник следует в свежую ночь, даже если он уже мёртв и наблюдает (незасчитанная смерть остаётся незасчитанной); живые игроки рестартуют вместе. Работает в обе стороны (рестарт у хоста или у клиента).
- **Наблюдатель: убраны бесполезные P/M.** Пинг (P) и метка на камере (M) у наблюдателя удалены; осталась только подсказка правила победы.
- **Наблюдатель: ~9 fps и нет звука.** Исправлены три причины: окно из 2 кадров (ограничивало fps величиной ~2/RTT, теперь 4), контроллер, не уходивший с верхнего уровня, пока zlib-компрессия тормозила отправителя, и баг ритма: миллисекундный таймер отправки терял целый кадр из-за джиттера кадров игры (жалобы «11 fps на 360p» / «20 fps на 144p»). Отправка теперь покадровая (до 60 к/с на малых размерах), контроллер меряет фактический fps и трафик и держит самый высокий устойчивый уровень: замерено 640×360 ~27–30 к/с, 480×270 ~50 к/с, 320×180 60 к/с на тестовом ПК, ~14 к/с на 360p при задержке ack 220 мс. 1080p60 в этом движке невозможен (однопоточный zlib, видеокодека нет); 1080p держит ~10 к/с. Звук офиса пересылается наблюдателю (play/stop/stop-all) и корректно замолкает при выходе из наблюдения.
- **ESC в лабиринте клонировал спрайт напарника и телепортировал второго игрока.** Пауза деактивирует все инстансы, кроме кооп-сетевого объекта, и код лабиринта читал отсутствие камеры как «вышел из лабиринта»: каждое resume создавало ещё один биллборд напарника и заново применяло смещение спавна клиента (96 px) от его текущей позиции. Теперь трекинг биллборда и смещение спавна переживают паузу; смещение применяется один раз при входе в лабиринт.
- **SCRAPTRAP «0 из 9 заданий» без босса.** Это поведение оригинала, не баг: Scraptrap — обычный аниматроник ночи (id 63); его задания выполняются на контрольной панели в задней части офиса. Общая полоска HUD теперь подсказывает, где их делать, и показывается только в те ночи, когда Scraptrap действительно активен (AI > 0): раньше она появлялась каждую ночь, потому что игра ставит его объект в офис даже когда он неактивен.
- **Проверка версии при подключении.** Соединение между разными версиями мода теперь отклоняется на handshake с понятным сообщением (раньше разные версии соединялись и молча вели себя по-разному). Обоим нужна 0.8.6. Сетевой протокол не изменён (proto 8).

### Установщик

- Тот же безопасный механизм, что в 0.8.5: `Freakbear3Coop-0.8.6-Setup.exe` (Inno Setup) проверяет папку игры и базу `data.win` по SHA-256, сохраняет оригинал как `data.win.coop-original` (никогда не перезаписывает), применяет xdelta-патч к копии файла, проверяет хеш результата и только затем заменяет `data.win`. Удаление возвращает оригинал.
- Поддерживаемые базы: чистая v2.1.5, Coop_Install 0.7.2 (2.1.5), кооп 0.8.2 / 0.8.2 UnlockAll, а также переустановка / смена варианта поверх уже установленного 0.8.5 / 0.8.6. Владельцам старой тестовой базы `988a…` нужно сначала применить официальный патч v0.8.2.
- Оригинальные файлы игры не распространяются: только xdelta-патчи, официальный инструмент xdelta3, лаунчеры, документы и арты кооп-персонажей.
- Тихий режим: `Setup.exe /SILENT /SUPPRESSMSGBOXES /DIR="<папка игры>" /VARIANT=std|unlock /LOG="<файл>"`.

### Установка

1. Скачайте `Freakbear3Coop-0.8.6-Setup.exe` из этого релиза (оба игрока).
2. Закройте игру и запустите установщик; выберите Standard или Unlock All (одинаковый вариант на обоих ПК).
3. Укажите папку игры (ту, где лежат `Frickbears3.exe` и `data.win`, v2.1.5).
4. Завершите мастер; установщик проверит пропатченный файл по SHA-256 и сохранит оригинал как `data.win.coop-original`.
5. Запускайте через `Host.bat` (хост) / `Join.bat` (подключение) или через внутриигровое меню Co-op (F8). Игра по интернету через Porthole описана в `CONNECT_RU.md`.

### Проверки

- Все 8 целей сборки (4 базы × Standard/UnlockAll) проходят статический набор проверок (`tests/verify.csx`, `VERIFY OK full`), включая проверку каждого исправления выше.
- Все 8 xdelta-патчей проверены обратным применением: SHA-256 результата decode(base, patch) равен хешу проверенной сборки.
- Установщик протестирован на копии игры: установка на чистую базу (оба варианта), обновление с 0.8.2 UnlockAll, повторная установка, смена варианта, удаление с восстановлением оригинала (хеш-в-хеш), отказ на неверной папке и неподдерживаемой базе, очистка добавленных файлов и boot-тест патченной копии.
- Живые парные тесты на Windows (два экземпляра игры, localhost, флаги тест-ботов): смерть → наблюдатель с пересылаемым звуком и адаптивным потоком, удерживающим устойчивый уровень (замерено 640×360 ~27–30 к/с, 480×270 ~50 к/с, 320×180 60 к/с на тестовом ПК; собственная zlib-нагрузка отправителя роняет игру до ~54 fps, поэтому 30 к/с — потолок 360p там; 60-с blacklist гасит колебания уровней); рестарт хоста, за которым мёртвый напарник следует в свежую ночь; следование рестарту живого напарника в обе стороны; убийство «в 6 утра» проходит гейт у обоих, имя убийцы сохранено, часы останавливаются в 6 AM (GameOver, без софтлока); нарочно залипшая блокировка 6 AM снята сторожевым таймером у обоих → ночь выиграна; ночь в лабиринте с тремя реальными циклами ESC-паузы/resume: ровно один биллборд напарника на сторону, смещение спавна клиента применено один раз при входе, позиции не меняются через resume (до фикса: один клон и телепорт на 96 px за цикл); поток наблюдателя при симулированной задержке ack 220 мс держит 640×360 ~14 к/с (ограничение окна) со звуком.
- Не проверено: живая сессия двух людей через интернет (звук наблюдателя проверен по протокольному логу и вызовам воспроизведения на принимающей стороне, не на слух через реальную сеть); fps/качество потока замерены на localhost.