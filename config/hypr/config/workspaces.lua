-- Assign Workspaces 1..10 to Primary Monitor (DP-1)
for w = 1, NUM_WPM do
    hl.workspace_rule({
        workspace  = tostring(w),
        monitor    = PRIMARY_MONITOR,
        default    = (w == 1),
        persistent = true,
    })
end
