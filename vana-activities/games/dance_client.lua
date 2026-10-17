-- Dancing and the lowrider contest on this client: run the rhythm game, report the score.
addEvent("vana-dance:start", true)
addEventHandler("vana-dance:start", resourceRoot, function(kind, opts)
    if not kind then return Rhythm.stop() end
    Rhythm.start(opts, function(share, points) triggerServerEvent("vana-dance:done", resourceRoot, share, points) end)
end)
