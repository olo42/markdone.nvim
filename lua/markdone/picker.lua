-- markdone.picker
-- Snacks.picker integration for markdone.
-- Opens a picker showing todo items instead of the quickfix list.
--
-- Each item displays:
--   [priority] text  +tag @resp  ~date
-- with metadata tokens highlighted using the Markdone* highlight groups.
--
-- Selecting an item jumps to the file + line.

local hl = require("markdone.highlights")

local M = {}

-- Priority label, always 4 characters so columns stay aligned.
local prio_label = { A = "[A]", B = "[B]", C = "[C]", D = "[D]" }

-- Build the plain display text for one item.
local function format_text(item)
    local p     = item.parsed
    local label = prio_label[p.priority] or "[C]"

    local meta = {}
    for _, t in ipairs(p.tags)  do table.insert(meta, "+" .. t)  end
    for _, r in ipairs(p.resps) do table.insert(meta, "@" .. r)  end
    if p.due then table.insert(meta, "~" .. p.due) end

    local suffix = #meta > 0 and ("  " .. table.concat(meta, " ")) or ""
    return label .. " " .. p.text .. suffix
end

-- Custom snacks formatter: returns a list of highlighted text segments.
-- The snacks picker format function signature is:
--   fun(item, picker) -> snacks.picker.Highlight[]
local function todo_format(item, _picker)
    local display = item.text   -- set in picker_items below
    local parsed  = item._markdone and item._markdone.parsed

    if not parsed then
        -- fallback: plain text
        return { { display, "Normal" } }
    end

    -- Build spans from highlights module.
    local spans = hl.picker_spans(display, parsed)

    -- Convert span list into snacks Highlight segments.
    -- Strategy: walk the display string byte by byte, emitting segments
    -- for each span; anything not covered gets "Normal".
    local segments = {}
    local pos = 0  -- current byte position (0-based)
    local len = #display

    -- Sort spans by start position.
    table.sort(spans, function(a, b) return a.col < b.col end)

    for _, span in ipairs(spans) do
        if span.col > pos then
            -- unstyled gap before this span
            table.insert(segments, { display:sub(pos + 1, span.col), "Normal" })
        end
        if span.col >= pos then
            -- span.end_col is already exclusive (0-based end = inclusive 1-based index)
            table.insert(segments, { display:sub(span.col + 1, span.end_col), span[1] })
            pos = span.end_col
        end
    end

    -- trailing unstyled text
    if pos < len then
        table.insert(segments, { display:sub(pos + 1), "Normal" })
    end

    return segments
end

-- Open a Snacks picker showing the given items list.
-- items: the list produced by search.run (filename/lnum/col/text/parsed).
-- title: picker window title string.
function M.open(items, title)
    local ok, snacks = pcall(require, "snacks")
    if not ok then
        vim.notify("markdone: snacks.nvim not available", vim.log.levels.ERROR)
        return
    end

    local picker_items = {}
    for _, item in ipairs(items) do
        table.insert(picker_items, {
            text     = format_text(item),
            file     = item.filename,
            pos      = { item.lnum, item.col - 1 },
            _markdone  = item,
        })
    end

    snacks.picker.pick({
        source  = "markdone",
        title   = title or "Markdown Tasks",
        items   = picker_items,
        format  = todo_format,
        preview = "file",
    })
end

return M
