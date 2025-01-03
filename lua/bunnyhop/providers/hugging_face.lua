local M = {}

---Gets the available models to use.
---@param callback function Function that gets called after the request is made.
---@return string[]
function M.get_models(config, callback) --luacheck: no unused args
    callback()
    return { "Qwen/Qwen2.5-Coder-32B-Instruct" }
end

---Completes the given prompt.
---@param prompt string Input prompt.
---@param model string LLM model name.
---@param config bhop.config User config. Used to get the api_key for now, mabye more things later.
---@param callback function Function that gets called after the request is made.
---@return nil
function M.complete(prompt, model, config, callback)
    local hf_url =
        "https://api-inference.huggingface.co/models/Qwen/Qwen2.5-Coder-32B-Instruct/v1/chat/completions"
    local request_body = vim.json.encode {
        model = model,
        messages = { { role = "user", content = prompt } },
        max_tokens = 30,
        stream = false,
    }
    vim.system({
        "curl",
        "-H",
        "Authorization: Bearer " .. config.api_key,
        "-H",
        "Content-Type: application/json",
        "-d",
        request_body,
        hf_url,
    }, {}, callback)
end

return M
