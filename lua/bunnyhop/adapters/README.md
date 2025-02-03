# LLM Interface Spec

This document is meant to document/explain how to create new LLM providers.
The only thing that needs to be implemented to create a new LLM provider is the functions specified by the spec below.

## Spec
The spec currently has three different functions that need to be implemented.

### General Requirements of each function
- It should be non-blocking and async.
- It should be documented with the types shown in the examples below.
- It should pass on its output to the given callback.

```lua
---Processes the given api_key for the Hugging Face provider.
---If an error occurs, the function returns nil and if it was successful, it returns the api_key.
---@param api_key string
---@param callback fun(api_key: string | nil): nil Function that gets called after the request is made.
---@return nil
local function process_api_key(api_key, callback)
end
```
Example Callback Input(aka function output):
```lua
"hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

```lua
---Gets the available models to use.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(models: string[]): nil Function that gets called after the request is made.
---@return nil
local function get_models(callback)
end
```
Example Callback Input:
```lua
{"gpt-3", "gpt-4", "o1-mini", "o1-preview"}
```

```lua
---Completes the given prompt.
---@param prompt string Input prompt.
---@param config bhop.Opts User config. Used to get the api_key for now, mabye more things later.
---@param callback fun(completion_result: string): nil Function that gets called after the request is made.
---@return nil
local function complete(prompt, config, callback)
end
```
Example Callback Input:
```lua
"I'm the a model based on the GPT-4 architecture..."
```
