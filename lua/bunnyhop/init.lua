-- Init of plugin

local M = {}

---@class bhop.opts
M.defaults = {
    ---@type "copilot"
    provier = "copilot",
    ---@type string
    api_key = "",
}

---@type string
function M._create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line_num
    -- bufnr -> buffer_name
    -- col -> column
    local JUMPLIST_COLUMNS = { "index", "line_num", "column", "buffer_name" }
    local jumplist = vim.fn.getjumplist()[1]
    local csv_jumplist = table.concat(JUMPLIST_COLUMNS, ",") .. "\n"

    for indx, jump_row in pairs(jumplist) do
        csv_jumplist = csv_jumplist
            .. indx
            .. ","
            .. jump_row["lnum"]
            .. ","
            .. jump_row["col"]
            .. ","
            .. vim.api.nvim_buf_get_name(jump_row["bufnr"])
            .. "\n"
    end

    local prompt = "Predict next cursor position based on the following information.\n"
        .. "ONLY output the row and column of the cursor in the format (row, column).\n"
        .. "DO NOT HALLUCINATE!\n"
        .. "# History of Cursor Jumps\n"
        .. csv_jumplist
    print(prompt)

    -- authenticate copilot and
    authorize_token()

    -- TODO: add the change list for each file in the jump list.
    -- local changelist = vim.api.getchangelist()
end

---Setup function
---@param opts? bhop.opts
function M.setup(opts)
    M.config = opts
end
return M
