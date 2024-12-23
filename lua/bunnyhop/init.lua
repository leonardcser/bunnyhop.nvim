-- Init of plugin

local M = {}

---@class bhop.opts
M.defaults = {
    ---@type "copilot"
    provier = "copilot",
    ---@type string
    api_key = "",
}


---Setup function
---@param opts? bhop.opts
function M.setup(opts)
    M.config = opts
end
return M
