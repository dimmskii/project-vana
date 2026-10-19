-- The manual: every running resource's help pages (their help.lua, through getHelpPages), shown to
-- each player as they may use them: a page with a `right` only to players the ACL gives it, console
-- pages only at the console. /help, /? and /man print to the chat, a page at a time, and the whole
-- of it to the player's console (F8). (desktop_client.lua keeps the old window for later.)
local pages = {}   -- name -> page (with .resource)
local AREAS = {    -- resource -> the area its pages are listed under
    ["vana-player"] = "Players", ["vana-vehicles"] = "Vehicles", ["vana-radio"] = "Radio", ["vana-traffic"] = "Traffic",
    ["vana-peds"] = "Pedestrians", ["vana-services"] = "Police and events", ["vana-shops"] = "Shops and garages",
    ["vana-activities"] = "Activities", ["vana-wildlife"] = "Wildlife", ["vana-help"] = "Help",
    ["vana-controls"] = "Controls",
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

-- In the chat: a page's lines, CHAT_LINES at a time ("/man <name> 2" for the next), all of them in
-- the console.
local CHAT_LINES = 8
local TITLE, DIM, TEXT = "#ACCBF1", "#9A9A9A", "#FFFFFF"

local function pageLines(page)
    local lines = {}
    local title = page.topic and page.name or (page.usage or ("/" .. page.name))
    lines[1] = TITLE .. title .. (page.right and (DIM .. "  (admin)") or "")
    if page.aliases and #page.aliases > 0 then lines[#lines + 1] = DIM .. "Also: /" .. table.concat(page.aliases, ", /") end
    for line in ((page.text or page.summary or "") .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then lines[#lines + 1] = TEXT .. line end
    end
    if page.see and #page.see > 0 then lines[#lines + 1] = DIM .. "See also: " .. table.concat(page.see, ", ") end
    return lines
end

local function listLines(list, query)
    local lines, areas, order = {}, {}, {}
    for _, p in ipairs(list) do
        if not areas[p.area] then areas[p.area] = {} order[#order + 1] = p.area end
        local names = areas[p.area]
        names[#names + 1] = p.topic and p.name or ("/" .. p.name)
    end
    lines[1] = TITLE .. (query and ("Manual: " .. query) or "Manual") .. DIM .. ("  (%d pages: /man <name> for one)"):format(#list)
    for _, area in ipairs(order) do lines[#lines + 1] = TITLE .. area .. ": " .. TEXT .. table.concat(areas[area], ", ") end
    return lines
end

local function strip(s) return (s:gsub("#%x%x%x%x%x%x", "")) end

local function say(player, lines, part, more)
    for _, line in ipairs(lines) do outputConsole(strip(line), player) end
    local first = (part - 1) * CHAT_LINES + 1
    if first > #lines then first, part = 1, 1 end
    for i = first, math.min(#lines, first + CHAT_LINES - 1) do outputChatBox(lines[i], player, 255, 255, 255, true) end
    if #lines >= first + CHAT_LINES then
        outputChatBox(DIM .. ("(more: %s %d, or the console, F8)"):format(more, part + 1), player, 255, 255, 255, true)
    end
end

-- /help [name or word] [part]: a page if `arg` names one, else the list (filtered by `arg`).
local function help(source, cmd, arg, part)
    if arg and tonumber(arg) and not part then arg, part = nil, arg end
    part = math.max(1, math.floor(tonumber(part) or 1))
    local page = arg and exact(source, arg)
    local list = page and {} or visible(source, arg)
    if getElementType(source) == "console" then return toConsole(list, page) end
    if not page and arg and #list == 0 then
        return outputChatBox("Nothing in the manual about " .. arg .. ". Try /? for everything.", source, 255, 200, 120)
    end
    if page then
        say(source, pageLines(page), part, "/man " .. page.name)
    else
        say(source, listLines(list, arg), part, "/" .. cmd .. (arg and (" " .. arg) or ""))
    end
end

addCommandHandler("help", help)
addCommandHandler("?", help)
addCommandHandler("man", function(source, cmd, arg, part)
    if not arg then
        if getElementType(source) == "console" then return outputServerLog("[help] Usage: man <command or topic>") end
        return outputChatBox("Usage: /man <command or topic>  (/? lists them)", source, 200, 200, 255)
    end
    help(source, cmd, arg, part)
end)

-- The commands a player may use, for /interact's suggestions (vana-controls): name, what follows it,
-- the summary.
addEvent("vana-help:commands", true)
addEventHandler("vana-help:commands", root, function()
    local out = {}
    for _, p in ipairs(visible(client)) do
        if not p.topic and not p.console then
            out[#out + 1] = { name = p.name, usage = p.usage and p.usage:gsub("^/%S+%s*", "") or nil, summary = p.summary }
        end
    end
    triggerClientEvent(client, "vana-help:commands", resourceRoot, out)
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
