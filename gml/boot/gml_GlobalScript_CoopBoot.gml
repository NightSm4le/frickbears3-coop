// Stage 0 log hook: runs once at game start (global script top level).
var _f = file_text_open_append("coop_boot.log");
if (_f >= 0)
{
    file_text_write_string(_f, "coop boot ok " + date_datetime_string(date_current_datetime()) + " params=" + string(parameter_count()));
    file_text_writeln(_f);
    file_text_close(_f);
}
show_debug_message("[coop] boot hook ran");
