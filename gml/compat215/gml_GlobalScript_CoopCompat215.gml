// overlay builds only: the 0.6.6@2.1.5 base (988a…) has script assets for these functions; keep them
// resolvable so the runner does not fail on load ("Unable to find function gml_Script_...").
function coop_unlock_save_active()
{
    return variable_global_exists("CoopAdmin") && variable_struct_exists(global.CoopAdmin, "enabled") && coop_admin_save_active();
}

