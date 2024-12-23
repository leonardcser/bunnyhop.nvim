-- Init of plugin

local M = {}

---@class bhop.opts
M.defaults = {
    ---@type "copilot"
    provier = "copilot",
    ---@type string
    api_key = "",
}

---@type string
M._config_path = nil

---Sets the Copilot OAuth token(API Key).
---The function first attempts to load the token from the GITHUB_TOKEN environment variable.
---If not found, it then attempts to load the token from configuration files located in the user's configuration path.
---@return nil
function M._set_copilot_api_key()
    if M.config.api_key then
        return
    end

    local token = os.getenv("GITHUB_TOKEN")
    if token then
        M.config.api_key = token
        return
    end

    -- Find config path.
    if M._config_path == nil then
        if
            vim.fn.has("win32") > 0
            and vim.fn.isdirectory(vim.fn.expand("~/AppData/Local")) > 0
        then
            M._config_path = vim.fn.expand("~/AppData/Local")
        elseif vim.fn.isdirectory(vim.fn.expand("$XDG_CONFIG_HOME")) > 0 then
            M._config_path = vim.fn.expand("$XDG_CONFIG_HOME")
        else
            vim.notify("Unable to find Config path", vim.log.levels.ERROR)
            return
        end
    end

    local file_paths = {
        M._config_path .. "/github-copilot/hosts.json",
        M._config_path .. "/github-copilot/apps.json",
    }

    for _, file_path in ipairs(file_paths) do
        if vim.fn.filereadable(file_path) == 1 then
            local userdata = vim.fn.json_decode(vim.fn.readfile(file_path))
            for key, value in pairs(userdata) do
                if string.find(key, "github.com") then
                    M.config.api_key =  value.oauth_token
                end
            end
        end
    end

    return nil
end

---Authorize the GitHub OAuth token
---@return table|nil
local function authorize_token()
    if _github_token and _github_token.expires_at > os.time() then
        log:debug("Reusing GitHub Copilot token")
        return _github_token
    end

    log:debug("Authorizing GitHub Copilot token")

    local request = curl.get("https://api.github.com/copilot_internal/v2/token", {
        headers = {
            Authorization = "Bearer " .. _oauth_token,
            ["Accept"] = "application/json",
        },
        insecure = config.adapters.opts.allow_insecure,
        proxy = config.adapters.opts.proxy,
        on_error = function(err)
            log:error("Copilot Adapter: Token request error %s", err)
        end,
    })

    _github_token = vim.fn.json_decode(request.body)
    return _github_token
end

function M._create_prompt()
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
        .. "ONLY output the row and column of the cursor in the format (row, column).\n"
        .. "DO NOT HALLUCINATE!\n"
        .. "# History of Cursor Jumps\n"
        .. csv_jumplist
    print(prompt)

    -- authenticate copilot and
    authorize_token()

    -- TODO: add the change list for each file in the jump list.
    -- local changelist = vim.api.getchangelist()
end

---Setup function
---@param opts? bhop.opts
function M.setup(opts)
    M.config = opts
end
return M
