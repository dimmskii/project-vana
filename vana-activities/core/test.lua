-- Console-only self-test: text, data and registrations every activity relies on. Activities add their
-- own checks with Activity.test(name, fn) (fn returns ok, summary).
local tests = {}
function Activity.test(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

addCommandHandler("activitytest", function(source)
    if getElementType(source) ~= "console" then return end
    local allOk = true
    local sample = Gxt.raw("BURG23", "BURGLAR")
    local textOk = sample ~= nil and Gxt.raw("BURGLAR", "BURGLAR") ~= nil
    outputServerLog(("[activitytest] text: %s (BURG23 = %q)"):format(textOk and "ok" or "MISSING", tostring(sample)))
    allOk = allOk and textOk
    for _, t in ipairs(tests) do
        local ok, passed, detail = pcall(t.fn)
        if not ok then passed, detail = false, passed end
        outputServerLog(("[activitytest] %s: %s %s"):format(t.name, passed and "ok" or "FAIL", tostring(detail or "")))
        allOk = allOk and passed
    end
    outputServerLog("[activitytest] " .. (allOk and "PASS" or "FAIL"))
end)
