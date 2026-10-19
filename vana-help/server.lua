-- The manual: every running resource's help pages (their help.lua, through getHelpPages), shown to
-- each player as they may use them: a page with a `right` only to players the ACL gives it, console
-- pages only at the console. /help, /? and /man.
local pages = {}   -- name -> page (with .resource)
local AREAS = {    -- resource -> the area its pages are listed under
    ["vana-player"] = "Players", ["vana-vehicles"] = "Vehicles", ["vana-radio"] = "Radio", ["vana-traffic"] = "Traffic",
    ["vana-peds"] = "Pedestrians", ["vana-services"] = "Police and events", ["vana-shops"] = "Shops and garages",
    ["vana-activities"] = "Activities", ["vana-wildlife"] = "Wildlife", ["vana-help"] = "Help",
}

local function loadPages(res)
    if getResourceState(res) ~= "running" then return end
    local exported = false
    for _, fn in ipairs(getResourceExportedFunctions(res) or {}) do exported = exported or fn == "getHelpPages" end
    if not exported then return end
    local name = getResourceName(res)
    local ok, list = pcall(function() return call(res, "getHelpPages") end)
    if not ok or type(list) ~= "table" then return end
    for _, page in ipairs(list) do
        if type(page) == "table" and type(page.name) == "string" then
            page.resource, page.area = name, AREAS[name] or "Server"
            pages[page.name:lower()] = page
        end
    end
end

local function drop(res)
    local name = getResourceName(res)
    for key, page in pairs(pages) do if page.resource == name then pages[key] = nil end end
end

addEventHandler("onResourceStart", root, function(res)
    if res == resource then
        for _, r in ipairs(getResources()) do loadPages(r) end
    else
        loadPages(res)
    end
end)
addEventHandler("onResourceStop", root, function(res) if res ~= resource then drop(res) end end)

local function allowed(page, who)
    if getElementType(who) == "console" then return true end
    if page.console then return false end
    return not page.right or hasObjectPermissionTo(who, page.right, false)
end

-- The pages `who` may see, matching `query` (a name, an alias, or any word in them), sorted by area.
local function visible(who, query)
    local list = {}
    query = query and query:lower()
    for _, page in pairs(pages) do
        if allowed(page, who) then
            local hit = not query
            if query and not hit then
                local aliases = table.concat(page.aliases or {}, " "):lower()
                hit = page.name:lower():find(query, 1, true) or aliases:find(query, 1, true)
                    or (page.summary or ""):lower():find(query, 1, true) or (page.text or ""):lower():find(query, 1, true)
            end
            if hit then list[#list + 1] = page end
        end
    end
    table.sort(list, function(a, b)
        if a.area ~= b.area then return a.area < b.area end
        if (a.topic or false) ~= (b.topic or false) then return a.topic == true end
        return a.name < b.name
    end)
    return list
end

local function exact(who, name)
    name = name:lower():gsub("^/", "")
    local page = pages[name]
    if not page then
        for _, p in pairs(pages) do
            for _, a in ipairs(p.aliases or {}) do if a:lower() == name then page = p end end
        end
    end
    return page and allowed(page, who) and page or nil
end

local function plain(page)
    return { name = page.name, topic = page.topic, usage = page.usage, aliases = page.aliases, summary = page.summary,
             text = page.text, see = page.see, area = page.area, admin = page.right ~= nil, console = page.console }
end

local function toConsole(list, page)
    if page then
        outputServerLog(("[help] %s%s  (%s)"):format(page.usage or page.name, page.console and "  [console]" or "", page.area))
        if page.aliases then outputServerLog("[help] also: " .. table.concat(page.aliases, ", ")) end
        for line in ((page.text or page.summary or "") .. "\n"):gmatch("(.-)\n") do outputServerLog("[help]   " .. line) end
        if page.see then outputServerLog("[help] see: " .. table.concat(page.see, ", ")) end
        return
    end
    for _, p in ipairs(list) do
        outputServerLog(("[help] %-18s %-14s %s"):format(p.name, p.console and "[console]" or (p.right and "[admin]" or ""), p.summary or ""))
    end
    outputServerLog(("[help] %d pages. help <name> for one."):format(#list))
end

-- /help [name or word]: a page if `arg` names one, else the list (filtered by `arg`).
local function help(source, _, arg)
    local page = arg and exact(source, arg)
    local list = page and {} or visible(source, arg)
    if getElementType(source) == "console" then return toConsole(list, page) end
    if not page and arg and #list == 0 then
        return outputChatBox("Nothing in the manual about " .. arg .. ". Try /help for everything.", source, 255, 200, 120)
    end
    local out = {}
    for i, p in ipairs(list) do out[i] = plain(p) end
    triggerClientEvent(source, "vana-help:open", resourceRoot, out, page and plain(page) or nil, arg)
end

addCommandHandler("help", help)
addCommandHandler("?", help)
addCommandHandler("man", function(source, cmd, arg)
    if not arg then
        if getElementType(source) == "console" then return outputServerLog("[help] Usage: man <command or topic>") end
        return outputChatBox("Usage: /man <command or topic>  (/help lists them)", source, 200, 200, 255)
    end
    help(source, cmd, arg)
end)

-- A page asked for from inside the manual (a "see" link).
addEvent("vana-help:page", true)
addEventHandler("vana-help:page", resourceRoot, function(name)
    local page = type(name) == "string" and exact(client, name)
    if page then triggerClientEvent(client, "vana-help:show", resourceRoot, plain(page)) end
end)

-- Console-only: every command a resource registers has a page, and every page's links lead somewhere.
addCommandHandler("helptest", function(source)
    if getElementType(source) ~= "console" then return end
    local broken, n = {}, 0
    for _, page in pairs(pages) do
        n = n + 1
        for _, s in ipairs(page.see or {}) do if not pages[s:lower()] then broken[#broken + 1] = page.name .. " -> " .. s end end
    end
    outputServerLog(("[helptest] %d pages; %s"):format(n, #broken == 0 and "PASS" or ("FAIL: broken links " .. table.concat(broken, ", "))))
end)
