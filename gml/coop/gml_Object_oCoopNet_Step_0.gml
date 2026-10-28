var _c = global.Coop;
// --- heartbeat / timeout ---
if (_c.connected)
{
    if (current_time - _c.lastPing > 1000) { _c.lastPing = current_time; coop_send({ t: "ping", ts: current_time }); }
    if (current_time - _c.lastRecv > 10000)
    {
        coop_log("timeout");
        if (coop_is_host()) { coop_drop_partner("timeout"); } else { coop_disconnect("timeout"); }
    }
}
else if (coop_is_client() && current_time - _c.lastRecv > 12000)
{
    coop_disconnect("connect timeout");
}
// --- host: night start + clock ---
if (room != _c.prevRoom)
{
    coop_log("room " + room_get_name(room));
    if (coop_is_host() && _c.connected && room == NightOpening) { coop_send(coop_night_payload()); }
    _c.prevRoom = room;
}
if (coop_is_host() && _c.connected && room == Office && current_time - _c.lastClockSend > 500)
{
    _c.lastClockSend = current_time;
    coop_send({ t: "clock", timer: global.Timer });
}
// --- partner snapshot ~10/s ---
if (_c.connected && current_time - _c.lastSnapSend >= 100)
{
    _c.lastSnapSend = current_time;
    coop_send(coop_snapshot());
}
// --- ping (P) ---
if (_c.connected && room == Office && keyboard_check_pressed(ord("P"))) { coop_send_ping(); }
// --- bot ---
if (_c.bot)
{
    BotTimer++;
    if (BotTimer mod 60 == 0) { coop_log(coop_bot_line() + " draws=" + string(DrawCount) + " gui=" + string(display_get_gui_width()) + "x" + string(display_get_gui_height())); }
    if (_c.botPing && _c.connected && room == Office && BotTimer mod 150 == 0) { coop_send_ping(); }
    if (_c.botDoors >= 0 && !BotDoorsDone && room == Office && variable_global_exists("Timer") && variable_global_exists("Doors") && global.Timer >= _c.botDoors)
    {
        BotDoorsDone = true;
        global.Doors[0] = 1;
        global.Doors[1] = 1;
        audio_play_sound(sfxDoor, 10, false);
        coop_log("bot: closed both doors at timer " + string(global.Timer));
    }
    if (_c.botWin >= 0 && !BotWinDone && room == Office && variable_global_exists("Timer") && global.Timer >= _c.botWin)
    {
        BotWinDone = true;
        coop_log("bot: forcing win_night at timer " + string(global.Timer));
        win_night();
    }
    // bot: skip the warning screen the same way pressing space does
    if (room == WarningScreen && BotTimer > 90 && !BotSkippedWarning)
    {
        BotSkippedWarning = true;
        coop_log("bot: skip warning screen");
        apply_settings(false);
        room_goto(TitleScreenMap);
    }
    if (coop_is_host() && _c.connected && _c.autoNight >= 0 && !AutoNightDone && BotTimer > 180 && room != StartupRoom && room != WarningScreen)
    {
        AutoNightDone = true;
        global.Night = _c.autoNight;
        coop_log("bot: auto-start night " + string(_c.autoNight));
        room_goto(NightOpening);
    }
}
// --- menu (F8, not during a night) ---
if (keyboard_check_pressed(vk_f8) && room != Office) { _c.menuOpen = !_c.menuOpen; _c.focus = 0; }
if (_c.menuOpen && room == Office) { _c.menuOpen = false; }
if (_c.menuOpen)
{
    var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _x = _gw / 2 - 150, _y = _gh / 2 - 90;
    if (mouse_check_button_pressed(mb_left))
    {
        if (point_in_rectangle(_mx, _my, _x + 70, _y + 40, _x + 290, _y + 60)) { _c.focus = 1; keyboard_string = IpText; }
        else if (point_in_rectangle(_mx, _my, _x + 70, _y + 70, _x + 290, _y + 90)) { _c.focus = 2; keyboard_string = PortText; }
        else if (point_in_rectangle(_mx, _my, _x + 10, _y + 110, _x + 100, _y + 135)) { coop_host(real(PortText)); }
        else if (point_in_rectangle(_mx, _my, _x + 105, _y + 110, _x + 195, _y + 135)) { coop_join(IpText, real(PortText)); }
        else if (point_in_rectangle(_mx, _my, _x + 200, _y + 110, _x + 290, _y + 135)) { coop_disconnect("menu"); }
        else { _c.focus = 0; }
    }
    if (_c.focus == 1)
    {
        // allow host names / IPv4: letters, digits, '.', '-', ':'
        var _s = string_copy(keyboard_string, 1, 64), _o = "";
        for (var i = 1; i <= string_length(_s); i++)
        {
            var _ch = string_char_at(_s, i);
            if (string_lettersdigits(_ch) != "" || _ch == "." || _ch == "-" || _ch == ":") { _o += _ch; }
        }
        IpText = _o;
    }
    else if (_c.focus == 2)
    {
        PortText = string_digits(string_copy(keyboard_string, 1, 5));
        if (PortText == "") { PortText = "7777"; }
    }
    if (keyboard_check_pressed(vk_tab)) { _c.focus = _c.focus == 1 ? 2 : 1; keyboard_string = _c.focus == 1 ? IpText : PortText; }
    if (keyboard_check_pressed(vk_enter)) { coop_join(IpText, real(PortText)); }
    if (keyboard_check_pressed(vk_escape)) { _c.menuOpen = false; }
}
