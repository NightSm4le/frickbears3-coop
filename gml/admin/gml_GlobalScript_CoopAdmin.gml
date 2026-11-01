global.CoopAdmin = {
    enabled: true,
    saveReady: false,
    infinitePower: false,
    giftAmount: 100000
};

function coop_admin_unlock_all()
{
    var _changed = false;
    var _names = ["UnlockedGuards", "UnlockedAnimatronics", "UnlockedTrophies", "UnlockedMinigames"];
    for (var n = 0; n < array_length(_names); n++)
    {
        var _name = _names[n];
        if (!variable_global_exists(_name)) { continue; }
        var _values = variable_global_get(_name);
        if (!is_array(_values)) { continue; }
        for (var i = 0; i < array_length(_values); i++)
        {
            if (!_values[i]) { _values[i] = true; _changed = true; }
        }
        variable_global_set(_name, _values);
    }
    if (_changed && room == TitleScreenMap && instance_exists(oTitleMenu))
    {
        with (oTitleMenu) { if (CurMenu == "Title" && !Transitioning) { goto_menu("Title", 0); } }
    }
    return _changed;
}

function coop_admin_step()
{
    var _a = global.CoopAdmin;
    if (!_a.saveReady)
    {
        if (global.CoopSaveTag == "_coop_admin") { _a.saveReady = true; }
        else if (global.CoopSaveTag == "" && room == TitleScreenMap)
        {
            global.CoopF.saveTagArg = "_admin";
            coop_save_enter();
            _a.saveReady = global.CoopSaveTag == "_coop_admin";
            if (!_a.saveReady)
            {
                show_debug_message("[coop admin] Could not activate isolated admin save.");
                return;
            }
        }
        else { return; }
    }

    coop_admin_unlock_all();
    if (keyboard_check_pressed(vk_f6))
    {
        _a.infinitePower = !_a.infinitePower;
        coop_alert("Admin infinite power " + (_a.infinitePower ? "ON" : "OFF"), c_aqua, undefined);
    }
    if (keyboard_check_pressed(vk_f7))
    {
        if (variable_global_exists("RunEarnings")) { global.RunEarnings += _a.giftAmount; }
        if (variable_global_exists("RunEarningsTotal")) { global.RunEarningsTotal += _a.giftAmount; }
        coop_alert("Admin gave +" + string(_a.giftAmount) + " money", c_aqua, undefined);
    }
    if (_a.infinitePower && room == Office && variable_global_exists("Power"))
    {
        global.Power = coop_help_power_max();
    }
}

function coop_admin_draw()
{
    var _a = global.CoopAdmin;
    if (!_a.enabled || !_a.saveReady) { return; }
    var _label = "ADMIN  F6 infinite power: " + (_a.infinitePower ? "ON" : "OFF") + "   F7 +$" + string(_a.giftAmount) + "   unlocks: ON";
    var _y = display_get_gui_height() - 22;
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_aqua);
    draw_text(8, _y, _label);
    draw_set_color(c_white);
}
