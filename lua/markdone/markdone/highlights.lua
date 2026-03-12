-- markdone.highlights
-- Defines highlight groups for todo metadata and provides helpers used by
-- both the quickfix and picker display surfaces.
--
-- All groups are defined with `default = true` so any colorscheme can
-- override them freely. By default they link to standard Neovim diagnostic
-- and treesitter groups that every theme already covers.
--
-- Groups:
--   MarkdonePriorityA   → DiagnosticError    (A) highest
--   MarkdonePriorityB   → DiagnosticWarn     (B)
--   MarkdonePriorityC   → DiagnosticInfo     (C) / default
--   MarkdonePriorityD   → DiagnosticHint     (D) lowest
--   MarkdoneTag         → @string.special    +tagname
--   MarkdoneResp        → @type              @name
--   MarkdoneDue         → @number            ~date (future / no date)
--   MarkdoneDueToday    → DiagnosticWarn     ~date when == today
--   MarkdoneDueTomorrow → DiagnosticHint     ~date when == tomorrow
--   MarkdoneDueOverdue  → DiagnosticError    ~date when before today

local M = {}

-- Define all highlight groups once on startup.
function M.setup()
    local groups = {
        MarkdonePriorityA   = { link = "DiagnosticError"  },
        MarkdonePriorityB   = { link = "DiagnosticWarn"   },
        MarkdonePriorityC   = { link = "DiagnosticInfo"   },
        MarkdonePriorityD   = { link = "DiagnosticHint"   },
        MarkdoneTag         = { link = "Special"          },
        MarkdoneResp        = { link = "Type"             },
        MarkdoneDue         = { link = "Number"           },
        MarkdoneDueToday    = { link = "DiagnosticWarn"   },
        MarkdoneDueTomorrow = { link = "DiagnosticHint"   },
        MarkdoneDueOverdue  = { link = "DiagnosticError"  },
    }
    for name, opts in pairs(groups) do
        opts.default = true
        vim.api.nvim_set_hl(0, name, opts)
    end
end

-- Returns the highlight group name for a priority marker.
-- prio: "A"|"B"|"C"|"D"|nil  (nil → "C")
function M.priority_hl(prio)
    local map = {
        A = "MarkdonePriorityA",
        B = "MarkdonePriorityB",
        C = "MarkdonePriorityC",
        D = "MarkdonePriorityD",
    }
    return map[prio] or "MarkdonePriorityC"
end

-- Returns the highlight group name for a due date string.
-- due: "YYYY-MM-DD" string or nil — the date portion only, without the ~ prefix
function M.due_hl(due)
    if not due then return "MarkdoneDue" end
    local today    = os.date("%Y-%m-%d")
    local t        = os.date("*t")
    t.day          = t.day + 1
    local tomorrow = os.date("%Y-%m-%d", os.time(t))
    if due < today then
        return "MarkdoneDueOverdue"
    elseif due == today then
        return "MarkdoneDueToday"
    elseif due == tomorrow then
        return "MarkdoneDueTomorrow"
    else
        return "MarkdoneDue"
    end
end

-- ---------------------------------------------------------------------------
-- Quickfix highlighting
-- ---------------------------------------------------------------------------

-- Patterns used with matchadd() in the quickfix window.
-- Each entry is { pattern, hl_group }.
local QF_PATTERNS = {
    -- Priority markers (A)-(D) — one entry per letter so each gets its own colour
    { [[\v\(A\)]],      "MarkdonePriorityA" },
    { [[\v\(B\)]],      "MarkdonePriorityB" },
    { [[\v\(C\)]],      "MarkdonePriorityC" },
    { [[\v\(D\)]],      "MarkdonePriorityD" },
    -- Tags  +word  (case-insensitive)
    { [[\v\c\+\w+]],      "MarkdoneTag"  },
    -- Responsibles  @word — only when @ is preceded by whitespace or BOL  (case-insensitive)
    { [[\v\c(^|\s)\zs\@\w+]], "MarkdoneResp" },
    -- Due dates — base group; overdue/today/tomorrow need per-line logic so
    -- we highlight the token with the base group here and rely on the picker
    -- for the finer-grained colours.
    { [[\v\~\d{4}-\d{2}-\d{2}]], "MarkdoneDue" },
}

-- Namespace for due-date highlights in the quickfix window.
local QF_NS = vim.api.nvim_create_namespace("markdone_qf")

-- Scan the quickfix buffer lines for ~YYYY-MM-DD tokens and apply
-- time-sensitive highlight colours via nvim_buf_add_highlight.
-- Called after apply_qf_matches() so the base MarkdoneDue matchadd is already
-- present; this overwrites it with the precise colour per date.
local function apply_qf_due_highlights(buf)
    vim.api.nvim_buf_clear_namespace(buf, QF_NS, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for lnum, line in ipairs(lines) do
        local search_from = 1
        while true do
            local s, e, date = line:find("~(%d%d%d%d%-%d%d%-%d%d)", search_from)
            if not s then break end
            vim.api.nvim_buf_add_highlight(buf, QF_NS, M.due_hl(date), lnum - 1, s - 1, e)
            search_from = e + 1
        end
    end
end

-- Set up matchadd()-based highlighting for the quickfix window.
-- Safe to call multiple times; guards against duplicate matches.
local function apply_qf_matches()
    -- Only act on the quickfix window.
    if vim.bo.buftype ~= "quickfix" then return end
    local buf = vim.api.nvim_get_current_buf()
    -- Remove any existing markdone matches to avoid duplicates on refresh.
    for _, m in ipairs(vim.fn.getmatches()) do
        if m.group:match("^Markdone") then
            vim.fn.matchdelete(m.id)
        end
    end
    for _, entry in ipairs(QF_PATTERNS) do
        vim.fn.matchadd(entry[2], entry[1])
    end
    apply_qf_due_highlights(buf)
end

-- Register the autocmd that applies highlights whenever a quickfix buffer
-- is opened or refreshed.  Called once from M.setup().
function M.apply_qf()
    vim.api.nvim_create_autocmd("FileType", {
        pattern  = "qf",
        group    = vim.api.nvim_create_augroup("MarkdoneQfHL", { clear = true }),
        callback = apply_qf_matches,
    })
end

-- ---------------------------------------------------------------------------
-- Picker highlight spans
-- ---------------------------------------------------------------------------

-- Given the formatted display text produced by picker.lua and the parsed
-- metadata, return a list of highlight spans:
--   { { hl_group, col = 0-based_byte_start, end_col = exclusive } }
-- These map directly to snacks.picker.Text / Highlight entries.
function M.picker_spans(display_text, parsed)
    local spans = {}

    local function add(group, s, e)
        -- s, e are 1-based indices from string.find; convert to 0-based
        table.insert(spans, { group, col = s - 1, end_col = e })
    end

    -- Priority label "[X] " at the very start (4 bytes)
    add(M.priority_hl(parsed.priority), 1, 4)

    -- Tags  +word  (case-insensitive: search on lowercased copy, offsets are identical)
    local lower_text = display_text:lower()
    local search_from = 1
    while true do
        local s, e = lower_text:find("%+[%w_%-]+", search_from)
        if not s then break end
        add("MarkdoneTag", s, e)
        search_from = e + 1
    end

    -- Responsibles  @word — only when preceded by whitespace or BOL
    -- Prepend a space so we can always match "%s@word" uniformly.
    local padded = " " .. lower_text
    search_from = 1
    while true do
        local s, e = padded:find("%s@[%w_%-]+", search_from)
        if not s then break end
        -- s points at the whitespace; the actual @word starts one byte later.
        -- Adjust back to display_text coordinates (padded is 1 byte longer).
        local real_s = s     -- s+1 in padded == s in display_text (space shifts by 1)
        local real_e = e - 1 -- e in padded == e-1 in display_text
        add("MarkdoneResp", real_s, real_e)
        search_from = e + 1
    end

    -- Due date  ~YYYY-MM-DD
    local s, e = display_text:find("~%d%d%d%d%-%d%d%-%d%d")
    if s then
        add(M.due_hl(parsed.due), s, e)
    end

    return spans
end

-- ---------------------------------------------------------------------------
-- Markdown buffer highlighting
-- ---------------------------------------------------------------------------

-- Namespace for due-date highlights applied via nvim_buf_add_highlight.
-- Using a dedicated namespace makes it easy to clear and reapply on save.
local BUF_NS = vim.api.nvim_create_namespace("markdone_buf")

-- Patterns applied with matchadd() in a markdown window.
-- Due dates are excluded here because they need time-sensitive colours that
-- matchadd() cannot provide; those are handled per-line below.
local BUF_MATCH_PATTERNS = {
    { [[\v\(A\)]],  "MarkdonePriorityA" },
    { [[\v\(B\)]],  "MarkdonePriorityB" },
    { [[\v\(C\)]],  "MarkdonePriorityC" },
    { [[\v\(D\)]],  "MarkdonePriorityD" },
    { [[\v\c\+\w+]], "MarkdoneTag"        },
    -- Responsibles @word — only when @ is preceded by whitespace or BOL  (case-insensitive)
    { [[\v\c(^|\s)\zs\@\w+]], "MarkdoneResp" },
}

-- Scan every line in buf for ~YYYY-MM-DD tokens and apply time-sensitive
-- highlight colours using nvim_buf_add_highlight.
local function apply_due_highlights(buf)
    vim.api.nvim_buf_clear_namespace(buf, BUF_NS, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for lnum, line in ipairs(lines) do
        -- find all ~YYYY-MM-DD occurrences on this line
        local search_from = 1
        while true do
            local s, e, date = line:find("~(%d%d%d%d%-%d%d%-%d%d)", search_from)
            if not s then break end
            local hl = M.due_hl(date)
            -- nvim_buf_add_highlight uses 0-based line, 0-based byte columns
            vim.api.nvim_buf_add_highlight(buf, BUF_NS, hl, lnum - 1, s - 1, e)
            search_from = e + 1
        end
    end
end

-- Apply matchadd()-based highlights to a specific window win.
-- Guards against duplicates by clearing existing Markdone matches in that window first.
local function apply_win_matches(win)
    for _, m in ipairs(vim.fn.getmatches(win)) do
        if m.group:match("^Markdone") then
            vim.fn.matchdelete(m.id, win)
        end
    end
    for _, entry in ipairs(BUF_MATCH_PATTERNS) do
        -- matchadd with window option applies only to the given window
        vim.fn.matchadd(entry[2], entry[1], 10, -1, { window = win })
    end
end

-- Full highlight pass for a markdown buffer: window matches in every window
-- that currently displays buf, plus buffer-scoped due-date spans.
local function highlight_buf(buf)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        apply_win_matches(win)
    end
    apply_due_highlights(buf)
end

-- Register autocmds that keep markdown buffer highlights up-to-date.
-- Called once from M.setup().
function M.apply_buf()
    local group = vim.api.nvim_create_augroup("MarkdoneBufHL", { clear = true })

    -- Initial highlight when a markdown buffer is loaded into a window.
    vim.api.nvim_create_autocmd("FileType", {
        pattern  = "markdown",
        group    = group,
        callback = function(ev)
            highlight_buf(ev.buf)
        end,
    })

    -- Refresh after every save so edited due dates get the correct colour.
    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern  = "*.md",
        group    = group,
        callback = function(ev)
            highlight_buf(ev.buf)
        end,
    })
end

return M
