local bhop_log = require("bunnyhop.log")
local completion_logger = require("bunnyhop.completion_logger")
local M = {}

---Processes the given api_key for the Hugging Face provider.
---If an error occurs, the function returns nil and if it was successful, it returns the api_key.
---@param api_key string
---@param callback fun(api_key: string | nil): nil Function that gets called after the request is made.
---@return nil
function M.process_api_key(api_key, callback)
    if #api_key == 0 then
        bhop_log.notify(
            "'api_key' wasn't given, set the api_key in opts.",
            vim.log.levels.ERROR
        )
        callback(nil)
        return
    end
    if api_key:match("[a-z]+") ~= nil then
        bhop_log.notify(
            "Given api_key is not a name of an enviornment variable.",
            vim.log.levels.ERROR
        )
        callback(nil)
        return
    end

    local env_api_key = os.getenv(api_key)
    if env_api_key then
        callback(env_api_key)
        return
    end
    bhop_log.notify(
        "Enviornment variable '" .. api_key .. "' not found.",
        vim.log.levels.ERROR
    )
    callback(nil)
end

---Gets the available models to use.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(models: string[]): nil Function that gets called after the request is made.
---@return nil
function M.get_models(config, callback) --luacheck: no unused args
    callback { "Qwen/Qwen2.5-Coder-32B-Instruct" }
end

---Completes the given prompt.
---@param prompt string Input prompt.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(completion_result: string): nil Function that gets called after the request is made.
---@return nil
function M.complete(prompt, config, callback)
    local hf_url = "https://api-inference.huggingface.co/models/"
        .. config.model
        .. "/v1/chat/completions"
    local request_body = vim.json.encode {
        model = config.model,
        messages = { { role = "user", content = prompt } },
        max_tokens = 50,
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
    }, {}, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                bhop_log.notify(result.stderr, vim.log.levels.ERROR)
                completion_logger.log_completion(prompt, "", config.model or "unknown", "hugging_face", false)
                callback("")
                return
            end
            local response = vim.json.decode(result.stdout)
            if response.error ~= nil then
                bhop_log.notify(
                    "Hugging Face Error: '" .. response.error .. "'",
                    vim.log.levels.ERROR
                )
                completion_logger.log_completion(prompt, response.error, config.model or "unknown", "hugging_face", false)
                callback("")
                return
            end
            -- Log successful completion
            completion_logger.log_completion(prompt, response.choices[1].message.content, config.model or "unknown", "hugging_face", true)
            callback(response.choices[1].message.content)
        end)
    end)
end

return M
