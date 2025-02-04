local bhop_log = require("bunnyhop.log")
local context = require("bunnyhop.context")

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

local Prediction = {}
Prediction.__index = Prediction

---Initializes the prediction class.
---@param config bhop.Opts
---@return bhop.Prediction
function Prediction:new(config)
    return setmetatable({
        config = config,
        adapter = require("bunnyhop.adapters." .. config.adapter),
        DEFAULT_PRED_LINE = 1,
        DEFAULT_PRED_COLUMN = 1,
        DEFAULT_PRED_FILE = "%",
        line = self.DEFAULT_PRED_LINE,
        column = self.DEFAULT_PRED_COLUMN,
        file = self.DEFAULT_PRED_FILE,
    }, self)
end

---Predicts the next cursor position.
---@param config bhop.Opts
---@param callback fun()
function Prediction:run(config, callback)
    self.adapter.complete(context.create_prompt(), config, function(completion_result)
        local success, pred_str = pcall(vim.json.decode, completion_result)
        self.file = self.DEFAULT_PRED_FILE
        self.line = self.DEFAULT_PRED_LINE
        self.column = self.DEFAULT_PRED_COLUMN
        if success == true then
            if vim.fn.filereadable(pred_str[3]) ~= 0 then
                self.file = pred_str[3]
            end
            local pred_buf_num = vim.fn.bufadd(self.file)
            vim.fn.bufload(pred_buf_num)

            if type(pred_str[1]) == "number" then
                self.line =
                    clip_number(self.line, 1, vim.api.nvim_buf_line_count(pred_buf_num))
            end

            if type(pred_str[2]) == "number" then
                local pred_line_content = vim.api.nvim_buf_get_lines(self.file, self.line - 1, self.line, true)[1]
                local white_space_ammount = #pred_line_content - #pred_line_content:gsub("^%s+", "")
                self.column = clip_number(pred_str[2], white_space_ammount + 1, #pred_line_content - 1)
            end
        end
        callback()
    end)
end

---Moves cursor to the predicted file, line and column.
function Prediction:hop()
    if self.line == -1 or self.column == -1 then
        return
    end

    -- Adds current position to the jumplist so you can <C-o> back to it if you don't like where you hopped.
    vim.cmd("normal! m'")
    local buf_num = vim.fn.bufnr(self.file, true)
    vim.fn.bufload(buf_num)
    vim.api.nvim_set_current_buf(buf_num)
    vim.api.nvim_win_set_cursor(0, { self.line, self.column - 1 })
end

return Prediction
