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
        end
    end)
    it("Test process_api_key() Exists", function()
        for _, provider in pairs(providers) do
            assert.is_function(provider.process_api_key)
        end
    end)
end)
