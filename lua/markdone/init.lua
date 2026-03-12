-- markdone
-- Public entry point for the markdone plugin.
-- Call require("markdone").setup() to register all user commands and highlights.
--
-- Optional config fields:
--   default_filter = "open"|"all"|"done"
--     When set, :Todo with no subcommand uses this filter instead of showing
--     an error.  Example: require("markdone").setup({ default_filter = "open" })
--   default_sort = "prio"|"due"|"prio+due"
--     When set, applied automatically unless an explicit sort: token is given.
--     Example: require("markdone").setup({ default_sort = "prio" })

local M = {}

function M.setup(cfg)
    local hl = require("markdone.highlights")
    hl.setup()     -- define highlight groups
    hl.apply_qf()  -- register FileType qf autocmd
    hl.apply_buf() -- register FileType markdown + BufWritePost autocmds
    require("markdone.commands").setup(cfg)
end

return M
