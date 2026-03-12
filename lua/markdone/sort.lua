-- markdone.sort
-- Sort strategies for todo item lists.
-- All functions take a list of items and return a new sorted list
-- (the original is not mutated).

local M = {}

-- Priority order: A (highest) = 1 … D (lowest) = 4.
-- Items without an explicit priority marker default to C (3).
local priority_order = { A = 1, B = 2, C = 3, D = 4 }

local function priority_key(item)
    local prio = item.parsed and item.parsed.priority
    return priority_order[prio] or priority_order["C"]
end

-- Sentinel for items with no due date — sorts to the end.
local NO_DUE = "9999-99-99"

-- Sort items by priority A → D (items without a marker sort as C).
function M.by_priority(items)
    local sorted = { unpack(items) }
    table.sort(sorted, function(a, b)
        return priority_key(a) < priority_key(b)
    end)
    return sorted
end

-- Sort items by priority first, then by due date as a tiebreaker.
-- Within the same priority, oldest due date comes first; no due date sorts last.
function M.by_priority_then_due(items)
    local sorted = { unpack(items) }
    table.sort(sorted, function(a, b)
        local pa, pb = priority_key(a), priority_key(b)
        if pa ~= pb then return pa < pb end
        local da = (a.parsed and a.parsed.due) or NO_DUE
        local db = (b.parsed and b.parsed.due) or NO_DUE
        return da < db
    end)
    return sorted
end

-- Sort items by due date, oldest first.
-- Items without a due date sort to the end.
function M.by_due(items)
    local sorted = { unpack(items) }
    table.sort(sorted, function(a, b)
        local da = (a.parsed and a.parsed.due) or NO_DUE
        local db = (b.parsed and b.parsed.due) or NO_DUE
        return da < db
    end)
    return sorted
end

return M
