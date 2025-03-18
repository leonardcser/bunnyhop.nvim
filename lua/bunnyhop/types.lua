---@meta

---Configuration options for the bunnyhop plugin.
---@class bhop.Opts
---@field adapter "hugging_face" | "copilot"
-- Model to use for chosen provider.
-- To know what models are available for chosen adapter,
-- run `:lua require("bunnyhop.adapters.{adapter}").get_models()`
---@field model string
-- Copilot doesn't use the API key, Hugging Face does.
---@field api_key string
-- Max width the preview window will be.
-- Here for if you want to make the preview window bigger/smaller.
---@field max_prev_width number

---Prediction data used by the predict and hop functions.
---@class bhop.Prediction
---@field line number
---@field column number
---@field file string

---Entry of the undo history(no branching, only root path of the tree)
---@class bhop.UndoEntry
---@field bufnr number
---@field diff number
---@field line number
---@field seq number
---@field time number

---Entry of the editlist
---@class bhop.EditEntry
---@field seq number state number
---@field time number state time
---@field diff string the diff
---@field file string edited file
---@field line number starting edited line number of the diff
---@field prediction_line number predicted line
---@field prediction_file string predicted file
---@field model string model used to predict the
