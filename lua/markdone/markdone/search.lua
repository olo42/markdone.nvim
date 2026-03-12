-- markdone.search
-- Runs ripgrep for todo checkboxes and returns a list of parsed items
-- via a callback.
--
-- Each item in the list has the quickfix shape plus parsed metadata:
-- {
--   filename = "path/to/file.md",
--   lnum     = 12,
--   col      = 1,
--   text     = "- [ ] (A) Some text +tag ~2026-03-12 @olli",  -- raw line
--   parsed   = { done, priority, tags, resps, due, text },
-- }

local parse = require("markdone.parse")

local M = {}

M.patterns = {
    all  = [[^\s*[-*+]\s\[[ xX]\]\s.*]],
    open = [[^\s*[-*+]\s\[\s\]\s.*]],
    done = [[^\s*[-*+]\s\[[xX]\]\s.*]],
}

local function relpath(path)
    return vim.fn.fnamemodify(path, ":.")
end

-- Runs rg with the given pattern and calls callback(items) on success,
-- or callback(nil, err_message) on failure.
function M.run(pat, callback)
    if vim.fn.executable("rg") ~= 1 then
        callback(nil, "ripgrep (rg) not found")
        return
    end

    local args = {
        "rg", "--vimgrep", "--no-heading", "--pcre2",
        pat,
        "--glob=*.md", "--glob=!node_modules", "--glob=!.git",
    }

    vim.system(args, { text = true, cwd = vim.uv.cwd() }, function(res)
        vim.schedule(function()
            if not res then
                callback(nil, "rg returned no result")
                return
            end
            if res.code == 2 then
                -- rg exit 2 = actual error (bad pattern, permission, etc.)
                callback(nil, "rg error: " .. vim.trim(res.stderr or "unknown error"))
                return
            end
            if res.code == 1 then
                -- rg exit 1 = no matches found; not an error
                callback({})
                return
            end

            local items = {}
            for line in (res.stdout or ""):gmatch("[^\r\n]+") do
                local f, l, c, m = line:match("^(.-):(%d+):(%d+):(.*)$")
                if f then
                    table.insert(items, {
                        filename = relpath(f),
                        lnum     = tonumber(l),
                        col      = tonumber(c),
                        text     = m,
                        parsed   = parse.line(m),
                    })
                end
            end

            callback(items)
        end)
    end)
end

return M
