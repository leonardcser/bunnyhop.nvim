local M = {}

--- Default config, gets overriden with user config options as needed.
---@class bhop.opts
M.config = {
    ---@type string
    api_key = "",
    ---@type number
    max_prev_width = 20,
}
-- TODO: Check if making these variables local works.
-- If so do it, its probably better to not expose these to the user.
local globals = {
    cursor_pred = { line = 0, column = 0, file = "" },
    prev_win_id = -1,
    action_counter = 0
}

local function create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line_num
    -- bufnr -> buffer_name
    -- col -> column
    local JUMPLIST_COLUMNS = { "index", "line_num", "column", "buffer_name" }
    local jumplist = vim.fn.getjumplist()[1]
    local csv_jumplist = table.concat(JUMPLIST_COLUMNS, ",") .. "\n"

    -- TODO: Figure out how neovim stores all the buffer numbers so that it can jump to between them and not get a "bufnr was not found" error
    for indx, jump_row in pairs(jumplist) do
        -- TODO: handle buffer number doesn't exist and causes an error when trying to get its file name.
        local buf_name = ""
        if vim.fn.bufexists(jump_row["bufnr"]) then
            buf_name = vim.api.nvim_buf_get_name(jump_row["bufnr"])
        end
        if buf_name:match(".git") == nil then
            csv_jumplist = csv_jumplist
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

    local prompt = "Predict next cursor position based on the following information.\n"
        .. 'ONLY output the row and column of the cursor in the format [line_num, column, "buffer_name"].\n'
        .. "DO NOT HALLUCINATE!\n"
        .. "# History of Cursor Jumps\n"
        .. csv_jumplist

    -- TODO: add the change list for each file in the jump list.
    -- local changelist = vim.api.getchangelist()
    return prompt
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
        if command_result.code ~= 0 then
            vim.notify(command_result.stderr, vim.log.levels.ERROR)
            return
        end

        local response = vim.json.decode(command_result.stdout)
        local err, pred = pcall(vim.json.decode, response.choices[1].message.content)
        if err then
            globals.cursor_pred.file = ""
            globals.cursor_pred.line = 0
            globals.cursor_pred.column = 0
        end

        globals.cursor_pred.file = pred[3]
        if vim.fn.filereadable(globals.cursor_pred.file) == 0 then
            globals.cursor_pred.file = ""
        end
        globals.cursor_pred.line = pred[1]
        if type(globals.cursor_pred.line) ~= "number" then
            globals.cursor_pred = 0
        end
        globals.cursor_pred.column = pred[2]
        if type(globals.cursor_pred.column) ~= "number" then
            globals.cursor_pred.column = 0
        end

        -- "Hack" to get around being unable to call vim functions in a callback.
        vim.schedule(function()
            -- Clipping model prediction because it predicts out of range values often.
            local function clip_number(num, min, max)
                if num < min then
                    return min
                elseif num > max then
                    return max
                end
                return num
            end

            -- TODO: Ensure buff_num exists before using it.
            local buf_num = vim.fn.bufnr(globals.cursor_pred.file)
            globals.cursor_pred.line =
                clip_number(globals.cursor_pred.line, 1, vim.api.nvim_buf_line_count(buf_num))
            local pred_line_content = vim.api.nvim_buf_get_lines(
                buf_num,
                globals.cursor_pred.line - 1,
                globals.cursor_pred.line,
                true
            )[1]
            pred_line_content = pred_line_content:gsub("^%s+", "")
            globals.cursor_pred.column =
                clip_number(globals.cursor_pred.column, 1, #pred_line_content)

            -- TODO: Create a reusable close window function.
            -- In this function, make sure there is a if statement that handle a nonexistant buffer/window ID.
            -- Closes previous window.
            if globals.prev_win_id > 0 then
                vim.api.nvim_win_close(M.prev_win_id, false)
                globals.action_counter = 0
                globals.prev_win_id = -1
            end

            -- Opens preview window.
            local buf = vim.api.nvim_create_buf(false, true)
            local prev_win_title = vim.fs.basename(globals.cursor_pred.file)
                .. " : "
                .. globals.cursor_pred.line
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { pred_line_content })
            globals.prev_win_id = vim.api.nvim_open_win(buf, false, {
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
        end)
    end)
end
vim.api.nvim_create_autocmd({ "ModeChanged" }, {
    group = vim.api.nvim_create_augroup("PredictCursor", { clear = true }),
    pattern = "i:n",
    callback = predict,
})

local prev_win_augroup = vim.api.nvim_create_augroup("CloseHopWindow", { clear = true })
vim.api.nvim_create_autocmd("CursorMoved", {
    group = prev_win_augroup,
    pattern = "*",
    callback = function()
        if globals.prev_win_id < 1 then
            return
        end

        if globals.action_counter < 1 then
            vim.api.nvim_win_set_config(
                globals.prev_win_id,
                { relative = "cursor", row = 1, col = 0 }
            )
            globals.action_counter = globals.action_counter + 1
        else
            vim.api.nvim_win_close(globals.prev_win_id, false)
            globals.action_counter = 0
            globals.prev_win_id = -1
        end
    end,
})
vim.api.nvim_create_autocmd("InsertEnter", {
    group = prev_win_augroup,
    pattern = "*",
    callback = function()
        if globals.prev_win_id < 1 then
            return
        end

        vim.api.nvim_win_close(globals.prev_win_id, false)
        globals.action_counter = 0
        globals.prev_win_id = -1
    end,
})

---Hops to the predicted cursor position.
function M.hop()
    if globals.cursor_pred.line == -1 or globals.cursor_pred.column == -1 then
        return
    end

    -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
    vim.cmd("normal! m'")
    local buf_num = vim.fn.bufnr(globals.cursor_pred.file, true)
    vim.fn.bufload(buf_num)
    vim.api.nvim_set_current_buf(buf_num)
    vim.api.nvim_win_set_cursor(0, { globals.cursor_pred.line, globals.cursor_pred.column - 1 })
    if globals.prev_win_id < 1 then
        return
    end

    vim.api.nvim_win_close(globals.prev_win_id, false)
    globals.action_counter = 0
    globals.prev_win_id = -1
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
