var _c = global.Coop;
if (variable_global_exists("FontW97White")) { draw_set_font(global.FontW97White); }
draw_set_halign(fa_left);
draw_set_valign(fa_top);
// small status line (always, when coop active)
if (_c.mode != "off" && !_c.menuOpen)
{
    draw_set_alpha(0.7);
    draw_set_color(c_white);
    draw_text(4, 4, "COOP " + _c.mode + ": " + _c.status + (_c.rtt >= 0 ? "  " + string(_c.rtt) + "ms" : ""));
    draw_set_alpha(1);
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
