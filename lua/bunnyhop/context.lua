local bhop_log = require("bunnyhop.log")

local M = {}

---Builds editlist of the current buffer
---@param n_latest? number n latest undootree entires to build the editlist from.
---@return bhop.UndoEntry[]
function M.build_editlist(n_latest)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local ut = vim.fn.undotree()

    local editlist = {}
    -- create diffs for each entry in our undotree
    local stop = 1
    if n_latest ~= nil then
        stop = #ut.entries - (n_latest - 1)
    end
    for i = #ut.entries, stop, -1 do
        -- grab the buffer as it is after this iteration's undo state
        local success = pcall(function()
            vim.cmd("silent undo " .. ut.entries[i].seq)
        end)
        if not success then
            bhop_log.notify(
                "Encountered a bad state in nvim's native undolist for buffer "
                    .. vim.api.nvim_buf_get_name(0),
                vim.log.levels.DEBUG
            )
            break
        end
        local buffer_after_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) or {}
        local buffer_after = table.concat(buffer_after_lines, "\n")

        -- grab the buffer as it is after this undo state's parent
        success = pcall(function()
            vim.cmd("silent undo")
        end)
        if not success then
            bhop_log.notify(
                "Encountered a bad state in nvim's native undolist for buffer "
                    .. vim.api.nvim_buf_get_name(0),
                vim.log.levels.DEBUG
            )
            break
        end
        local buffer_before_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) or {}
        local buffer_before = table.concat(buffer_before_lines, "\n")

        local filename = vim.fn.expand("%")
        local header = filename .. "\n--- " .. filename .. "\n+++ " .. filename .. "\n"
        ---@type string
        ---@diagnostic disable-next-line: assign-type-mismatch
        local diff = vim.diff(buffer_before, buffer_after)
        local line_match = diff:match("@@ %-%d+")
        ---@type number?
        local line = 1
        if line_match ~= nil then
            line = tonumber(line_match:sub(5))
        end

        table.insert(editlist, {
            seq = ut.entries[i].seq, -- state number
            time = ut.entries[i].time, -- state time
            diff = header .. diff, -- the diff of what was edited
            file = vim.api.nvim_buf_get_name(0), -- edited file
            line = line, -- starting edited line number
            prediction_line = -1,
            prediction_file = "",
            model = "",
        })
    end

    -- BUG: `gi` (last insert location) is being killed by our method, we should save that as well
    vim.cmd("silent undo " .. ut.seq_cur)
    vim.api.nvim_win_set_cursor(0, cursor)

    return editlist
end

---Creates prompt
---@return string
function M.create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line
    -- bufnr -> buffer_name
    -- col -> column
    local jumplist = vim.fn.getjumplist()[1]
    local visited_files = {}

    for _, jump_row in pairs(jumplist) do
        local buf_num = jump_row["bufnr"]
        if
            vim.fn.bufexists(buf_num) == 0
            or vim.api.nvim_buf_is_valid(buf_num) == false
        then
            goto continue
        end
        local buf_name = vim.api.nvim_buf_get_name(buf_num)
        if
            #buf_name == 0
            or buf_name:match(".") == nil
            or buf_name:match(".git") ~= nil
            or buf_name:match(vim.fn.getcwd()) == nil
        then
            goto continue
        end
        if visited_files[buf_num] == nil then
            visited_files[buf_num] = buf_name
        end
        ::continue::
    end

    -- Get recent edit history with diffs
    local editlist = M.build_editlist(2) -- Get last 2 edits
    local recent_edits = ""
    if #editlist > 0 then
        recent_edits = "## Recent Edit History (most recent first)\n"
        for i, edit in ipairs(editlist) do
            recent_edits = recent_edits
                .. "### Edit " .. i .. " (line " .. (edit.line or "unknown") .. ")\n"
                .. "```diff\n"
                .. edit.diff
                .. "\n```\n\n"
        end
    end

    local CHANGELIST_COLUMNS = { "index", "line", "column" }
    local CHANGELIST_MAX_SIZE = 15 -- Reduced to make room for diffs
    local context = ""
    for buf_num, buf_name in pairs(visited_files) do
        local file_content = ""
        local file = io.open(buf_name, "r")
        if file == nil then
            bhop_log.notify("Wasn't able to open " .. buf_name, vim.log.levels.DEBUG)
        else
            file_content = file:read("*a")
            file:close()
            if file_content == nil then
                file_content = ""
            end
        end

        local changelist_csv = ""
        local changelist = vim.fn.getchangelist(buf_num)[1]
        local changelist_start = vim.fn.max { 1, #changelist - CHANGELIST_MAX_SIZE }
        changelist = vim.fn.slice(changelist, changelist_start, #changelist)
        if #changelist == 0 then
            goto continue
        end
        for indx, change_row in pairs(changelist) do
            changelist_csv = changelist_csv
                .. indx
                .. ","
                .. change_row["lnum"]
                .. ","
                .. change_row["col"]
                .. "\n"
        end
        context = context
            .. buf_name
            .. "\n"
            .. "## Current Buffer Content\n"
            .. file_content
            .. "\n"
            .. "## Cursor Position History\n"
            .. table.concat(CHANGELIST_COLUMNS, ",")
            .. "\n"
            .. changelist_csv
            .. "\n"
        ::continue::
    end

    local prompt = "Predict the next cursor position based on editing patterns and context.\n"
        .. "ANALYZE:\n"
        .. "1. Recent edits show what changes were made\n"
        .. "2. Cursor history shows movement patterns\n"
        .. "3. Current content shows the file state\n"
        .. "4. Look for patterns like: variable renaming, function calls, similar code structures\n\n"
        .. "OUTPUT FORMAT: [line, column, \"buffer_name\"]\n"
        .. "- line: predicted line number (1-indexed)\n"
        .. "- column: predicted column number (0-indexed)\n"
        .. "- buffer_name: just the filename (e.g., \"test.js\" not full path)\n\n"
        .. recent_edits
        .. "# File Context\n"
        .. context

    return prompt
end
return M
