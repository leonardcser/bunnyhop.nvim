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
---@return string[]
function get_models()
end
```
Example output:
```lua
{"gpt-3", "gpt-4", "o1-mini", "o1-preview"}
```

```lua
---Sets the given model.
---Model must be one of the models returned in get_models().
---@param model_name string
---@return nil
function set_model(model_name)
end
```


```lua
---Completes the given prompt.
---@param prompt string
---@return string
function complete(prompt)
end
```
Example output:
```lua
"I'm the a model based on the GPT-4 architecture..."
```
