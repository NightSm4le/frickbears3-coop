// Async - Networking
var _c = global.Coop;
var _type = ds_map_find_value(async_load, "type");
switch (_type)
{
    case network_type_connect:
        if (!coop_is_host()) { break; }
        var _s = ds_map_find_value(async_load, "socket");
        if (_c.sock >= 0)
        {
            coop_log("extra connection refused (max 2 players)");
            network_destroy(_s);
            break;
        }
        _c.sock = _s;
        _c.lastRecv = current_time;
        _c.status = "partner connecting...";
        coop_log("incoming from " + string(ds_map_find_value(async_load, "ip")));
        break;
    case network_type_non_blocking_connect:
        if (!coop_is_client()) { break; }
        if (ds_map_find_value(async_load, "succeeded"))
        {
            coop_log("tcp connected, sending hello");
            _c.lastRecv = current_time;
            coop_send({ t: "hello", proto: _c.proto, modver: _c.modver, game: global.CurrentVersion });
        }
        else { coop_disconnect("connect failed"); }
        break;
    case network_type_disconnect:
        if (ds_map_find_value(async_load, "socket") != _c.sock) { break; }
        if (coop_is_host()) { coop_drop_partner("socket closed"); } else { coop_disconnect("socket closed"); }
        break;
    case network_type_data:
        var _b = ds_map_find_value(async_load, "buffer");
        _c.bytesIn += ds_map_find_value(async_load, "size");
        var _sz = ds_map_find_value(async_load, "size");
        if (_sz > 10 && buffer_peek(_b, 0, buffer_u8) == 1) { coop_stream_on_frame(_b, _sz); break; } // binary video frame
        buffer_seek(_b, buffer_seek_start, 0);
        var _str = buffer_read(_b, buffer_string);
        var _m = undefined;
        try { _m = json_parse(_str); } catch (_e) { coop_log("bad packet"); }
        if (is_struct(_m)) { coop_on_packet(_m); }
        break;
}
