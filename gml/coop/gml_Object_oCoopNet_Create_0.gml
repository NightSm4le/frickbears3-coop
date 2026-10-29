coop_parse_args();
var _c = global.Coop;
coop_log("oCoopNet up, mod " + _c.modver + " proto " + string(_c.proto) + " game " + global.CurrentVersion);
if (_c.mode == "want_host") { coop_host(_c.port); }
else if (_c.mode == "want_join") { coop_join(_c.ip, _c.port); }
BotTimer = 0;
AutoNightDone = false;
BotSkippedWarning = false;
BotWinDone = false;
BotOfficeFrames = 0;
BotDoorsDone = false;
DrawCount = 0;
IpText = _c.ip;
PortText = string(_c.port);
BotKickDone = false;
BotShotLogged = false;
