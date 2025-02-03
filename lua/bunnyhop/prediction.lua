local bhop_log = require("bunnyhop.log")

local _DEFAULT_PRED_LINE = 1
local _DEFAULT_PRED_COLUMN = 1
local _DEFAULT_PRED_FILE = "%"

---@class bhop.Prediction
local _pred = {
    line = _DEFAULT_PRED_LINE,
    column = _DEFAULT_PRED_COLUMN,
    file = _DEFAULT_PRED_FILE,
}


---Gets the line of a given buffer
---@param buf_num number
---@param line_num number
---@return string
local function buf_get_line(buf_num, line_num)
    return vim.api.nvim_buf_get_lines(buf_num, line_num - 1, line_num, true)[1]
end

---Clips given number to given range
---@param num number
---@param min number
---@param max number
---@return number
local function clip_number(num, min, max)
    if min > max or num < min then
        return min
    elseif num > max then
        return max
    end
    return num
end

---Preprocess prediction result returned by the llm.
---@param llm_output string
---@return bhop.Prediction
local function extract_pred(llm_output)
    local success, pred_str = pcall(vim.json.decode, llm_output)
    local pred = {
        file = _DEFAULT_PRED_FILE,
        line = _DEFAULT_PRED_LINE,
        column = _DEFAULT_PRED_COLUMN,
    }
    if success == true then
        if vim.fn.filereadable(pred_str[3]) ~= 0 then
            pred.file = pred_str[3]
        end
        local pred_buf_num = vim.fn.bufadd(pred.file)
        vim.fn.bufload(pred_buf_num)

        if type(pred_str[1]) == "number" then
            pred.line =
                clip_number(pred.line, 1, vim.api.nvim_buf_line_count(pred_buf_num))
        end

        if type(pred_str[2]) == "number" then
            local pred_line_content = buf_get_line(pred_buf_num, pred.line)
            local white_space_ammount = #pred_line_content - #pred_line_content:gsub("^%s+", "")
            pred.column = clip_number(pred_str[2], white_space_ammount + 1, #pred_line_content - 1)
        end
    end

    return pred
end

---Creates prompt
---@return string
local function create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line_num
    -- bufnr -> buffer_name
    -- col -> column
    local jumplist = vim.fn.getjumplist()[1]
    local visited_files = {}

    for _, jump_row in pairs(jumplist) do
        local buf_num = jump_row["bufnr"]
        if vim.fn.bufexists(buf_num) == 0 or vim.api.nvim_buf_is_valid(buf_num) == false then
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

    local CHANGELIST_COLUMNS = { "index", "line_num", "column" }
    local CHANGELIST_MAX_SIZE = 20
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
            .. "## Buffer content"
            .. "\n"
            .. file_content
            .. "\n"
            .. "## Change history of buffer "
            .. "\n"
            .. table.concat(CHANGELIST_COLUMNS, ",")
            .. "\n"
            .. changelist_csv
            .. "\n"
        ::continue::
    end

    local prompt = "Predict next cursor position based on the following information.\n"
        .. "ONLY output the following format:\n"
        .. '[line_num, column, "buffer_name"].\n'
        .. "'line_num' is the line number the cursor should be on next\n"
        .. "'column' is the column the cursor should be on next\n"
        .. "'buffer_name' should be the name of the file the cursor should be on next\n"
        .. "DO NOT HALLUCINATE!\n" -- for the memes
        .. "# History of Cursor Jumps\n"
        .. context

    return prompt
end

local M = {}

---Predicts the next cursor position.
---@param config bhop.Opts
---@param callback fun(completion_result: bhop.Prediction)
function M.predict(config, callback)
    local adapter = require("bunnyhop.adapters." .. config.adapter)
    adapter.complete(create_prompt(), config, function(completion_result)
        -- "Hack" to get around being unable to call vim functions in a callback.
        callback(extract_pred(completion_result))
    end)
end


function M.hop()
    if _pred.line == -1 or _pred.column == -1 then
        return
    end

    -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
    vim.cmd("normal! m'")
    local buf_num = vim.fn.bufnr(_pred.file, true)
    vim.fn.bufload(buf_num)
    vim.api.nvim_set_current_buf(buf_num)
    vim.api.nvim_win_set_cursor(0, { _pred.line, _pred.column - 1 })
end

return M
