# bunnyhop.nvim

Hop across your code at lightning speed ⚡️⚡️⚡️

> [!Note] This plugin is in alpha version, expect bugs, lacking features and
> documentation. If you found a bug, reporting it would be appriciated, while
> fixing it via a pull request would be greatly appriciated.

## Features

#### Supports Copilot, Hugging Face, and Ollama LLM's

#### Predicts your next desired cursor position a preview window, allowing you to hop to it via your chosen keybinding.

![bhop_feat_1](https://github.com/user-attachments/assets/2d25d126-ce59-4566-a5ee-6eaa78390dd0)

## Installation

### Prerequisites

Curl and its cli are required as they are used for performing http requests to
the different LLM providers.

Either Copilot (Recommended), Hugging Face's
[Serverless](https://huggingface.co/docs/api-inference/en/index), or Ollama for
local inference.

- **Copilot**: You only need to set it up via
  [copilot.lua](https://github.com/zbirenbaum/copilot.lua) or
  [copilot.vim](https://github.com/github/copilot.vim).
- **Hugging Face**: An API key is required. Learn how to set it up
  [here](https://huggingface.co/docs/api-inference/en/getting-started). Once you
  have the API key, create an environment variable for the key, eg.
  `export HF_API_KEY=************`.
- **Ollama**: Install [Ollama](https://ollama.ai) and pull your desired model
  (e.g., `ollama pull llama3.2` or `ollama pull qwen2.5-coder`). Make sure
  Ollama is running (`ollama serve`).

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "PLAZMAMA/bunnyhop.nvim",
    lazy = false, -- This plugin does not support lazy loading for now
    -- Setting the keybinding for hopping to the predicted location.
    -- Change it to whatever suits you.
    keys = {
        {
            "<C-h>",
            function()
                require("bunnyhop").hop()
            end,
            desc = "[H]op to predicted location.",
        },
    },
    opts = {
        -- Available options: "copilot", "huggingface", "ollama"
        adapter = "copilot",
        -- Model to use for chosen provider.
        -- To know what models are available for chosen adapter,
        -- run `:lua require("bunnyhop.adapters.{adapter}").get_models()`
        model = "gpt-4o-2024-08-06",
        -- Copilot and Ollama don't use the API key.
        -- Hugging Face does and its stored in an environment variable.
        -- Example where `HF_API_KEY` is the name of the environment variable:
        -- `api_key = "HF_API_KEY"`
        api_key = "",
        -- Ollama URL (only used with ollama adapter)
        ollama_url = "http://localhost:11434",
        -- Max width the preview window will be.
        -- Here for if you want to make the preview window bigger/smaller.
        max_prev_width = 20,
        -- This is an option to enable LOCAL data collection.
        -- Can be used to assess the accuracy of the predictions and will be used for better context creation.
        -- Currently its disabled by default to respect user privacy but will be required later for better performance and planned advanced features.
        collect_data = false,
    },
},
```

## Configuration

Bunnyhop is configured via the setup() function. The default configuration
values can be found [here](lua/bunnyhop/init.lua).

### Example Configurations

#### Using Ollama (Local LLM)

```lua
opts = {
    adapter = "ollama",
    model = "llama3.2", -- or "qwen2.5-coder", "codellama", etc.
    ollama_url = "http://localhost:11434", -- default Ollama URL
},
```

#### Using Copilot

```lua
opts = {
    adapter = "copilot",
    model = "gpt-4o-2024-08-06", -- or "claude-3.5-sonnet", "o1-2024-12-17", etc.
},
```

#### Using Hugging Face

```lua
opts = {
    adapter = "huggingface",
    model = "Qwen/Qwen2.5-Coder-32B-Instruct",
    api_key = "HF_API_KEY", -- environment variable name
},
```

## Development

### Run tests

Running tests requires either

- [luarocks][luarocks]
- or [busted][busted] and [nlua][nlua]

to be installed[^1]. [^1]: The test suite assumes that `nlua` has been added to
the PATH.

You can then run:

```bash
luarocks test --local
# or
busted
```

Or if you want to run a single test file:

```bash
luarocks test spec/path_to_file.lua --local
# or
busted spec/path_to_file.lua
```

### Common Errors

If you encounter the `module 'busted.runner' not found` or
`pl.path requires LuaFileSystem` errors, fix it by runing the following command
the following command:

```bash
eval $(luarocks path --no-bin)
```

If you encounter `sh: nlua: command not found` error the error above occurs
do[^1]:

#### Linux/Mac

Run the following command:

```bash
export PATH=$PATH:~/.luarocks/bin
```

#### Windows

See the following guide to a variable to the PATH: [add to
PATH][add-env-vars-windows].

> [!Note] For local testing to work you need to have Lua 5.1 set as your default
> version for luarocks. If that's not the case you can pass `--lua-version 5.1`
> to all the luarocks commands above, or set lua version 5.1 globally by running
> `luarocks config --scope system lua_version 5.1`.

## Acknowledgments

- Thank you [Oli Morris](https://github.com/olimorris) for encoraging me to make
  to plugin.
- [Cursor](https://github.com/getcursor/cursor) for the inspiration for this
  plugin.

[rockspec-format]: https://github.com/luarocks/luarocks/wiki/Rockspec-format
[luarocks]: https://luarocks.org
[luarocks-api-key]: https://luarocks.org/settings/api-keys
[gh-actions-secrets]:
  https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository
[busted]: https://lunarmodules.github.io/busted/
[nlua]: https://github.com/mfussenegger/nlua
[use-this-template]:
  https://github.com/new?template_name=nvim-lua-plugin-template&template_owner=nvim-lua
[add-env-vars-windows]:
  https://answers.microsoft.com/en-us/windows/forum/all/adding-path-variable/97300613-20cb-4d85-8d0e-cc9d3549ba23
