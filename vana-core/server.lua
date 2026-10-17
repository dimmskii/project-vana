addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("[vana-core] started on " .. getServerName() .. " (MTA " .. getVersion().sortable .. ")")
end)
