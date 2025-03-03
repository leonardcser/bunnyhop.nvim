local bhop_log = require("bunnyhop.log")

local M = {}

function M.read(file_name)
    local file = io.open(file_name, "r")
    if file == nil then
        bhop_log.notify("Wasn't able to open " .. file_name, vim.log.levels.INFO)
        return {}
    end
    local parsed_content = {}
    for row in file:lines() do
        table.insert(parsed_content, vim.json.decode(row))
    end
    file:close()
    return parsed_content
end

function M.append(file_name, rows)
    local file = io.open(file_name, "a")
    if file == nil then
        bhop_log.notify("Wasn't able to open " .. file_name, vim.log.levels.INFO)
        return
    end
    for _, row in pairs(rows) do
        file:write(vim.json.encode(row) .. "\n")
    end
    file:close()
end

return M
