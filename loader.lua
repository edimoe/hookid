--[[
    HOOKID | Fish Hub - Modular Loader
    Loads modules one by one to reduce initial load time
]]

local MODULE_BASE_URL = "https://raw.githubusercontent.com/edimoe/hookid/refs/heads/main/"

-- Module loading order (core must be loaded first)
local MODULE_LOAD_ORDER = {
    -- Core systems (must load first)
    { name = "core", path = "modules/core/core.lua", required = true },
    
    -- Tab modules (load after core)
    { name = "farm", path = "modules/tabs/farm.lua", required = true },
    { name = "automatic", path = "modules/tabs/automatic.lua", required = false },
    { name = "teleport", path = "modules/tabs/teleport.lua", required = false },
    { name = "shop", path = "modules/tabs/shop.lua", required = false },
    { name = "premium", path = "modules/tabs/premium.lua", required = false },
    { name = "quest", path = "modules/tabs/quest.lua", required = false },
    { name = "event", path = "modules/tabs/event.lua", required = false },
    { name = "utility", path = "modules/tabs/utility.lua", required = false },
    { name = "webhook", path = "modules/tabs/webhook.lua", required = false },
    { name = "settings", path = "modules/tabs/settings.lua", required = false },
    { name = "about", path = "modules/tabs/about.lua", required = false },
}

-- Load module with error handling (with better yielding)
local function LoadModule(moduleInfo)
    local success, err = pcall(function()
        -- Yield before HTTP request to prevent freeze
        for i = 1, 2 do task.wait() end
        
        local url = MODULE_BASE_URL .. moduleInfo.path
        local content = game:HttpGet(url, true)
        
        -- Yield after HTTP request
        for i = 1, 2 do task.wait() end
        
        local func = loadstring(content)
        if func then
            -- Yield before executing module
            for i = 1, 3 do task.wait() end
            
            -- Execute module (this may take time for large modules)
            func()
            
            -- Yield after executing module
            for i = 1, 2 do task.wait() end
            
            print(string.format("[Loader] ✓ Loaded module: %s", moduleInfo.name))
            return true
        else
            error("Failed to compile module: " .. moduleInfo.name)
        end
    end)
    
    if not success then
        local msg = string.format("[Loader] ✗ Failed to load module '%s': %s", moduleInfo.name, tostring(err))
        if moduleInfo.required then
            warn(msg .. " (REQUIRED MODULE - SCRIPT MAY NOT WORK)")
        else
            warn(msg .. " (Optional module - continuing...)")
        end
        return false
    end
    
    return true
end

-- Main loader (async to prevent freezing)
task.spawn(function()
    print("========================================")
    print("[HookID] Starting modular loader...")
    print("========================================")

    local startTime = tick()
    local loadedCount = 0
    local failedCount = 0

    for i, moduleInfo in ipairs(MODULE_LOAD_ORDER) do
        -- Yield before each module
        task.wait()
        
        if LoadModule(moduleInfo) then
            loadedCount = loadedCount + 1
        else
            failedCount = failedCount + 1
        end
        
        -- Longer delay between loads to prevent freezing
        -- Core module gets more time (it's the largest)
        if i == 1 then
            for j = 1, 10 do task.wait() end  -- Core: ~1.6s delay (allows game to recover)
        elseif i == 2 then
            for j = 1, 5 do task.wait() end   -- Farm: ~800ms delay
        else
            for j = 1, 8 do task.wait() end   -- Other modules: ~1.3s delay
        end
    end

    local loadTime = tick() - startTime

    print("========================================")
    print(string.format("[HookID] Loader completed in %.2fs", loadTime))
    print(string.format("Loaded: %d modules | Failed: %d modules", loadedCount, failedCount))
    print("========================================")
end)

