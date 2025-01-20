describe("Provider Tests", function()
    local providers = {}
    local bhop = require("bunnyhop")
    setup(function()
        local ADAPTERS_PATH = "./lua/bunnyhop/adapters/"
        for _, provider_path in
            pairs(vim.fn.glob(ADAPTERS_PATH .. "*.lua", false, true))
        do
            local provider_name = vim.fn.split(vim.fs.basename(provider_path), ".lua")[1]
            providers[provider_name] = require("bunnyhop.adapters." .. provider_name)
        end
        bhop.setup { api_key = "HF_API_KEY" }
    end)
    it("Test Providers Loaded", function()
        for _, provider in pairs(providers) do
            assert.is_table(provider)
        end
    end)
    it("Test get_models()", function()
        for _, provider in pairs(providers) do
            assert.is_function(provider.get_models)
            provider.get_models(bhop.config, function(models)
                assert.is_table(models)
            end)
        end
    end)
    it("Test complete()", function()
        for _, provider in pairs(providers) do
            assert.is_function(provider.complete)
            provider.complete(
                "test prompt, say 'hello there'",
                bhop.config,
                -- Looks like busted can't test this callback yet.
                -- This doesn't make sense as it works fine in the callback in "Test get_models()".
                -- I suspect it might be because get_models doesn't use neovim's callback functions.
                function(result)
                    assert.is_string(result)
                    assert.is_true(#result > 0)
                end
            )
        end
    end)
    it("Test process_api_key() Exists", function()
        for _, provider in pairs(providers) do
            assert.is_function(provider.process_api_key)
        end
    end)
    it("Test Hugging Face process_api_key()", function()
        local provider = providers["hugging_face"]
        provider.process_api_key("HF_API_KEY", function(api_key)
            assert.is_string(api_key)
            assert.is_true(api_key:match("hf_+") ~= nil)
        end)
    end)
    it("Test Copilot process_api_key()", function()
        local provider = providers["copilot"]
        local api_key = provider.process_api_key("", function(api_key)
            assert.is_string(api_key)
            assert.is_true(api_key:match("tid=+") ~= nil)
        end)
    end)
end)
