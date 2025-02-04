---@meta

---Configuration options for the bunnyhop plugin.
---@class bhop.Opts
---@field adapter "hugging_face" | "copilot"
---@field model string
---@field api_key string
---@field max_prev_width number

---Prediction data used by the predict and hop functions.
---@class bhop.Prediction
---@field config bhop.Opts
---@field adapter "hugging_face" | "copilot"
---@field DEFAULT_PRED_LINE number
---@field DEFAULT_PRED_COLUMN number
---@field DEFAULT_PRED_FILE string
---@field line number
---@field column number
---@field file string
