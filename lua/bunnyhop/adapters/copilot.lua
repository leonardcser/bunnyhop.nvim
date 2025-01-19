local bhop_log = require("bunnyhop.log")
local M = {}

---@type string|nil
local _oauth_token
local _expires_at

--- Finds the configuration path
local function find_config_path()
    if os.getenv("CODECOMPANION_TOKEN_PATH") then
        return os.getenv("CODECOMPANION_TOKEN_PATH")
    end

    local path = vim.fs.normalize("$XDG_CONFIG_HOME")

    if path and vim.fn.isdirectory(path) > 0 then
        return path
    elseif vim.fn.has("win32") > 0 then
        path = vim.fs.normalize("~/AppData/Local")
        if vim.fn.isdirectory(path) > 0 then
            return path
        end
    else
        path = vim.fs.normalize("~/.config")
        if vim.fn.isdirectory(path) > 0 then
            return path
        end
    end
end

---Get the Copilot OAuth token
--- The function first attempts to load the token from the environment variables,
--- specifically for GitHub Codespaces. If not found, it then attempts to load
--- the token from configuration files located in the user's configuration path.
---@return string|nil
local function get_github_token()
    if _oauth_token then
        return _oauth_token
    end

    local token = os.getenv("GITHUB_TOKEN")
    local codespaces = os.getenv("CODESPACES")
    if token and codespaces then
        return token
    end

    local config_path = find_config_path()
    if not config_path then
        return nil
    end

    local file_paths = {
        config_path .. "/github-copilot/hosts.json",
        config_path .. "/github-copilot/apps.json",
    }

    for _, file_path in ipairs(file_paths) do
        if vim.fn.filereadable(file_path) == 1 then
            local userdata = vim.fn.json_decode(vim.fn.readfile(file_path))
            for key, value in pairs(userdata) do
                if string.find(key, "github.com") then
                    return value.oauth_token
                end
            end
        end
    end

    return nil
end

---Authorize the GitHub OAuth token
---@param callback fun(github_token: string): nil
---@return nil
local function authorize_token(api_key, oauth_token, callback) --luacheck: no unused args
    if
        api_key ~= nil
        and api_key ~= ""
        and _expires_at ~= nil
        and _expires_at > os.time()
    then
        callback(api_key)
        return
    end

    vim.system({
        "curl",
        "-H",
        "Authorization: Bearer " .. oauth_token,
        "-H",
        "Accept: " .. "application/json",
        "https://api.github.com/copilot_internal/v2/token",
    }, {}, function(result)
        if result.code ~= 0 then
            bhop_log.notify(
                "Copilot Adapter: Token request error %s",
                result.stderr,
                vim.log.levels.ERROR
            )
            return
        end
        vim.schedule(function()
            local token = vim.fn.json_decode(result.stdout)
            if not token then
                bhop_log.notify(
                    "Copilot Adapter: Could not authorize your GitHub Copilot token",
                    vim.log.levels.ERROR
                )
                return
            end
            _expires_at = token.expires_at
            callback(token["token"])
        end)
    end)
end

---Processes the given api_key for the Hugging Face provider.
---If an error occurs, the function returns nil and if it was successful, it returns the api_key.
---@param api_key string
---@param callback fun(api_key: string | nil): nil Function that gets called after the request is made.
---@return nil
function M.process_api_key(api_key, callback)
    _oauth_token = get_github_token()
    if not _oauth_token then
        bhop_log.notify(
            "Copilot Adapter: No token found. Please refer to https://github.com/github/copilot.vim",
            vim.log.levels.ERROR
        )
        return
    end

    authorize_token(api_key, _oauth_token, callback)
end

---Gets the available models to use.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(models: string[]): nil Function that gets called after the request is made.
---@return nil
function M.get_models(config, callback) --luacheck: no unused args
    callback {
        "gpt-4o-2024-08-06",
        "claude-3.5-sonnet",
        "o1-2024-12-17",
        "o1-mini-2024-09-12",
    }
end

---Completes the given prompt.
---@param prompt string Input prompt.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(completion_result: string): nil Function that gets called after the request is made.
---@return nil
function M.complete(prompt, config, callback)
    authorize_token(config.api_key, _oauth_token, function(api_key)
        local url = "https://api.githubcopilot.com/chat/completions"
        local body = vim.json.encode {
            model = config.model,
            max_tokens = 50,
            messages = { { role = "user", content = prompt } },
            temperature = 0,
            n = 1,
            top_p = 1,
            stream = false,
        }

        vim.system({
            "curl",
            "-H",
            "Content-Type: application/json",
            "-H",
            "Copilot-Integration-Id: vscode-chat",
            "-H",
            "editor-version: Neovim/"
                .. vim.version().major
                .. "."
                .. vim.version().minor
                .. "."
                .. vim.version().patch,
            "-H",
            "Authorization: Bearer " .. api_key,
            "-d",
            body,
            url,
        }, {}, function(cmd_result)
            vim.schedule(function()
                if cmd_result.code ~= 0 then
                    bhop_log.notify(cmd_result.stderr, vim.log.levels.ERROR)
                    callback("")
                    return
                end
                local response = vim.json.decode(cmd_result.stdout)
                if response.error ~= nil then
                    bhop_log.notify(
                        "Copilot Error: '" .. response.error.message .. "'",
                        vim.log.levels.ERROR
                    )
                    callback("")
                    return
                end
                callback(response.choices[1].message.content)
            end)
        end)
    end)
end
return M
