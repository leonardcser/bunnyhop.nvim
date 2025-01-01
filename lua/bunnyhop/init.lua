local M = {}

--- Default config, gets overriden with user config options as needed.
---@class bhop.opts
M.config = {
    ---@type string
    api_key = "",
    ---@type number
    max_prev_width = 20,
}
local globals = {
    DEFAULT_PREVIOUS_WIN_ID = -1,
    DEFAULT_ACTION_COUNTER = 0,
    DEFAULT_CURSOR_PRED_LINE = 1,
    DEFAULT_CURSOR_PRED_COLUMN = 1,
    DEFAULT_CURSOR_PRED_FILE = "",
}
globals.hop_args = {
    cursor_pred_line = globals.DEFAULT_CURSOR_PRED_LINE,
    cursor_pred_column = globals.DEFAULT_CURSOR_PRED_COLUMN,
    cursor_pred_file = globals.DEFAULT_CURSOR_PRED_FILE,
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

    -- TODO: Figure out how neovim stores all the buffer numbers so that it can jump to between them and not get a "bufnr was not found" error
    for indx, jump_row in pairs(jumplist) do
        local buf_name = ""
        if vim.fn.bufexists(jump_row["bufnr"]) == 1 then
            buf_name = vim.api.nvim_buf_get_name(jump_row["bufnr"])
        end
        if buf_name:match(".git") == nil then
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

        if jumplist_files[jump_row["bufnr"]] == nil and #buf_name ~= 0 then
            jumplist_files[jump_row["bufnr"]] = buf_name
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
                .. changelist_csv
                .. "\n"
        end
    end

    local prompt = "Predict next cursor position based on the following information.\n"
        .. 'ONLY output the row and column of the cursor in the format [line_num, column, "buffer_name"].\n'
        .. "DO NOT HALLUCINATE!\n" -- for the memes
        .. "# History of Cursor Jumps\n"
        .. jumplist_csv
        .. changelists

    return prompt
end

local function buf_get_line(buf_num, line_num)
    return vim.api.nvim_buf_get_lines(buf_num, line_num - 1, line_num, true)[1]
end

local function open_preview_win(cursor_pred_line, cursor_pred_column, cursor_pred_file)
    local buf_num = vim.fn.bufnr(cursor_pred_file)
    if vim.fn.bufexists(buf_num) == 0 then
        vim.notify("Buffer number: " .. buf_num .. " doesn't exist", vim.log.levels.WARN)
        return
    end
    local pred_line_content = buf_get_line(buf_num, cursor_pred_line)
    pred_line_content = pred_line_content:gsub("^%s+", "")

    -- Opens preview window.
    -- Closing the existing preview window if it exist to make space for the newly created window.
    close_preview_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local prev_win_title = vim.fs.basename(cursor_pred_file) .. " : " .. cursor_pred_line
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
    if num < min then
        return min
    elseif num > max then
        return max
    end
    return num
end

local function predict()
    local hf_url =
        "https://api-inference.huggingface.co/models/Qwen/Qwen2.5-Coder-32B-Instruct/v1/chat/completions"
    local prompt = create_prompt()
    local request_body = vim.json.encode {
        model = "Qwen/Qwen2.5-Coder-32B-Instruct",
        messages = { { role = "user", content = prompt } },
        max_tokens = 30,
        stream = false,
    }
    vim.system({
        "curl",
        "-H",
        "Authorization: Bearer " .. M.config.api_key,
        "-H",
        "Content-Type: application/json",
        "-d",
        request_body,
        hf_url,
    }, {}, function(command_result)
        local cursor_pred_file = globals.DEFAULT_CURSOR_PRED_FILE
        local cursor_pred_line = globals.DEFAULT_CURSOR_PRED_LINE
        local cursor_pred_column = globals.DEFAULT_CURSOR_PRED_COLUMN
        if command_result.code ~= 0 then
            vim.notify(command_result.stderr, vim.log.levels.ERROR)
            return
        end

        local response = vim.json.decode(command_result.stdout)
        local success, pred = pcall(vim.json.decode, response.choices[1].message.content)
        -- "Hack" to get around being unable to call vim functions in a callback.
        vim.schedule(function()
            if success == true then
                cursor_pred_file = pred[3]
                if vim.fn.filereadable(cursor_pred_file) == 0 then
                    cursor_pred_file = globals.DEFAULT_CURSOR_PRED_FILE
                end
                local pred_buf_num = vim.fn.bufnr(cursor_pred_file, true)
                cursor_pred_line = pred[1]
                if type(cursor_pred_line) ~= "number" then
                    cursor_pred_line = globals.DEFAULT_CURSOR_PRED_LINE
                else
                    cursor_pred_line = clip_number(
                        cursor_pred_line,
                        1,
                        vim.api.nvim_buf_line_count(pred_buf_num)
                    )
                end
                cursor_pred_column = pred[2]
                if type(cursor_pred_column) ~= "number" then
                    cursor_pred_column = globals.DEFAULT_CURSOR_PRED_COLUMN
                else
                    local pred_line_content =
                        buf_get_line(pred_buf_num, cursor_pred_line):gsub("^%s+", "")
                    cursor_pred_column =
                        clip_number(cursor_pred_column, 1, #pred_line_content)
                end
            end

            globals.hop_args.cursor_pred_line = cursor_pred_line
            globals.hop_args.cursor_pred_column = cursor_pred_column
            globals.hop_args.cursor_pred_file = cursor_pred_file

            -- Makes sure to only display the preview mode when in normal mode
            if vim.api.nvim_get_mode().mode == "n" then
                open_preview_win(cursor_pred_line, cursor_pred_column, cursor_pred_file)
            end
        end)
    end)
end

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

local prev_win_augroup = vim.api.nvim_create_augroup("UpdateHopWindow", { clear = true })
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

---Hops to the predicted cursor position.
function M.hop()
    if
        globals.hop_args.cursor_pred_line == -1
        or globals.hop_args.cursor_pred_column == -1
    then
        return
    end

    -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
    vim.cmd("normal! m'")
    local buf_num = vim.fn.bufnr(globals.hop_args.cursor_pred_file, true)
    vim.fn.bufload(buf_num)
    vim.api.nvim_set_current_buf(buf_num)
    vim.api.nvim_win_set_cursor(
        0,
        { globals.hop_args.cursor_pred_line, globals.hop_args.cursor_pred_column - 1 }
    )
    close_preview_win()
end

---Setup function
---@param opts? bhop.opts
function M.setup(opts)
    ---@diagnostic disable-next-line: param-type-mismatch
    for opt_key, opt_val in pairs(opts) do
        M.config[opt_key] = opt_val
    end

    if #M.config.api_key == 0 then
        vim.notify(
            "API key wasn't given, please set the api_key in the opts table to an enviornment variable name.",
            vim.log.levels.ERROR
        )
    elseif M.config.api_key:match("[a-z]+") ~= nil then
        vim.notify(
            "Given API key is not a name of an enviornment variable.",
            vim.log.levels.ERROR
        )
    else
        local api_key = os.getenv(M.config.api_key)
        if api_key then
            M.config.api_key = api_key
        else
            vim.notify(
                "Wasn't able to get API key from the enviornment.",
                vim.log.levels.ERROR
            )
        end
    end
end

return M
