local bhop_log = require("bhop.log")

local M = {}
function M.read(file_name)
    local file = io.open(file_name, "r")
    if file == nil then
        bhop_log.notify("Wasn't able to open " .. file_name, vim.log.levels.INFO)
        return
    end
    local lines_iter = file:lines()
    local headers = vim.json.decode("[" .. lines_iter() .. "]")
    local parsed_content = {}
    for line in lines_iter do
        local parsed_line = {}
        for indx, value in pairs(vim.json.decode("[" .. line .. "]")) do
            parsed_line[headers[indx]] = value
        end
        table.insert(parsed_content, parsed_line)
    end
    file:close()
    return parsed_content
end

function M.append(rows)
    local file_name = "/home/plazma/src/lab/lua/test.csv"
    local file = io.open(file_name, "a+")
    if file == nil then
        bhop_log.notify("Wasn't able to open " .. file_name, vim.log.levels.INFO)
        return
    end
    local headers = vim.json.decode("[" .. file:lines()() .. "]")
    local encoded_rows = ""
    for _, row in pairs(rows) do
        local encoded_row = ""
        for _, header in pairs(headers) do
            if type(row[header]) == "string" then
                encoded_row = encoded_row .. "," .. '"' .. row[header] .. '"'
            else
                encoded_row = encoded_row .. "," .. row[header]
            end
        end
        encoded_rows = encoded_rows .. string.sub(encoded_row, 2) .. "\n"
    end
    file:write(encoded_rows)
    file:close()
end

return M
