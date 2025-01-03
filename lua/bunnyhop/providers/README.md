# LLM Interface Spec

This document is meant to document/explain how to create new LLM providers.
The only thing that needs to be implemented to create a new LLM provider is the functions specified by the spec below.

## Spec
The spec currently has three different functions that need to be implemented.

### General Requirements of each function
- It should be non-blocking and async.
- It should be documented with the types shown in the examples below.

```lua
---Gets the available models to use.
---@param callback function Function that gets called after the request is made.
---@return string[]
local function get_models(callback)
end
```
Example output:
```lua
{"gpt-3", "gpt-4", "o1-mini", "o1-preview"}
```

```lua
---Completes the given prompt.
---@param prompt string Input prompt.
---@param model string LLM model name.
---@param config bhop.config User config. Used to get the api_key for now, mabye more things later.
---@param callback function Function that gets called after the request is made.
---@return nil
function M.complete(prompt, model, config, callback)
end
```
Example output:
```lua
"I'm the a model based on the GPT-4 architecture..."
```
