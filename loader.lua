--[[
    HOOKID | Fish Hub - Modular Loader
    Loads modules one by one with smart yielding to prevent freezing
]]

local RunService = game:GetService("RunService")

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

-- Smart yield function using RunService.Heartbeat for smoother yielding
local function SmartYield(count)
    count = count or 1
    for i = 1, count do
        RunService.Heartbeat:Wait()
    end
end

-- Execute function with chunk-based yielding (for large modules)
local function ExecuteWithYielding(func)
    -- Try to execute, but if it takes too long, the yield points in the module itself will help
    local success, err = pcall(func)
    if not success then
        error(err)
    end
end

-- Load module with error handling (with smart yielding)
local function LoadModule(moduleInfo)
    local success, err = pcall(function()
        -- Yield before HTTP request
        SmartYield(3)
        
        local url = MODULE_BASE_URL .. moduleInfo.path
        local content = game:HttpGet(url, true)
        
        -- Yield after HTTP request
        SmartYield(3)
        
        local func = loadstring(content)
        if func then
            -- Yield before executing module (more aggressive for large modules)
            if moduleInfo.name == "core" then
                SmartYield(30)  -- Extra yield for core module
                print("[Loader] Loading core module (this is the largest module, please wait)...")
            else
                SmartYield(10)
            end
            
            -- Execute module with setfenv
            local env = getfenv(0)
            setfenv(func, env)
            
            -- Execute module
            -- Note: This is still blocking, but the delays before/after help reduce freeze impact
            print(string.format("[Loader] Executing module: %s...", moduleInfo.name))
            func()
            print(string.format("[Loader] ✓ Loaded module: %s", moduleInfo.name))
            
            -- Yield after executing module
            SmartYield(5)
            
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
-- Load essential modules first, then load others in background
task.spawn(function()
    print("========================================")
    print("[HookID] Starting modular loader...")
    print("========================================")

    local startTime = tick()
    local loadedCount = 0
    local failedCount = 0
    
    -- Separate essential and optional modules
    local essentialModules = {}
    local optionalModules = {}
    
    for _, moduleInfo in ipairs(MODULE_LOAD_ORDER) do
        if moduleInfo.required then
            table.insert(essentialModules, moduleInfo)
        else
            table.insert(optionalModules, moduleInfo)
        end
    end
    
    -- Load essential modules first (core, farm)
    print("[Loader] Loading essential modules...")
    for i, moduleInfo in ipairs(essentialModules) do
        SmartYield(5)
        
        if LoadModule(moduleInfo) then
            loadedCount = loadedCount + 1
            print(string.format("[Loader] Essential module '%s' loaded", moduleInfo.name))
        else
            failedCount = failedCount + 1
        end
        
        -- MUCH longer delay after essential modules to allow game to recover
        -- Core module is very large (1639 lines) and loads WindUI which is heavy
        if i == 1 then
            print("[Loader] ⚠ Core module loaded. Waiting 15 seconds for game to stabilize...")
            print("[Loader] This delay prevents freeze - please wait...")
            -- Very long delay after core to prevent freeze (core loads WindUI which is heavy)
            for frame = 1, 900 do  -- ~15 seconds at 60 FPS
                RunService.Heartbeat:Wait()
                -- Print progress every 3 seconds
                if frame % 180 == 0 then
                    local secondsPassed = math.floor(frame / 60)
                    print(string.format("[Loader] Still waiting... %d/%d seconds", secondsPassed, 15))
                end
            end
            print("[Loader] ✓ Game stabilized, continuing...")
        else
            SmartYield(180)  -- ~3 seconds after farm
        end
    end
    
    print("[Loader] Essential modules loaded. Loading optional modules in background...")
    
    -- Load optional modules with longer delays
    for i, moduleInfo in ipairs(optionalModules) do
        SmartYield(10)
        
        if LoadModule(moduleInfo) then
            loadedCount = loadedCount + 1
        else
            failedCount = failedCount + 1
        end
        
        -- Even longer delay for optional modules to prevent freeze
        if moduleInfo.name == "premium" or moduleInfo.name == "automatic" then
            SmartYield(120)  -- ~2 seconds for large modules
        else
            SmartYield(90)  -- ~1.5 seconds for smaller modules
        end
    end

    local loadTime = tick() - startTime

    print("========================================")
    print(string.format("[HookID] Loader completed in %.2fs", loadTime))
    print(string.format("Loaded: %d modules | Failed: %d modules", loadedCount, failedCount))
    print("========================================")
end)

