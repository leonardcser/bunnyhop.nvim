local M = {}

---@class bhop.opts
M.defaults = {
    ---@type string
    api_key = "",
}

-- TODO: Return to providing a copilot provider later (its wayyy to complex and undocumented for test)
---Gets the Copilot OAuth token(API Key).
---The function first attempts to load the token from the GITHUB_TOKEN environment variable.
---If not found, it then attempts to load the token from configuration files located in the user's configuration path.
---Returns an empty string if it failed to get copilot's api key(OAuth token).
---@param env_var_name? string
---@return string
local function _get_copilot_api_key(env_var_name)
    if env_var_name == nil then
        env_var_name = "GITHUB_TOKEN"
    end

    if M.config.api_key:match("[a-z]+") ~= nil then
        vim.notify(
            "Given Copilot API key is not a name of an enviornment variable",
            vim.log.levels.WARN
        )
    else
        local api_key = os.getenv(env_var_name)
        if api_key then
            return api_key
        end
    end

    -- Find config path.
    local _config_path = nil
    if
        vim.fn.has("win32") > 0
        and vim.fn.isdirectory(vim.fn.expand("~/AppData/Local")) > 0
    then
        _config_path = vim.fn.expand("~/AppData/Local")
    elseif vim.fn.isdirectory(vim.fn.expand("$XDG_CONFIG_HOME")) > 0 then
        _config_path = vim.fn.expand("$XDG_CONFIG_HOME")
    else
        vim.notify("Unable to find Config path", vim.log.levels.ERROR)
        return ""
    end

    local file_paths = {
        _config_path .. "/github-copilot/hosts.json",
        _config_path .. "/github-copilot/apps.json",
    }

    for _, file_path in ipairs(file_paths) do
        if vim.fn.filereadable(file_path) == 1 then
            local userdata = vim.fn.json_decode(vim.fn.readfile(file_path))
            for key, value in pairs(userdata) do
                if key:find("github.com") then
                    return value.oauth_token
                end
            end
        end
    end

    return ""
end

local function _get_copilot_response(prompt, api_key)
    print("HERE")
    local copilot_url = "https://api.githubcopilot.com/chat/completions"
    local request_body = vim.json.encode { ["messages"] = { prompt }, ["stream"] = false }

    -- TODO: Figure out how to send chat request to copilot
    -- ['vscode-sessionid'] = self.sessionid,
    -- ['vscode-machineid'] = self.machineid,
    local response = vim.system {
        "curl",
        " -X POST ",
        '-H "authorization: Bearer ' .. api_key .. '"',
        '-H "content-type: application/json"',
        '-H "copilot-integration-id: vscode-chat"',
        '-H "editor-version: Neovim/'
            .. vim.version().major
            .. "."
            .. vim.version().minor
            .. "."
            .. vim.version().patch
            .. '"',
        '-d "' .. request_body .. '" ',
        copilot_url,
    }
end

-- TODO: use this for later copilot integration
-- -- Get copilot api token
-- local api_key = _get_copilot_api_key(M.config.api_key)
-- if #api_key == 0 then
--     vim.notify("Wasn't Able to get Copilot's OAuth/API key.", vim.log.levels.ERROR)
--     return
-- end
--
-- _get_copilot_response(prompt, api_key)

-- TODO: Remove all the ".git/..." jumps from the jumplist
local function _create_prompt()
    -- Dict keys to column name convertor
    -- index (index of the table, 1 to n)
    -- lnum -> line_num
    -- bufnr -> buffer_name
    -- col -> column
    local JUMPLIST_COLUMNS = { "index", "line_num", "column", "buffer_name" }
    local jumplist = vim.fn.getjumplist()[1]
    local csv_jumplist = table.concat(JUMPLIST_COLUMNS, ",") .. "\n"

    for indx, jump_row in pairs(jumplist) do
        csv_jumplist = csv_jumplist
            .. indx
            .. ","
            .. jump_row["lnum"]
            .. ","
            .. jump_row["col"]
            .. ","
            .. vim.api.nvim_buf_get_name(jump_row["bufnr"])
            .. "\n"
    end

    local prompt = "Predict next cursor position based on the following information.\n"
        .. 'ONLY output the row and column of the cursor in the format [line_num, column, "buffer_name"].\n'
        .. "DO NOT HALLUCINATE!\n"
        .. "# History of Cursor Jumps\n"
        .. csv_jumplist

    -- TODO: add the change list for each file in the jump list.
    -- local changelist = vim.api.getchangelist()
    return prompt
end

function M.predict()
    local hf_url =
        "https://api-inference.huggingface.co/models/Qwen/Qwen2.5-Coder-32B-Instruct/v1/chat/completions"
    local prompt = _create_prompt()
    local request_body = vim.json.encode {
        ["model"] = "Qwen/Qwen2.5-Coder-32B-Instruct",
        ["messages"] = { { ["role"] = "user", ["content"] = prompt } },
        ["max_tokens"] = 30,
        ["stream"] = false,
    }
    -- TODO: Figure out why vim.system{...} doesn't work. (curl says it can't the url has nested braces)
    local response = vim.json.decode(
        vim.fn.system(
            "curl"
                .. " -s"
                .. ' "'
                .. hf_url
                .. '"'
                .. " -X POST"
                .. ' -H "Authorization: Bearer '
                .. M.config.api_key
                .. '"'
                .. ' -H "Content-Type: application/json"'
                .. " -d '"
                .. request_body
                .. "'"
        )
    )
    local prediction = vim.json.decode(response.choices[1].message.content)

    vim.cmd("edit " .. prediction[3])
    vim.api.nvim_win_set_cursor(0, { prediction[1], prediction[2] - 1 })
end

-- TODO: Move jump logic to here and make predict into an Autocommand that activate everytime the person enters normal mode.
function M.jump()
end

---Setup function
---@param opts? bhop.opts
function M.setup(opts)
    if opts == nil then
        M.config = M.defaults
    else
        M.config = opts
    end

    if #M.config.api_key == 0 then
        vim.notify(
            "API key wasn't given, please set the api_key in the opts table to an enviornment variable name.",
            vim.log.levels.ERROR
        )
    elseif M.config.api_key:match("[a-z]+") ~= nil then
        vim.notify(
            "Given API key is not a name of an enviornment variable.",
            vim.log.levels.ERROR
        )
    else
        local api_key = os.getenv(M.config.api_key)
        if api_key then
            M.config.api_key = api_key
        else
            vim.notify(
                "Wasn't able to get API key from the enviornment.",
                vim.log.levels.ERROR
            )
        end
    end
end

return M
