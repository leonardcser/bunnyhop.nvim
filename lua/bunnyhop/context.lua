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
            model = "",
        })
    end

    -- BUG: `gi` (last insert location) is being killed by our method, we should save that as well
    vim.cmd("silent undo " .. ut.seq_cur)
    vim.api.nvim_win_set_cursor(0, cursor)

    return editlist
end

---Gets the most recently modified file (excluding current buffer)
---@return string?, string?
local function get_last_modified_file_diff()
    local current_buf_name = vim.api.nvim_buf_get_name(0)
    local current_dir = vim.fn.getcwd()
    
    -- Get all buffers and their modification times
    local buffers_info = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted') then
            local buf_name = vim.api.nvim_buf_get_name(buf)
            if buf_name ~= "" and buf_name ~= current_buf_name and buf_name:find(current_dir, 1, true) == 1 then
                local stat = vim.loop.fs_stat(buf_name)
                if stat then
                    table.insert(buffers_info, {
                        name = buf_name,
                        mtime = stat.mtime.sec,
                        buf = buf
                    })
                end
            end
        end
    end
    
    -- Sort by modification time (most recent first)
    table.sort(buffers_info, function(a, b) return a.mtime > b.mtime end)
    
    if #buffers_info == 0 then
        return nil, nil
    end
    
    local last_modified = buffers_info[1]
    
    -- Try to get git diff for the file
    local git_diff_cmd = string.format("git diff HEAD -- %s", vim.fn.shellescape(last_modified.name))
    local git_diff = vim.fn.system(git_diff_cmd)
    
    if vim.v.shell_error == 0 and git_diff ~= "" then
        return last_modified.name, git_diff
    end
    
    -- Fallback: try to get diff from buffer's undo history
    local current_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(last_modified.buf)
    local success, result = pcall(function()
        local editlist = M.build_editlist(1)
        if #editlist > 0 then
            return editlist[1].diff
        end
        return nil
    end)
    vim.api.nvim_set_current_buf(current_buf)
    
    if success and result then
        return last_modified.name, result
    end
    
    return last_modified.name, nil
end

---Creates prompt
---@return string
function M.create_prompt()
    -- Get recent edit history with diffs
    local editlist = M.build_editlist(4)
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

    -- Get last modified file diff
    local last_modified_file, last_modified_diff = get_last_modified_file_diff()
    local last_modified_context = ""
    if last_modified_file and last_modified_diff then
        local relative_path = vim.fn.fnamemodify(last_modified_file, ":~:.")
        last_modified_context = "## Last Modified File: " .. relative_path .. "\n"
            .. "```diff\n"
            .. last_modified_diff
            .. "\n```\n\n"
    end

    local context = ""
    local current_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    
    -- Only process the current buffer
    local file_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false) or {}
    
    -- Add line numbers to file content
    local numbered_content = ""
    
    for i, line in ipairs(file_lines) do
        numbered_content = numbered_content .. string.format("%4d: %s\n", i, line)
    end

    -- Get current cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_cursor_info = string.format("## Current Cursor Position\nLine: %d, Column: %d\n\n", cursor[1], cursor[2])

    context = buf_name .. " (LIVE - includes unsaved changes)"
        .. "\n"
        .. current_cursor_info
        .. "## File Content (with line numbers)\n"
        .. numbered_content

    local prompt = "You are predicting where a programmer will move their cursor next.\n\n"
        .. "KEY TASK: Look for incomplete edits that need finishing.\n\n"
        .. "COMMON PATTERNS:\n"
        .. "- Variable renaming: if renamed in one location, likely needs renaming elsewhere\n"
        .. "- Function definitions: after defining, often used/called elsewhere\n"
        .. "- Similar structures: patterns often repeat (imports, assignments, etc.)\n"
        .. "- Error fixing: inconsistent variable names, missing semicolons, etc.\n\n"
        .. "- Linting errors: unused variables, unused imports, etc.\n\n"
        .. "HOW TO PREDICT:\n"
        .. "1. Look at recent edits - what was changed?\n"
        .. "2. Scan the file for similar patterns that weren't changed yet\n"
        .. "3. Consider changes in other recently modified files for related patterns\n"
        .. "4. Predict the cursor will go to the next logical place to make the same change\n\n"
        .. "RESPONSE FORMAT - MANDATORY:\n"
        .. "You MUST respond with ONLY the cursor position in this exact format: [line, column]\n"
        .. "- Line numbers start at 1\n"
        .. "- Column numbers start at 1 and refer to the position within the actual text content\n"
        .. "- Do NOT include any explanation or reasoning\n"
        .. "- Do NOT include any other text\n\n"
        .. "EXAMPLE:\n"
        .. "If you predict the cursor should go to line 42, column 15, respond with exactly:\n"
        .. "[42, 15]\n\n"
        .. last_modified_context
        .. recent_edits
        .. "# File Context\n"
        .. context

    return prompt
end
return M
