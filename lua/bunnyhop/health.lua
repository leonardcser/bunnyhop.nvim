local bhop = require("bunnyhop.init")
local M = {}
M.check = function()
    vim.health.start("Bunnyhop Health Check")

    local setup_checks = {
        api_key = {
            {
                ok = bhop.config.api_key ~= "",
                err_msg = "Given API key is incorrect, you should see a popup explaining the reason when starting Neovim",
            },
            {
                ok = bhop.config.api_key:match("^hf_*"),
                err_msg = "Given API key '" .. bhop.config.api_key .. "' is not a hugging face api key",
            },
        },
    }
    local ok = true
    local err_msg = "Setup is incorrect: \n"
    local current_ok = true
    local current_err_msg = ""
    for check_category_name, check_category in pairs(setup_checks) do
        current_ok = true
        current_err_msg = check_category_name .. " Error: \n"
        for _, check in pairs(check_category) do
            if check.ok == false then
                current_ok = false
                current_err_msg = current_err_msg .. check.err_msg .. "\n"
                -- Early stop to not call checks that depend on previous ones in the category.
                break
            end
        end
        if current_ok == false then
            ok = current_ok
            err_msg = current_err_msg
        end
    end

    if ok then
        vim.health.ok("Setup is correct")
    else
        vim.health.error(err_msg)
    end
end
return M
