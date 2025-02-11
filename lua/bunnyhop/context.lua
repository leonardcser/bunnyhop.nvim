local bhop_log = require("bunnyhop.log")
local M = {}

---Creates prompt
---@return string
function M.create_prompt()
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
return M
