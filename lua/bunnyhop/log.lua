local M = {}

function M.notify(msg, level, opts)
    if opts == nil then
        opts = {}
    end
    opts["title"] = "bunnyhop.nvim"
    vim.notify(msg, level, opts)
end

return M
