---@meta

---Configuration options for the bunnyhop plugin.
---@class bhop.Opts
---@field adapter "hugging_face" | "copilot" | "ollama" | "openrouter"
-- Model to use for chosen provider.
-- To know what models are available for chosen adapter,
-- run `:lua require("bunnyhop.adapters.{adapter}").get_models()`
---@field model string
-- Copilot and Ollama don't use the API key, Hugging Face does.
---@field api_key string
-- Ollama URL (only used with ollama adapter)
---@field ollama_url string
-- OpenRouter URL (only used with openrouter adapter)
---@field openrouter_url string
-- Max width the preview window will be.
-- Here for if you want to make the preview window bigger/smaller.
---@field max_prev_width number
-- Collects data locally when set to true. NO DATA LEAVES YOUR PC!
---@field collect_data boolean

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
---@field model string model used to predict the
