local bhop_log = require("bunnyhop.log")
local M = {}

-- The default config, gets overriden with user config options as needed.
---@class bhop.Opts
M.config = {
    provider = "hugging_face",
    model = "Qwen/Qwen2.5-Coder-32B-Instruct",
    api_key = "",
    max_prev_width = 20,
}
local globals = {
    DEFAULT_PREVIOUS_WIN_ID = -1,
    DEFAULT_ACTION_COUNTER = 0,
    DEFAULT_PRED_LINE = 1,
    DEFAULT_PRED_COLUMN = 1,
    DEFAULT_PRED_FILE = "%",
}
globals.pred = {
    line = globals.DEFAULT_PRED_LINE,
    column = globals.DEFAULT_PRED_COLUMN,
    file = globals.DEFAULT_PRED_FILE,
}
globals.preview_win_id = globals.DEFAULT_PREVIOUS_WIN_ID
globals.action_counter = globals.DEFAULT_ACTION_COUNTER

local function close_preview_win()
    if globals.preview_win_id < 0 then
        return
    end

    vim.api.nvim_win_close(globals.preview_win_id, false)
    globals.action_counter = globals.DEFAULT_ACTION_COUNTER
    globals.preview_win_id = globals.DEFAULT_PREVIOUS_WIN_ID
end

local function create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line_num
    -- bufnr -> buffer_name
    -- col -> column
    local JUMPLIST_COLUMNS = { "index", "line_num", "column", "buffer_name" }
    local jumplist = vim.fn.getjumplist()[1]
    local jumplist_csv = table.concat(JUMPLIST_COLUMNS, ",") .. "\n"
    local jumplist_files = {}

    for indx, jump_row in pairs(jumplist) do
        local buf_num = jump_row["bufnr"]
        if vim.fn.bufexists(buf_num) == 1 then
            local buf_name = vim.api.nvim_buf_get_name(buf_num)
            if
                buf_name:match(".git") == nil
                and buf_name:match(vim.fn.getcwd()) ~= nil
            then
                if jumplist_files[buf_num] == nil then
                    jumplist_files[buf_num] = buf_name
                end
                jumplist_csv = jumplist_csv
                    .. indx
                    .. ","
                    .. jump_row["lnum"]
                    .. ","
                    .. jump_row["col"]
                    .. ","
                    .. buf_name
                    .. "\n"
            end
        end
    end

    local CHANGELIST_COLUMNS = { "index", "line_num", "column" }
    local CHANGELIST_MAX_SIZE = 20
    local changelists = ""
    for buf_num, buf_name in pairs(jumplist_files) do
        local changelist_csv = ""
        local changelist = vim.fn.getchangelist(buf_num)[1]
        local changelist_start = vim.fn.max { 1, #changelist - CHANGELIST_MAX_SIZE }
        changelist = vim.fn.slice(changelist, changelist_start, #changelist)
        if #changelist ~= 0 then
            for indx, change_row in pairs(changelist) do
                changelist_csv = changelist_csv
                    .. indx
                    .. ","
                    .. change_row["lnum"]
                    .. ","
                    .. change_row["col"]
                    .. "\n"
            end
            changelists = changelists
                .. "# Change history of buffer "
                .. buf_name
                .. "\n"
                .. table.concat(CHANGELIST_COLUMNS, ",")
                .. "\n"
                .. changelist_csv
                .. "\n"
        end
    end

    local prompt = "Predict next cursor position based on the following information.\n"
        .. "ONLY output the following format:\n"
        .. '[line_num, column, "buffer_name"].\n'
        .. "'line_num' is the line number the cursor should be on next\n"
        .. "'column' is the column the cursor should be on next\n"
        .. "'buffer_name' should be the name of the file the cursor should be on next\n"
        .. "DO NOT HALLUCINATE!\n" -- for the memes
        .. "# History of Cursor Jumps\n"
        .. jumplist_csv
        .. changelists

    return prompt
end

local function buf_get_line(buf_num, line_num)
    return vim.api.nvim_buf_get_lines(buf_num, line_num - 1, line_num, true)[1]
end

local function open_preview_win(pred) --luacheck: no unused args
    local buf_num = vim.fn.bufnr(pred.file)
    if vim.fn.bufexists(buf_num) == 0 then
        bhop_log.notify("Buffer number: " .. buf_num .. " doesn't exist", vim.log.levels.WARN)
        return
    end

    if pred.file == "%" then
        pred.file = vim.api.nvim_buf_get_name(0)
    end

    local pred_line_content = buf_get_line(buf_num, pred.line)
    pred_line_content = pred_line_content:gsub("^%s+", "")

    -- Opens preview window.
    -- Closing the existing preview window if it exist to make space for the newly created window.
    close_preview_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local prev_win_title = vim.fs.basename(pred.file) .. " : " .. pred.line
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { pred_line_content })
    globals.preview_win_id = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = vim.fn.max {
            1,
            vim.fn.min {
                M.config.max_prev_width,
                vim.fn.max {
                    #pred_line_content,
                    #prev_win_title,
                },
            },
        },
        height = 1,
        style = "minimal",
        border = "single",
        title = prev_win_title,
    })
end

local function clip_number(num, min, max)
    if min > max or num < min then
        return min
    elseif num > max then
        return max
    end
    return num
end

local function extract_pred(llm_output)
    -- "Hack" to get around being unable to call vim functions in a callback.
    local success, pred_str = pcall(vim.json.decode, llm_output)
    local pred = {
        file = globals.DEFAULT_PRED_FILE,
        line = globals.DEFAULT_PRED_LINE,
        column = globals.DEFAULT_PRED_COLUMN,
    }
    if success == true then
        pred.file = pred_str[3]
        if #pred.file == 0 or vim.fn.filereadable(pred.file) == 0 then
            pred.file = globals.DEFAULT_PRED_FILE
        end
        local pred_buf_num = vim.fn.bufadd(pred.file)
        vim.fn.bufload(pred_buf_num)

        pred.line = pred_str[1]
        if type(pred.line) ~= "number" then
            pred.line = globals.DEFAULT_PRED_LINE
        else
            pred.line =
                clip_number(pred.line, 1, vim.api.nvim_buf_line_count(pred_buf_num))
        end

        pred.column = pred_str[2]
        if type(pred.column) ~= "number" then
            pred.column = globals.DEFAULT_PRED_COLUMN
        else
            local pred_line_content =
                buf_get_line(pred_buf_num, pred.line):gsub("^%s+", "")
            pred.column = clip_number(pred.column, 1, #pred_line_content)
        end
    end

    return pred
end

local function predict()
    local provider = require("bunnyhop.adapters." .. M.config.provider)
    provider.complete(
        create_prompt(),
        M.config,
        function(completion_result)
            -- "Hack" to get around being unable to call vim functions in a callback.
            vim.schedule(function()
                local pred = extract_pred(completion_result)
                globals.pred.line = pred.line
                globals.pred.column = pred.column
                globals.pred.file = pred.file

                -- Makes sure to only display the preview mode when in normal mode
                if vim.api.nvim_get_mode().mode == "n" then
                    open_preview_win(pred)
                end
            end)
        end
    )
end

function M.hop() end

local function init()
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
        group = vim.api.nvim_create_augroup("PredictCursor", { clear = true }),
        pattern = "i:n",
        callback = function()
            local current_win_config = vim.api.nvim_win_get_config(0)
            if current_win_config.relative == "" then
                predict()
            end
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
            if globals.preview_win_id < 0 then
                return
            end
            if globals.action_counter < 1 then
                vim.api.nvim_win_set_config(
                    globals.preview_win_id,
                    { relative = "cursor", row = 1, col = 0 }
                )
                globals.action_counter = globals.action_counter + 1
            else
                close_preview_win()
            end
        end,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
        group = prev_win_augroup,
        pattern = "*",
        callback = function()
            close_preview_win()
        end,
    })
    vim.api.nvim_create_autocmd("InsertEnter", {
        group = prev_win_augroup,
        pattern = "*",
        callback = close_preview_win,
    })
    function M.hop()
        if globals.pred.line == -1 or globals.pred.column == -1 then
            return
        end

        -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
        vim.cmd("normal! m'")
        local buf_num = vim.fn.bufnr(globals.pred.file, true)
        vim.fn.bufload(buf_num)
        vim.api.nvim_set_current_buf(buf_num)
        vim.api.nvim_win_set_cursor(0, { globals.pred.line, globals.pred.column - 1 })
        close_preview_win()
    end
end

---Setup function
---@param opts? bhop.Opts
function M.setup(opts)
    ---@diagnostic disable-next-line: param-type-mismatch
    for opt_key, opt_val in pairs(opts) do
        M.config[opt_key] = opt_val
    end

    local config_ok = false
    if #M.config.api_key == 0 then
        bhop_log.notify(
            "'api_key' wasn't given, set the api_key in opts.",
            vim.log.levels.ERROR
        )
    elseif M.config.api_key:match("[a-z]+") ~= nil then
        bhop_log.notify(
            "Given api_key is not a name of an enviornment variable.",
            vim.log.levels.ERROR
        )
    else
        local api_key = os.getenv(M.config.api_key)
        if api_key then
            config_ok = true
            M.config.api_key = api_key
        else
            bhop_log.notify(
                "Enviornment variable '" .. M.config.api_key .. "' not found.",
                vim.log.levels.ERROR
            )
        end
    end
    if config_ok then
        init()
    end
end

return M
