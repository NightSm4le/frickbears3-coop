var _c = global.Coop;
if (variable_global_exists("FontW97White")) { draw_set_font(global.FontW97White); }
draw_set_halign(fa_left);
draw_set_valign(fa_top);
// small status line (always, when coop active)
if (_c.mode != "off" && !_c.menuOpen && !(room == Office && _c.connected))
{
    draw_set_alpha(0.7);
    draw_set_color(c_white);
    draw_text(4, 4, "COOP " + _c.mode + ": " + _c.status + (_c.rtt >= 0 ? "  " + string(_c.rtt) + "ms" : ""));
    draw_set_alpha(1);
}
// --- partner mini-window (Office, connected) ---
if (room == Office && _c.connected)
{
    var _gw0 = display_get_gui_width();
    var _w = 150, _h = 84;
    var _px = _gw0 - _w - 4, _py = 30;
    var _fresh = current_time - _c.partnerSnapAt < 1000;
    var _alive = coop_partner_get("alive", true);
    var _flash = current_time - _c.pingFlash < 2000;
    draw_set_alpha(0.75); draw_set_color(c_black); draw_rectangle(_px, _py, _px + _w, _py + _h, false); draw_set_alpha(1);
    var _border = _flash ? (((current_time div 150) mod 2) ? c_yellow : c_red) : (_alive ? c_white : c_red);
    draw_set_color(_border); draw_rectangle(_px, _py, _px + _w, _py + _h, true);
    if (_flash) { draw_rectangle(_px + 1, _py + 1, _px + _w - 1, _py + _h - 1, true); }
    draw_set_color(c_white);
    draw_text(_px + 4, _py + 2, "PARTNER" + (_c.rtt >= 0 ? "  " + string(_c.rtt) + "ms" : ""));
    if (!_fresh) { draw_set_color(c_gray); draw_text(_px + 4, _py + 18, "no data..."); }
    else if (!_alive) { draw_set_color(c_red); draw_text(_px + 4, _py + 18, "DEAD - spectating"); }
    else if (coop_partner_get("rm", "") != "Office") { draw_text(_px + 4, _py + 18, "in " + string(coop_partner_get("rm", "?"))); }
    else
    {
        var _pw = coop_partner_get("pw", 0);
        draw_text(_px + 4, _py + 18, "PWR " + string(max(_pw, 0)) + "%");
        // power bar
        draw_set_color(c_dkgray); draw_rectangle(_px + 76, _py + 21, _px + _w - 6, _py + 29, false);
        draw_set_color(_pw > 25 ? c_lime : c_red); draw_rectangle(_px + 76, _py + 21, _px + 76 + (_w - 82) * clamp(_pw, 0, 100) / 100, _py + 29, false);
        // doors
        draw_set_color(c_white);
        draw_text(_px + 4, _py + 34, "L");
        draw_set_color(coop_partner_get("d0", 0) ? c_red : c_dkgray); draw_rectangle(_px + 16, _py + 35, _px + 30, _py + 47, false);
        draw_set_color(c_white);
        draw_text(_px + 36, _py + 34, "R");
        draw_set_color(coop_partner_get("d1", 0) ? c_red : c_dkgray); draw_rectangle(_px + 48, _py + 35, _px + 62, _py + 47, false);
        draw_set_color(c_white);
        var _view = coop_partner_get("cu", 0) ? "CAM " + string(coop_partner_get("cam", "?")) : "OFFICE";
        if (coop_partner_get("mk", 0)) { _view = "MASK"; }
        draw_text(_px + 70, _py + 34, _view);
        var _ex = "";
        if (coop_partner_get("fan", 0)) { _ex += "FAN "; }
        if (coop_partner_get("fl", 0)) { _ex += "LIGHT "; }
        _ex += "T" + string(coop_partner_get("tp", 0));
        draw_text(_px + 4, _py + 50, _ex);
    }
    draw_set_color(_flash ? c_yellow : c_gray);
    draw_text(_px + 4, _py + 66, _flash ? "PING!" : "P = ping");
    draw_set_color(c_white);
}
if (!_c.menuOpen) { exit; }
var _gw = display_get_gui_width(), _gh = display_get_gui_height();
var _x = _gw / 2 - 150, _y = _gh / 2 - 90;
draw_set_alpha(0.85); draw_set_color(c_black); draw_rectangle(_x, _y, _x + 300, _y + 175, false); draw_set_alpha(1);
draw_set_color(c_white); draw_rectangle(_x, _y, _x + 300, _y + 175, true);
draw_text(_x + 10, _y + 10, "CO-OP (F8)");
draw_text(_x + 10, _y + 42, "IP:");
draw_text(_x + 10, _y + 72, "Port:");
draw_set_color(_c.focus == 1 ? c_yellow : c_gray); draw_rectangle(_x + 70, _y + 40, _x + 290, _y + 60, true);
draw_set_color(_c.focus == 2 ? c_yellow : c_gray); draw_rectangle(_x + 70, _y + 70, _x + 290, _y + 90, true);
draw_set_color(c_white);
draw_text(_x + 74, _y + 42, IpText + (_c.focus == 1 && (current_time div 500) mod 2 ? "_" : ""));
draw_text(_x + 74, _y + 72, PortText + (_c.focus == 2 && (current_time div 500) mod 2 ? "_" : ""));
var _labels = ["HOST", "JOIN", "LEAVE"];
for (var i = 0; i < 3; i++)
{
    var _bx = _x + 10 + i * 95;
    draw_rectangle(_bx, _y + 110, _bx + 90, _y + 135, true);
    draw_text(_bx + 8, _y + 114, _labels[i]);
}
draw_text(_x + 10, _y + 145, _c.status);
