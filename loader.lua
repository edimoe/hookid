--[[
    HOOKID | Fish Hub - Smooth Modular Loader
    Loads modules one by one using coroutines to reduce freeze
]]

-- Prevent double-loading in the same session
if _G.HookID_LoaderStarted then
    warn("[HookID] Loader already started, skipping duplicate load.")
    return
end
_G.HookID_LoaderStarted = true

local MODULE_BASE_URL = "https://raw.githubusercontent.com/edimoe/hookid/refs/heads/main/"
local MODULE_LOAD_DELAY = 0.25
local MODULE_PREP_YIELD = 0.03

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
    { name = "event", path = "modules/tabs/event.lua", required = false },
    { name = "utility", path = "modules/tabs/utility.lua", required = false },
    { name = "webhook", path = "modules/tabs/webhook.lua", required = false },
    { name = "settings", path = "modules/tabs/settings.lua", required = false },
    { name = "about", path = "modules/tabs/about.lua", required = false },
}

-- Load module with error handling
local function LoadModule(moduleInfo)
    local success, err = pcall(function()
        local url = MODULE_BASE_URL .. moduleInfo.path
        local content = game:HttpGet(url, true)
        local func = loadstring(content)
        if func then
            task.wait(MODULE_PREP_YIELD)
            func()
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

-- Main loader
print("========================================")
print("[HookID] Starting smooth modular loader...")
print("========================================")

local startTime = tick()
local loadedCount = 0
local failedCount = 0

-- Load core first (blocking) to show GUI fast
LoadModule(MODULE_LOAD_ORDER[1])
loadedCount = loadedCount + 1

-- Load remaining modules sequentially in a single coroutine to reduce spikes
task.spawn(function()
    for i = 2, #MODULE_LOAD_ORDER do
        local moduleInfo = MODULE_LOAD_ORDER[i]
        if LoadModule(moduleInfo) then
            loadedCount = loadedCount + 1
        else
            failedCount = failedCount + 1
        end
        task.wait(MODULE_LOAD_DELAY) -- larger delay to reduce load spikes
    end
end)

-- Optional: wait a short moment to let coroutines start
task.wait(0.1)

local loadTime = tick() - startTime
print("========================================")
print(string.format("[HookID] Loader initiated in %.2fs", loadTime))
print("Loaded modules (core started + coroutines): %d | Failed modules: %d", loadedCount, failedCount)
print("========================================")
