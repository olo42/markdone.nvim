-- markdone.commands
-- Registers the single :Todo user command.
--
-- Usage:
--   :Todo [subcommand] [tokens...]
--
-- Subcommands:
--   all    search all checkboxes (open and done)
--   open   search open checkboxes only  [ ]
--   done   search done checkboxes only  [x] / [X]
--
-- If no subcommand is given and a default_filter is configured, that default
-- is used.  Otherwise an error is shown.
--
-- Tokens (all optional, space-separated, after the subcommand):
--   sort:prio              sort results A → D (no marker = C)
--   sort:due               sort results by due date, oldest first
--   sort:prio+due          sort by priority, then due date as tiebreaker
--   tag:<name>             keep only items with +<name>
--   resp:<name>            keep only items with @<name>
--   due:today              due date == today
--   due:tomorrow           due date == tomorrow
--   due:overdue            due date is strictly before today
--   due:week               due date within the next 7 days
--   due:YYYY-MM-DD         exact date match (file syntax for dates is ~YYYY-MM-DD)
--   picker                 show results in Snacks picker instead of quickfix
--
-- Multiple filters are AND-combined.
-- Examples:
--   :Todo open sort:prio tag:work resp:olli due:overdue
--   :Todo all picker sort:due
--   :Todo done picker tag:work
--   :Todo due:today sort:prio+due   ← uses default_filter if configured

local search = require("markdone.search")
local sort   = require("markdone.sort")
local filter = require("markdone.filter")

local M = {}

local SUBCOMMANDS = { all = true, open = true, done = true }

local PATTERNS = {
    all  = search.patterns.all,
    open = search.patterns.open,
    done = search.patterns.done,
}

local TITLES = {
    all  = "All Tasks",
    open = "Open Tasks",
    done = "Done Tasks",
}

-- Parse a space-separated argument string into { subcommand, opts }.
-- The first token is treated as the subcommand if it matches a known keyword;
-- otherwise the default_filter is used as the subcommand and all tokens are
-- treated as filter/sort/display options.
-- default_sort is applied only when no sort: token is present in the args.
local function parse_args(arg_str, default_filter, default_sort)
    local tokens = {}
    for token in (arg_str or ""):gmatch("%S+") do
        table.insert(tokens, token)
    end

    local subcommand = nil
    local start = 1

    if tokens[1] and SUBCOMMANDS[tokens[1]] then
        subcommand = tokens[1]
        start = 2
    elseif default_filter and SUBCOMMANDS[default_filter] then
        subcommand = default_filter
        start = 1
    end

    local opts = {}
    for i = start, #tokens do
        local token = tokens[i]
        if token == "picker" then
            opts.display = "picker"
        else
            local key, val = token:match("^(%a+):(.+)$")
            if key == "sort" then opts.sort = val end
            if key == "tag"  then opts.tag  = val end
            if key == "resp" then opts.resp = val end
            if key == "due"  then opts.due  = val end
        end
    end

    -- Apply default_sort only when no explicit sort: token was given.
    if not opts.sort and default_sort then
        opts.sort = default_sort
    end

    return subcommand, opts
end

local function run(subcommand, opts)
    local pat   = PATTERNS[subcommand]
    local title = TITLES[subcommand]

    search.run(pat, function(items, err)
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        if not items or #items == 0 then
            vim.notify("No matches.", vim.log.levels.INFO)
            return
        end

        -- Apply filters
        items = filter.apply(items, opts)

        if #items == 0 then
            vim.notify("No matches after filtering.", vim.log.levels.INFO)
            return
        end

        -- Apply sort
        if opts.sort == "prio" then
            items = sort.by_priority(items)
        elseif opts.sort == "due" then
            items = sort.by_due(items)
        elseif opts.sort == "prio+due" then
            items = sort.by_priority_then_due(items)
        end

        -- Display
        if opts.display == "picker" then
            require("markdone.picker").open(items, title)
        else
            vim.fn.setqflist({}, " ", { title = title, items = items })
            vim.cmd("copen")
        end
    end)
end

-- cfg: the config table passed to setup(), used for default_filter and default_sort.
function M.setup(cfg)
    local default_filter = cfg and cfg.default_filter
    local default_sort   = cfg and cfg.default_sort

    vim.api.nvim_create_user_command("Todo", function(cmd_opts)
        local subcommand, opts = parse_args(cmd_opts.args, default_filter, default_sort)
        if not subcommand then
            vim.notify(
                "Todo: subcommand required. Usage: Todo <all|open|done> [tokens...]\n" ..
                "Set default_filter in setup() to make the subcommand optional.",
                vim.log.levels.ERROR
            )
            return
        end
        run(subcommand, opts)
    end, {
        nargs = "*",
        complete = function(arglead, cmdline, _)
            -- Offer subcommand completions when typing the first word.
            local args = {}
            for w in cmdline:gmatch("%S+") do table.insert(args, w) end
            -- args[1] is "Todo"; if only one more word is being typed, complete subcommands
            if #args == 1 or (#args == 2 and not cmdline:match("%s$")) then
                local candidates = { "all", "open", "done" }
                local result = {}
                for _, c in ipairs(candidates) do
                    if c:find("^" .. arglead) then
                        table.insert(result, c)
                    end
                end
                return result
            end
        end,
    })
end

return M
