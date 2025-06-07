local M = {}

---Logs completion data to log.txt file in the repository root
---@param prompt string The input prompt
---@param completion string The completion result
---@param model string The model used
---@param provider string The provider/adapter used
---@param success boolean Whether the completion was successful
function M.log_completion(prompt, completion, model, provider, success)
    -- Hard coded log file path
    local log_file = "/Users/leo/dev/lua/bunnyhop.nvim/log.txt"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Format the log entry
    local log_entry = string.format(
        "[%s] Provider: %s | Model: %s | Success: %s\nPrompt: %s\nResult: %s\n%s\n",
        timestamp,
        provider,
        model,
        tostring(success),
        prompt,
        completion,
        string.rep("-", 80)
    )
    
    -- Append to log file
    local file = io.open(log_file, "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end

return M 