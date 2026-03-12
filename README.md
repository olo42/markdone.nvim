# markdone.nvim

A Neovim plugin for managing markdown-based todo lists. Searches `.md` files
for task checkboxes, supports priority, tags, responsibles and due dates, and
shows results in either the quickfix list or a [Snacks](https://github.com/folke/snacks.nvim) picker.

## Requirements

- Neovim 0.10+
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) on `$PATH`
- [snacks.nvim](https://github.com/folke/snacks.nvim) — optional, required only for the `picker` display mode

## Task format

Tasks are standard markdown checkboxes with optional metadata fields. All
fields except the checkbox itself are optional and can appear in any order
after the priority marker.

```
- [ ] (A) Buy milk +groceries ~2026-03-15 @olli
- [x] (B) Write report +work ~2026-03-12 @anna
- [ ] Fix the bug +work @olli
- [ ] (D) Low priority task
```

| Field | Syntax | Example | Notes |
|---|---|---|---|
| Checkbox | `- [ ]` / `- [x]` | `- [ ]` | `*` and `+` list markers also work |
| Priority | `(A)` – `(D)` | `(B)` | Must come directly after the checkbox. Omitted = treated as `C` |
| Tag | `+name` | `+work` | Multiple tags allowed. Case-insensitive (`+Work` == `+work`). |
| Responsible | `@name` | `@olli` | Multiple responsibles allowed. Must be preceded by a space (e-mail addresses are not matched). Case-insensitive (`@Olli` == `@olli`). |
| Due date | `~YYYY-MM-DD` | `~2026-03-15` | ISO 8601 date |

## Commands

`:Todo` searches `.md` files recursively from the current working directory
(ignoring `node_modules/` and `.git/`).

```
:Todo <subcommand> [tokens...]
```

| Subcommand | Searches for |
|---|---|
| `all` | All checkboxes (open and done) |
| `open` | Open checkboxes `[ ]` only |
| `done` | Done checkboxes `[x]` / `[X]` only |

The subcommand can be omitted if `default_filter` is set in the config.

### Sort tokens

| Token | Behaviour |
|---|---|
| `sort:prio` | Sort by priority A → B → C → D. Items without a marker sort as C. |
| `sort:due` | Sort by due date, oldest first. Items without a due date sort last. |
| `sort:prio+due` | Sort by priority, then by due date as a tiebreaker within the same priority. |

A default sort can be configured via `default_sort` (see Configuration). An
explicit `sort:` token always overrides it.

### Filter tokens

All active filters are AND-combined.

| Token | Keeps items where… |
|---|---|
| `tag:<name>` | `+<name>` is present (case-insensitive) |
| `resp:<name>` | `@<name>` is present (case-insensitive) |
| `due:today` | Due date == today |
| `due:tomorrow` | Due date == tomorrow |
| `due:overdue` | Due date is strictly before today |
| `due:week` | Due date is within the next 7 days (inclusive) |
| `due:YYYY-MM-DD` | Due date matches exactly |

### Display tokens

| Token | Behaviour |
|---|---|
| _(none)_ | Results go to the quickfix list (`:copen`) |
| `picker` | Results open in a Snacks picker with file preview |

### Examples

```
:Todo open sort:prio tag:work resp:olli due:overdue
:Todo all picker sort:prio+due
:Todo done picker tag:work
:Todo due:today                   " requires default_filter to be set
```

## Configuration

```lua
require("markdone").setup({
    -- Make :Todo with no subcommand default to open tasks.
    default_filter = "open",   -- "open" | "all" | "done"

    -- Always sort by priority unless an explicit sort: token is given.
    default_sort = "prio",     -- "prio" | "due" | "prio+due"
})
```

All config fields are optional. Calling `setup()` with no arguments is valid.

## Installation

The plugin lives inside your Neovim config directory as a lazy.nvim local
plugin. Add the following spec to `lua/plugins/markdone.lua`:

```lua
return {
    dir    = vim.fn.stdpath("config"),
    name   = "markdone.nvim",
    lazy   = false,
    config = function()
        require("markdone").setup({
            -- default_filter = "open",
            -- default_sort   = "prio",
        })
    end,
}
```

## Highlight groups

All groups are defined with `default = true` so any colorscheme can override
them freely.

| Group | Default link | Used for |
|---|---|---|
| `MarkdonePriorityA` | `DiagnosticError` | `(A)` priority marker |
| `MarkdonePriorityB` | `DiagnosticWarn` | `(B)` priority marker |
| `MarkdonePriorityC` | `DiagnosticInfo` | `(C)` / no marker |
| `MarkdonePriorityD` | `DiagnosticHint` | `(D)` priority marker |
| `MarkdoneTag` | `Special` | `+tag` tokens |
| `MarkdoneResp` | `Type` | `@responsible` tokens |
| `MarkdoneDue` | `Number` | `~date` — future or undated |
| `MarkdoneDueToday` | `DiagnosticWarn` | `~date` — due today |
| `MarkdoneDueTomorrow` | `DiagnosticHint` | `~date` — due tomorrow |
| `MarkdoneDueOverdue` | `DiagnosticError` | `~date` — past due |

Highlights are applied in three surfaces: the quickfix window, the Snacks
picker, and normal markdown buffers (refreshed on `BufWritePost`).

## Architecture

```
lua/markdone/
├── init.lua        -- public entry point: require("markdone").setup()
├── commands.lua    -- :Todo command registration and argument parsing
├── search.lua      -- ripgrep integration
├── parse.lua       -- parses a raw todo line into structured fields
├── filter.lua      -- tag / responsible / due date filter functions
├── sort.lua        -- priority and due date sort functions
├── picker.lua      -- Snacks picker integration (optional)
└── highlights.lua  -- highlight group definitions and application
```

## Keymaps

No keymaps are defined by default. Add your own in your config, for example:

```lua
vim.keymap.set("n", "<leader>to", "<cmd>Todo open sort:prio picker<cr>", { desc = "Todo: open tasks" })
vim.keymap.set("n", "<leader>ta", "<cmd>Todo all  sort:prio picker<cr>", { desc = "Todo: all tasks"  })
vim.keymap.set("n", "<leader>td", "<cmd>Todo done picker<cr>",           { desc = "Todo: done tasks" })
```
