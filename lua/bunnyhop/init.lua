local bhop_log = require("bunnyhop.log")
local bhop_context = require("bunnyhop.context")
local bhop_jsona = require("bunnyhop.jsona")

local _bhop_adapter = {
    process_api_key = function(api_key, callback) end, --luacheck: no unused args
    get_models = function(config, callback) end, --luacheck: no unused args
    complete = function(prompt, config, callback) end, --luacheck: no unused args
}

---@type table<string, bhop.UndoEntry[]>
local _editlists = {}
---@type number
local _DEFAULT_PREVIOUS_WIN_ID = -1
---@type number
local _DEFAULT_ACTION_COUNTER = 0
---@type number
local _preview_win_id = _DEFAULT_PREVIOUS_WIN_ID
---@type number
local _action_counter = _DEFAULT_ACTION_COUNTER
---@type bhop.Prediction
local _prediction = nil
---@type string
local _edit_dir_path = vim.fn.stdpath("data") .. "/bunnyhop/edit_predictions/"

local M = {}
-- The default config, gets overriden with user config options as needed.
---@class bhop.Opts
M.opts = {
    adapter = "copilot",
    model = "gpt-4o-2024-08-06",
    api_key = "",
    ollama_url = "http://localhost:11434",
    max_prev_width = 20,
    collect_data = false,
}

local function close_preview_win()
    if _preview_win_id < 0 then
        return
    end

    vim.api.nvim_win_close(_preview_win_id, false)
    _action_counter = _DEFAULT_ACTION_COUNTER
    _preview_win_id = _DEFAULT_PREVIOUS_WIN_ID
end

---Opens preview window and returns the window's ID.
---@param prediction bhop.Prediction
---@param max_prev_width number
---@return integer
local function open_preview_win(prediction, max_prev_width) --luacheck: no unused args
    local buf_num = vim.fn.bufnr(prediction.file)
    if vim.fn.bufexists(buf_num) == 0 then
        bhop_log.notify(
            "Buffer number: " .. buf_num .. " doesn't exist",
            vim.log.levels.WARN
        )
        return -1
    end
    local prediction_file = prediction.file

    local preview_win_title = vim.fs.basename(prediction_file) .. " : " .. prediction.line
    local pred_line_content = vim.api.nvim_buf_get_lines(buf_num, prediction.line - 1, prediction.line, true)[1]
    local preview_win_width = vim.fn.max {
        1,
        vim.fn.min {
            max_prev_width,
            vim.fn.max {
                #pred_line_content,
                #preview_win_title,
            },
        },
    }
    local half_preview_win_width = math.floor(preview_win_width/2)
    if half_preview_win_width < prediction.column and preview_win_width < #pred_line_content then
        pred_line_content = string.sub(
            pred_line_content,
            (prediction.column - half_preview_win_width),
            -1
        )
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { pred_line_content })
    local byte_col = vim.str_byteindex(pred_line_content, vim.fn.min {prediction.column - 1, half_preview_win_width})
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.api.nvim_buf_add_highlight(buf, 0, "Cursor", 0, byte_col, byte_col + 1)
    local id = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = preview_win_width,
        height = 1,
        style = "minimal",
        border = "single",
        title = preview_win_title,
    })
    return id
end

local function get_editlist_file_path(file_path)
    return _edit_dir_path .. file_path:sub(2):gsub("/", "|") .. ".jsona"
end

---Returns the lastest n elements in a list.
---@param list table
---@param n number
---@return table
local function latest_n(list, n)
    local list_latest_n = {}
    for edit_indx = #list - n, #list do
        table.insert(list_latest_n, list[edit_indx])
    end
    return list_latest_n
end

---Clips number "num" to be within the range of "min" and "max".
---@param num number
---@param min number
---@param max number
---@return number
local function clip_number(num, min, max)
    -- TODO: Figure out why min > max is there and if it can be removed
    if min > max or num < min then
        return min
    elseif num > max then
        return max
    end
    return num
end

---Empty stub for hop function
function M.hop() end

--- Initializes all the autocommands and hop function.
local function init()
    -- Functions initialization
    function M.hop()
        if _prediction.line == -1 or _prediction.column == -1 then
            return
        end

        -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
        vim.cmd("normal! m'")
        local buf_num = vim.fn.bufnr(_prediction.file, true)
        vim.fn.bufload(buf_num)
        vim.api.nvim_set_current_buf(buf_num)
        vim.api.nvim_win_set_cursor(0, { _prediction.line, _prediction.column - 1 })
        close_preview_win()
    end

    --- Autocommands initialization
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
        group = vim.api.nvim_create_augroup("PredictCursor", { clear = true }),
        pattern = "i:n",
        callback = function()
            local current_win_config = vim.api.nvim_win_get_config(0)
            if current_win_config.relative ~= "" then
                return
            end
            local prompt = bhop_context.create_prompt()
            _bhop_adapter.complete(prompt, M.opts, function(completion_result)
                if vim.api.nvim_get_mode().mode ~= "n" then return end

                -- Prasing completion result to prediction
                _prediction = {
                    line = 1,
                    column = 1,
                    file = vim.api.nvim_buf_get_name(0),
                }
                local json_match = completion_result:match('%[%d+, %d+, "[%w/\\.-_]+"%]')
                if json_match ~= nil then
                    local prediction_json = vim.json.decode(json_match)
                    if vim.fn.filereadable(prediction_json[3]) == 1 then
                        _prediction.file = prediction_json[3]
                    end
                    local pred_buf_num = vim.fn.bufadd(_prediction.file)
                    vim.fn.bufload(pred_buf_num)

                    if type(prediction_json[1]) == "number" then
                        _prediction.line =
                            clip_number(prediction_json[1], 1, vim.api.nvim_buf_line_count(pred_buf_num))
                    end

                    if type(prediction_json[2]) == "number" then
                        local pred_line_content = vim.api.nvim_buf_get_lines(pred_buf_num, _prediction.line - 1, _prediction.line, true)[1]
                        local white_space_ammount = #pred_line_content - #pred_line_content:gsub("^%s+", "")
                        _prediction.column = clip_number(prediction_json[2], white_space_ammount + 1, #pred_line_content - 1)
                    end
                end

                -- Opening preview window
                if _preview_win_id ~= _DEFAULT_PREVIOUS_WIN_ID then
                    close_preview_win()
                end
                _preview_win_id = open_preview_win(_prediction, M.opts.max_prev_width)

                -- Collecting data
                if M.opts.collect_data == false then return end
                local latest_edit = bhop_context.build_editlist(1)[1]
                if latest_edit == nil then
                    return
                end
                latest_edit["prediction_line"] = _prediction.line
                latest_edit["prediction_file"] = _prediction.file
                latest_edit["model"] = M.opts.model
                latest_edit["prompt"] = prompt
                bhop_jsona.append(get_editlist_file_path(_prediction.file), {latest_edit})
                -- TODO: This if statement is a patch, find the root cause and fix it.
                if _editlists[_prediction.file] == nil then
                    return
                end
                table.insert(_editlists[_prediction.file], latest_edit)
            end)
        end,
    })
    local prev_win_augroup =
        vim.api.nvim_create_augroup("UpdateHopWindow", { clear = true })
    -- TODO: Find an autocommand event or pattern that only activates when cursor is moved inside the current buffer/in normal mode.
    -- Not when switching between different files.
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = prev_win_augroup,
        pattern = "*",
        callback = function()
            if _preview_win_id < 0 then
                return
            end
            if _action_counter < 1 then
                vim.api.nvim_win_set_config(
                    _preview_win_id,
                    { relative = "cursor", row = 1, col = 0 }
                )
                _action_counter = _action_counter + 1
            else
                close_preview_win()
            end
        end,
    })
    vim.api.nvim_create_autocmd({"BufLeave", "InsertEnter"}, {
        group = prev_win_augroup,
        pattern = "*",
        callback = close_preview_win
    })

    if M.opts.collect_data == false then return end
    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("GetEditlist", {clear = true}),
        pattern = "*",
        callback = function()
            local buffer_name = vim.api.nvim_buf_get_name(0)
            local valid_file_name = buffer_name:match("^.+/([%w_-]+)%.([%w]+)$")
            if valid_file_name == nil then
                return
            end

            vim.fn.mkdir(_edit_dir_path, "p")
            local edit_file_path = get_editlist_file_path(buffer_name)
            local file_exists = vim.fn.filereadable(edit_file_path) == 1
            if file_exists then
                local content = bhop_jsona.read(edit_file_path)
                _editlists[buffer_name] = latest_n(content, 40)
                return
            end
            local editlist = bhop_context.build_editlist()
            bhop_jsona.append(edit_file_path, editlist)
            _editlists[buffer_name] = latest_n(editlist, 40)
        end
    })
end

---Setup function
---@param opts? bhop.Opts
function M.setup(opts)
    ---@diagnostic disable-next-line: param-type-mismatch
    for opt_key, opt_val in pairs(opts) do
        M.opts[opt_key] = opt_val
    end

    _bhop_adapter = require("bunnyhop.adapters." .. M.opts.adapter)
    _bhop_adapter.process_api_key(
        M.opts.api_key,
        function(api_key)
            M.opts.api_key = api_key
        end
    )
    local config_ok = M.opts.api_key ~= nil
    if config_ok then
        init()
    else
        bhop_log.notify(
            "Error: bunnyhop config was incorrect, not initializing",
            vim.log.levels.ERROR
        )
    end
end

return M
