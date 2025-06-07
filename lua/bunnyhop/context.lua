local bhop_log = require("bunnyhop.log")

local M = {}

---Validates the undo tree state for the current buffer
---@return boolean
local function validate_undo_tree()
    local ut = vim.fn.undotree()
    if not ut or not ut.entries then
        return false
    end
    
    -- Check if current sequence is valid
    if not ut.seq_cur or ut.seq_cur < 0 then
        return false
    end
    
    -- Check if entries are properly structured
    for i, entry in ipairs(ut.entries) do
        if not entry or not entry.seq or entry.seq < 0 then
            bhop_log.notify(
                "Invalid undo entry at index " .. i .. " (seq: " .. tostring(entry and entry.seq or "nil") .. ")",
                vim.log.levels.DEBUG
            )
            return false
        end
    end
    
    return true
end

---Builds editlist of the current buffer
---@param n_latest? number n latest undootree entires to build the editlist from.
---@return bhop.UndoEntry[]
function M.build_editlist(n_latest)
    local cursor = vim.api.nvim_win_get_cursor(0)
    
    -- Validate undo tree state first
    if not validate_undo_tree() then
        bhop_log.notify(
            "Invalid or corrupted undo tree for buffer " .. vim.api.nvim_buf_get_name(0),
            vim.log.levels.DEBUG
        )
        return {}
    end
    
    local ut = vim.fn.undotree()
    
    -- Double-check after validation
    if not ut or not ut.entries or #ut.entries == 0 then
        bhop_log.notify(
            "No undo history available for buffer " .. vim.api.nvim_buf_get_name(0),
            vim.log.levels.DEBUG
        )
        return {}
    end

    -- Save current state for recovery
    local original_seq = ut.seq_cur
    local original_changedtick = vim.api.nvim_buf_get_changedtick(0)
    
    local editlist = {}
    local stop = 1
    if n_latest ~= nil then
        stop = math.max(1, #ut.entries - (n_latest - 1))
    end
    
    -- Process undo entries with better error handling
    for i = #ut.entries, stop, -1 do
        local entry = ut.entries[i]
        
        -- Validate entry structure
        if not entry or not entry.seq then
            bhop_log.notify(
                "Invalid undo entry at index " .. i .. " for buffer " .. vim.api.nvim_buf_get_name(0),
                vim.log.levels.DEBUG
            )
            goto continue
        end
        
        -- Try to navigate to this undo state
        local success_after = pcall(function()
            vim.cmd("silent undo " .. entry.seq)
        end)
        
        if not success_after then
            bhop_log.notify(
                "Failed to navigate to undo state " .. entry.seq .. " for buffer " .. vim.api.nvim_buf_get_name(0),
                vim.log.levels.DEBUG
            )
            -- Try to recover to original state before breaking
            pcall(function()
                vim.cmd("silent undo " .. original_seq)
            end)
            break
        end
        
        -- Verify we're actually at the expected state
        local current_seq = vim.fn.undotree().seq_cur
        if current_seq ~= entry.seq then
            bhop_log.notify(
                "Undo state mismatch: expected " .. entry.seq .. ", got " .. current_seq,
                vim.log.levels.DEBUG
            )
            goto continue
        end
        
        local buffer_after_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) or {}
        local buffer_after = table.concat(buffer_after_lines, "\n")

        -- Navigate to parent state
        local success_before = pcall(function()
            vim.cmd("silent undo")
        end)
        
        if not success_before then
            bhop_log.notify(
                "Failed to navigate to parent undo state for " .. entry.seq,
                vim.log.levels.DEBUG
            )
            -- Try to recover to original state before breaking
            pcall(function()
                vim.cmd("silent undo " .. original_seq)
            end)
            break
        end
        
        local buffer_before_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) or {}
        local buffer_before = table.concat(buffer_before_lines, "\n")

        -- Generate diff only if we have valid content
        if buffer_before ~= buffer_after then
            local filename = vim.fn.expand("%")
            local header = filename .. "\n--- " .. filename .. "\n+++ " .. filename .. "\n"
            local diff = vim.diff(buffer_before, buffer_after)
            
            if diff then
                local line_match = diff:match("@@ %-%d+")
                local line = 1
                if line_match ~= nil then
                    line = tonumber(line_match:sub(5)) or 1
                end

                table.insert(editlist, {
                    seq = entry.seq,
                    time = entry.time,
                    diff = header .. diff,
                    file = vim.api.nvim_buf_get_name(0),
                    line = line,
                    prediction_line = -1,
                    model = "",
                })
            end
        end
        
        ::continue::
    end

    -- Restore original state with better error handling
    local restore_success = pcall(function()
        vim.cmd("silent undo " .. original_seq)
    end)
    
    if not restore_success then
        bhop_log.notify(
            "Failed to restore original undo state " .. original_seq .. " for buffer " .. vim.api.nvim_buf_get_name(0),
            vim.log.levels.WARN
        )
        
        -- Try alternative restoration methods
        local recovery_attempts = {
            function() vim.cmd("silent earlier 9999f") end, -- Go to oldest state
            function() vim.cmd("silent later 9999f") end,   -- Go to newest state
            function() vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.api.nvim_buf_get_lines(0, 0, -1, false)) end -- Force buffer refresh
        }
        
        for _, recovery_fn in ipairs(recovery_attempts) do
            if pcall(recovery_fn) then
                bhop_log.notify(
                    "Successfully recovered buffer state using alternative method",
                    vim.log.levels.DEBUG
                )
                break
            end
        end
    end
    
    -- Restore cursor position
    pcall(function()
        vim.api.nvim_win_set_cursor(0, cursor)
    end)

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
    local success, result = pcall(function()
        -- Safely switch to the target buffer
        if not vim.api.nvim_buf_is_valid(last_modified.buf) then
            return nil
        end
        
        vim.api.nvim_set_current_buf(last_modified.buf)
        
        -- Check if buffer has undo history before trying to build editlist
        local ut = vim.fn.undotree()
        if not ut or not ut.entries or #ut.entries == 0 then
            return nil
        end
        
        local editlist = M.build_editlist(1)
        if #editlist > 0 and editlist[1].diff then
            return editlist[1].diff
        end
        return nil
    end)
    
    -- Always try to restore the original buffer, even if there was an error
    pcall(function()
        if vim.api.nvim_buf_is_valid(current_buf) then
            vim.api.nvim_set_current_buf(current_buf)
        end
    end)
    
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
