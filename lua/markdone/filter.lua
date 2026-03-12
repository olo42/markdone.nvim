-- markdone.filter
-- Filter strategies for todo item lists.
-- M.apply(items, opts) is the single entry point; it applies all active
-- filters from opts in sequence and returns the surviving items.
--
-- opts fields (all optional):
--   opts.tag   = "tagname"        -- keep items that have +tagname
--   opts.resp  = "name"           -- keep items that have @name
--   opts.due   = "YYYY-MM-DD"     -- exact date match
--              | "today"          -- due date == today
--              | "tomorrow"       -- due date == tomorrow
--              | "overdue"        -- due date is strictly before today
--              | "week"           -- due date is within the next 7 days

local M = {}

-- Returns today's date as "YYYY-MM-DD".
local function today()
    return os.date("%Y-%m-%d")
end

-- Returns the date N days from today as "YYYY-MM-DD".
-- Uses calendar arithmetic instead of adding raw seconds to avoid DST errors
-- on days where the day is not exactly 86400 seconds long.
local function days_from_today(n)
    local t = os.date("*t")   -- broken-down local time
    t.day = t.day + n
    return os.date("%Y-%m-%d", os.time(t))
end

-- Individual predicates -------------------------------------------------------

local function has_tag(item, tag)
    local needle = tag:lower()
    for _, t in ipairs(item.parsed.tags) do
        if t == needle then return true end
    end
    return false
end

local function has_resp(item, resp)
    local needle = resp:lower()
    for _, r in ipairs(item.parsed.resps) do
        if r == needle then return true end
    end
    return false
end

local function matches_due(item, due_filter)
    local d = item.parsed.due
    if not d then return false end

    if due_filter == "today" then
        return d == today()
    elseif due_filter == "tomorrow" then
        return d == days_from_today(1)
    elseif due_filter == "overdue" then
        return d < today()
    elseif due_filter == "week" then
        local t = today()
        local limit = days_from_today(7)
        return d >= t and d <= limit
    else
        -- treat as exact ISO date
        return d == due_filter
    end
end

-- Public API ------------------------------------------------------------------

function M.apply(items, opts)
    opts = opts or {}
    local result = items

    if opts.tag then
        local tag = opts.tag
        local filtered = {}
        for _, item in ipairs(result) do
            if has_tag(item, tag) then
                table.insert(filtered, item)
            end
        end
        result = filtered
    end

    if opts.resp then
        local resp = opts.resp
        local filtered = {}
        for _, item in ipairs(result) do
            if has_resp(item, resp) then
                table.insert(filtered, item)
            end
        end
        result = filtered
    end

    if opts.due then
        local due_filter = opts.due
        local filtered = {}
        for _, item in ipairs(result) do
            if matches_due(item, due_filter) then
                table.insert(filtered, item)
            end
        end
        result = filtered
    end

    return result
end

return M
