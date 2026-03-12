-- markdone.parse
-- Parses a raw todo line string into a structured record.
--
-- Expected format (all metadata fields are optional):
--   - [ ] (A) Some text +tag ~2026-03-12 @olli
--
-- Returns a table:
-- {
--   done     = false,
--   priority = "A",           -- nil if absent
--   tags     = { "tag" },     -- may be empty
--   resps    = { "olli" },    -- may be empty
--   due      = "2026-03-12",  -- nil if absent
--   text     = "Some text",   -- content minus all metadata tokens
-- }

local M = {}

function M.line(raw)
    local result = {
        done     = false,
        priority = nil,
        tags     = {},
        resps    = {},
        due      = nil,
        text     = "",
    }

    -- Detect done state from the checkbox marker
    if raw:match("%[[xX]%]") then
        result.done = true
    end

    -- Strip the leading list marker and checkbox: "- [ ] " / "- [x] " etc.
    local content = raw:gsub("^%s*[-*+]%s+%[[%s xX]%]%s*", "")

    -- Extract priority marker (A)-(D) at the very start of the remaining content
    local prio = content:match("^%(([A-D])%)%s*")
    if prio then
        result.priority = prio
        content = content:gsub("^%([A-D]%)%s*", "")
    end

    -- Extract due date token "~YYYY-MM-DD"
    local due = content:match("~(%d%d%d%d%-%d%d%-%d%d)")
    if due then
        result.due = due
        content = content:gsub("%s*~%d%d%d%d%-%d%d%-%d%d", "")
    end

    -- Extract tags "+tagname" — stored lowercase for case-insensitive matching
    for tag in content:gmatch("%+([%w_%-]+)") do
        table.insert(result.tags, tag:lower())
    end
    content = content:gsub("%s*%+[%w_%-]+", "")

    -- Extract responsibles "@name" — only when @ is preceded by whitespace or
    -- is at the start of the content (prevents matching emails like foo@bar).
    -- Lua has no lookbehind, so we prepend a space and match "%s@word".
    -- Stored lowercase for case-insensitive matching.
    local padded = " " .. content
    for resp in padded:gmatch("%s@([%w_%-]+)") do
        table.insert(result.resps, resp:lower())
    end
    content = content:gsub("^@[%w_%-]+%s*", ""):gsub("%s@[%w_%-]+", "")

    result.text = vim.trim(content)

    return result
end

return M
