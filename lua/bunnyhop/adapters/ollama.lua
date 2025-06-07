local bhop_log = require("bunnyhop.log")
local completion_logger = require("bunnyhop.completion_logger")
local M = {}

---Processes the given api_key for the Ollama provider.
---Since Ollama runs locally, no API key is needed.
---@param api_key string
---@param callback fun(api_key: string | nil): nil Function that gets called after the request is made.
---@return nil
function M.process_api_key(api_key, callback) --luacheck: no unused args
    -- Ollama runs locally, no API key needed
    callback("")
end

---Gets the available models to use by querying the local Ollama instance.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(models: string[]): nil Function that gets called after the request is made.
---@return nil
function M.get_models(config, callback) --luacheck: no unused args
    local ollama_url = (config.ollama_url or "http://localhost:11434") .. "/api/tags"
    
    vim.system({
        "curl",
        "-H",
        "Content-Type: application/json",
        ollama_url,
    }, {}, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                bhop_log.notify(
                    "Ollama Adapter: Failed to connect to Ollama. Make sure Ollama is running. " .. result.stderr,
                    vim.log.levels.ERROR
                )
                -- Return some common default models if we can't connect
                callback({ "llama3.2", "codellama", "qwen2.5-coder" })
                return
            end
            
            local response = vim.json.decode(result.stdout)
            if not response or not response.models then
                bhop_log.notify(
                    "Ollama Adapter: Invalid response from Ollama API",
                    vim.log.levels.ERROR
                )
                callback({ "llama3.2", "codellama", "qwen2.5-coder" })
                return
            end
            
            local models = {}
            for _, model in ipairs(response.models) do
                table.insert(models, model.name)
            end
            
            if #models == 0 then
                bhop_log.notify(
                    "Ollama Adapter: No models found. Please install models using 'ollama pull <model>'",
                    vim.log.levels.WARN
                )
                callback({ "llama3.2", "codellama", "qwen2.5-coder" })
                return
            end
            
            callback(models)
        end)
    end)
end



---Completes the given prompt using the local Ollama instance.
---@param prompt string Input prompt.
---@param config bhop.Opts User config. Used to get the model and ollama_url.
---@param callback fun(completion_result: string): nil Function that gets called after the request is made.
---@return nil
function M.complete(prompt, config, callback)
    local ollama_url = (config.ollama_url or "http://localhost:11434") .. "/api/generate"
    local request_body = vim.json.encode {
        model = config.model,
        prompt = prompt,
        stream = false,
        options = {
            temperature = 0,
            num_predict = 50,
        }
    }
    
    vim.system({
        "curl",
        "-H",
        "Content-Type: application/json",
        "-d",
        request_body,
        ollama_url,
    }, {}, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                bhop_log.notify(
                    "Ollama Adapter: Request failed. " .. result.stderr,
                    vim.log.levels.ERROR
                )
                completion_logger.log_completion(prompt, "", config.model or "unknown", "ollama", false)
                callback("")
                return
            end
            
            local response = vim.json.decode(result.stdout)
            if not response then
                bhop_log.notify(
                    "Ollama Adapter: Invalid response from Ollama API",
                    vim.log.levels.ERROR
                )
                completion_logger.log_completion(prompt, "", config.model or "unknown", "ollama", false)
                callback("")
                return
            end
            
            if response.error then
                bhop_log.notify(
                    "Ollama Error: '" .. response.error .. "'",
                    vim.log.levels.ERROR
                )
                completion_logger.log_completion(prompt, response.error, config.model or "unknown", "ollama", false)
                callback("")
                return
            end
            
            if not response.response then
                bhop_log.notify(
                    "Ollama Adapter: Empty response from model",
                    vim.log.levels.ERROR
                )
                completion_logger.log_completion(prompt, "", config.model or "unknown", "ollama", false)
                callback("")
                return
            end
            
            -- Log successful completion
            completion_logger.log_completion(prompt, response.response, config.model or "unknown", "ollama", true)
            callback(response.response)
        end)
    end)
end

return M 