// Draw GUI End: the game leaves z-testing on (3D title/office), which hides GUI primitives -> turn it off while we draw.
DrawCount++;
var _zt = gpu_get_ztestenable(), _zw = gpu_get_zwriteenable();
gpu_set_ztestenable(false);
gpu_set_zwriteenable(false);
coop_draw_gui();
gpu_set_ztestenable(_zt);
gpu_set_zwriteenable(_zw);
