WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
Window = WindUI:CreateWindow({
    Title = "HOOKID | Fish Hub",
    Icon = "anchor",
    Author = "PREMIUM",
    Folder = "HOOKIDFish",
    Size = UDim2.fromOffset(500, 350),
    MinSize = Vector2.new(500, 350),
    MaxSize = Vector2.new(1100, 850),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 65,
    BackgroundImageTransparency = 0.94,
    BackgroundImage = "rbxassetid://5553946656",
    ToggleKey = Enum.KeyCode.End,
    HideSearchBar = true,
    ScrollBarEnabled = true,
})

-- Custom Theme: Ocean Teal
WindUI:SetTheme({
    Name = "HOOKID Ocean",
    Accent = Color3.fromRGB(0, 210, 175),
    Background = Color3.fromRGB(8, 12, 18),
    SecondaryBackground = Color3.fromRGB(14, 22, 30),
    TextColor = Color3.fromRGB(255, 255, 255),
    SecondaryTextColor = Color3.fromRGB(140, 190, 200),
    PlaceholderColor = Color3.fromRGB(80, 110, 120),
})

-- =================================================================
-- THREAD CLEANUP VERIFICATION SYSTEM
-- =================================================================
ThreadManager = {
    -- Track semua active threads
    activeThreads = {},
    
    -- Verification timeout (seconds)
    verificationTimeout = 2,
    
    -- Enable/disable verification
    enableVerification = true,
}

-- Register thread untuk tracking
function ThreadManager:Register(threadId, thread, description)
    if not threadId or not thread then return end
    
    self.activeThreads[threadId] = {
        thread = thread,
        description = description or "Unknown",
        registeredAt = os.clock(),
        cancelled = false,
    }
    
    return threadId
end

-- Cancel thread dengan verification
function ThreadManager:Cancel(threadId, force)
    if not threadId then return false end
    
    local threadData = self.activeThreads[threadId]
    if not threadData then
        -- Thread tidak terdaftar, coba cancel langsung
        if threadId and type(threadId) == "thread" then
            local success = pcall(function() task.cancel(threadId) end)
            return success
        end
        return false
    end
    
    if threadData.cancelled then
        -- Thread sudah di-cancel sebelumnya
        return true
    end
    
    -- Cancel thread
    local success = pcall(function()
        if threadData.thread then
            task.cancel(threadData.thread)
        end
    end)
    
    if not success then
        warn(string.format("[ThreadManager] Failed to cancel thread '%s': %s", threadId, threadData.description))
        return false
    end
    
    threadData.cancelled = true
    threadData.cancelledAt = os.clock()
    
    -- Verification (optional, bisa di-disable untuk performance)
    if self.enableVerification and not force then
        task.spawn(function()
            task.wait(self.verificationTimeout)
            self:VerifyStopped(threadId)
        end)
    end
    
    return true
end

-- Verify thread benar-benar stopped
function ThreadManager:VerifyStopped(threadId)
    local threadData = self.activeThreads[threadId]
    if not threadData then return true end
    
    -- Check jika thread masih running (dengan cara check status)
    -- Note: Roblox tidak punya direct way untuk check thread status
    -- Jadi kita hanya bisa verify berdasarkan waktu dan flag
    
    if not threadData.cancelled then
        warn(string.format("[ThreadManager] Thread '%s' (%s) was not properly cancelled!", threadId, threadData.description))
        return false
    end
    
    -- Thread sudah di-mark sebagai cancelled
    -- Unregister setelah verification
    self.activeThreads[threadId] = nil
    return true
end

-- Cancel all threads
function ThreadManager:CancelAll(description)
    local count = 0
    for threadId, threadData in pairs(self.activeThreads) do
        if self:Cancel(threadId, true) then
            count = count + 1
        end
    end
    
    if description then
        print(string.format("[ThreadManager] Cancelled %d threads: %s", count, description))
    end
    
    return count
end

-- Get active threads count
function ThreadManager:GetActiveCount()
    local count = 0
    for _, threadData in pairs(self.activeThreads) do
        if not threadData.cancelled then
            count = count + 1
        end
    end
    return count
end

-- Unregister thread (setelah verified stopped)
function ThreadManager:Unregister(threadId)
    self.activeThreads[threadId] = nil
end

-- Get thread status untuk debugging
function ThreadManager:GetThreadStatus(threadId)
    local threadData = self.activeThreads[threadId]
    if not threadData then
        return { exists = false, status = "Not Registered" }
    end
    
    return {
        exists = true,
        description = threadData.description,
        registeredAt = threadData.registeredAt,
        cancelled = threadData.cancelled,
        cancelledAt = threadData.cancelledAt,
        age = os.clock() - threadData.registeredAt,
    }
end

-- Print all active threads (untuk debugging)
function ThreadManager:PrintActiveThreads()
    local activeCount = 0
    local cancelledCount = 0
    
    print("========================================")
    print("[ThreadManager] Active Threads Status:")
    print("========================================")
    
    for threadId, threadData in pairs(self.activeThreads) do
        if threadData.cancelled then
            cancelledCount = cancelledCount + 1
            print(string.format("  [CANCELLED] %s (%s) - Age: %.2fs", threadId, threadData.description, os.clock() - threadData.registeredAt))
        else
            activeCount = activeCount + 1
            print(string.format("  [ACTIVE] %s (%s) - Age: %.2fs", threadId, threadData.description, os.clock() - threadData.registeredAt))
        end
    end
    
    print(string.format("Total: %d active, %d cancelled", activeCount, cancelledCount))
    print("========================================")
end

-- Cleanup all threads on script end (optional)
game.Players.LocalPlayer.PlayerGui.ChildRemoved:Connect(function()
    -- Cleanup jika player leave
    ThreadManager:CancelAll("Player leaving")
end)

-- =================================================================
-- CONNECTION MANAGER (Memory Leak Prevention)
-- =================================================================
ConnectionManager = {
    -- Track semua active connections
    activeConnections = {},
    
    -- Connection groups untuk cleanup by category
    connectionGroups = {},
}

-- Register connection untuk tracking
function ConnectionManager:Register(connectionId, connection, description, group)
    if not connectionId or not connection then return false end
    
    self.activeConnections[connectionId] = {
        connection = connection,
        description = description or "Unknown Connection",
        registeredAt = os.clock(),
        group = group or "default",
    }
    
    -- Add to group
    if not self.connectionGroups[group or "default"] then
        self.connectionGroups[group or "default"] = {}
    end
    table.insert(self.connectionGroups[group or "default"], connectionId)
    
    return true
end

-- Disconnect connection dengan safety check
function ConnectionManager:Disconnect(connectionId)
    if not connectionId then return false end
    
    local connData = self.activeConnections[connectionId]
    if not connData then
        -- Connection tidak terdaftar, coba disconnect langsung
        if connectionId and type(connectionId) == "RBXScriptConnection" then
            local success = pcall(function() connectionId:Disconnect() end)
            return success
        end
        return false
    end
    
    -- Disconnect connection
    local success = pcall(function()
        if connData.connection and connData.connection.Disconnect then
            connData.connection:Disconnect()
        end
    end)
    
    if not success then
        warn(string.format("[ConnectionManager] Failed to disconnect '%s': %s", connectionId, connData.description))
        return false
    end
    
    -- Remove from group
    local group = connData.group or "default"
    if self.connectionGroups[group] then
        for i, id in ipairs(self.connectionGroups[group]) do
            if id == connectionId then
                table.remove(self.connectionGroups[group], i)
                break
            end
        end
    end
    
    -- Unregister
    self.activeConnections[connectionId] = nil
    
    return true
end

-- Disconnect all connections in a group
function ConnectionManager:DisconnectGroup(groupName)
    if not self.connectionGroups[groupName] then return 0 end
    
    local count = 0
    -- Copy table karena kita akan modify selama iterate
    local groupCopy = {}
    for _, connId in ipairs(self.connectionGroups[groupName]) do
        table.insert(groupCopy, connId)
    end
    
    for _, connId in ipairs(groupCopy) do
        if self:Disconnect(connId) then
            count = count + 1
        end
    end
    
    self.connectionGroups[groupName] = nil
    
    return count
end

-- Disconnect all connections
function ConnectionManager:DisconnectAll(description)
    local count = 0
    -- Copy table karena kita akan modify selama iterate
    local connectionsCopy = {}
    for connId, _ in pairs(self.activeConnections) do
        table.insert(connectionsCopy, connId)
    end
    
    for _, connId in ipairs(connectionsCopy) do
        if self:Disconnect(connId) then
            count = count + 1
        end
    end
    
    if description then
        print(string.format("[ConnectionManager] Disconnected %d connections: %s", count, description))
    end
    
    return count
end

-- Get active connections count
function ConnectionManager:GetActiveCount()
    local count = 0
    for _, _ in pairs(self.activeConnections) do
        count = count + 1
    end
    return count
end

-- Get connections by group
function ConnectionManager:GetGroupConnections(groupName)
    if not self.connectionGroups[groupName] then return {} end
    
    local connections = {}
    for _, connId in ipairs(self.connectionGroups[groupName]) do
        if self.activeConnections[connId] then
            table.insert(connections, {
                id = connId,
                data = self.activeConnections[connId]
            })
        end
    end
    return connections
end

-- Print all active connections (untuk debugging)
function ConnectionManager:PrintActiveConnections()
    local count = 0
    
    print("==========================================")
    print("[ConnectionManager] Active Connections:")
    print("==========================================")
    
    -- Group by group
    for groupName, connIds in pairs(self.connectionGroups) do
        print(string.format("Group: %s (%d connections)", groupName, #connIds))
        for _, connId in ipairs(connIds) do
            local connData = self.activeConnections[connId]
            if connData then
                count = count + 1
                print(string.format("  - %s (%s) - Age: %.2fs", connId, connData.description, os.clock() - connData.registeredAt))
            end
        end
    end
    
    print(string.format("Total: %d active connections", count))
    print("==========================================")
end

-- Helper function untuk safe connect dengan auto-registration
function SafeConnect(event, callback, connectionId, description, group)
    if not event then 
        warn(string.format("[ConnectionManager] Cannot connect: event is nil for '%s'", connectionId or "unknown"))
        return nil
    end
    
    local connection = event:Connect(callback)
    
    if connectionId then
        ConnectionManager:Register(connectionId, connection, description, group)
    end
    
    return connection
end

-- Helper function untuk safe disconnect dengan cleanup
function SafeDisconnect(connectionId)
    return ConnectionManager:Disconnect(connectionId)
end

print("[HookID] Connection Manager initialized")

-- Helper function untuk cancel thread dengan verification
function SafeCancelThread(threadVar, threadId, description)
    if not threadVar then return true end
    
    -- Register jika belum terdaftar
    if threadId and not ThreadManager.activeThreads[threadId] then
        ThreadManager:Register(threadId, threadVar, description)
    end
    
    -- Cancel dengan verification
    local success = ThreadManager:Cancel(threadId or "unknown", false)
    
    if success then
        threadVar = nil
    end
    
    return success, threadVar
end

-- Helper function untuk spawn thread dengan auto-registration
function SafeSpawnThread(threadId, callback, description)
    local thread = task.spawn(function()
        local success, err = pcall(callback)
        if not success then
            warn(string.format("[ThreadManager] Thread '%s' (%s) error: %s", threadId, description or "Unknown", tostring(err)))
        end
    end)
    
    if threadId then
        ThreadManager:Register(threadId, thread, description)
    end
    
    return thread
end

-- Helper function untuk cancel thread dengan verification (simplified)
function CancelThread(threadVar, threadId, description)
    if not threadVar then return true end
    
    -- Register jika belum terdaftar
    if threadId and not ThreadManager.activeThreads[threadId] then
        ThreadManager:Register(threadId, threadVar, description or "Unknown Thread")
    end
    
    -- Cancel dengan verification
    local success = ThreadManager:Cancel(threadId or "unknown", false)
    
    if success then
        return true, nil
    end
    
    return false, threadVar
end

-- Helper untuk spawn thread dengan auto-cleanup
function SpawnThread(threadId, callback, description)
    local thread = task.spawn(function()
        local success, err = pcall(callback)
        if not success then
            warn(string.format("[ThreadManager] Thread '%s' (%s) error: %s", threadId, description or "Unknown", tostring(err)))
        else
            -- Auto unregister ketika thread selesai
            ThreadManager:Unregister(threadId)
        end
    end)
    
    if threadId then
        ThreadManager:Register(threadId, thread, description)
    end
    
    return thread
end

print("[HookID] Thread Cleanup Verification System initialized")

-- =================================================================
-- CONSTANTS TABLE (All Magic Numbers & Hardcoded Values)
-- =================================================================
CONSTANTS = {
    -- UI Constants
    BackgroundImageTransparency = 0.94,
    
    -- Config System
    ConfigUpdateBatchSize = 10, -- Update UI setiap N perubahan untuk anti-freeze
    
    -- Frame Budget System
    FrameBudgetMaxTime = 8, -- Maximum 8ms per frame untuk 120 FPS target
    FrameBudgetDefaultCooldown = 0.016, -- Default 16ms (60 FPS)
    FrameBudgetStatsSmoothing = 0.99, -- Exponential smoothing factor untuk stats
    
    -- Consolidated Equip System
    EquipCooldown = 0.1, -- 100ms cooldown (10x per detik)
    
    -- Remote Path
    RemotePath = {"Packages", "_Index", "sleitnick_net@0.2.0", "net"},
    RemoteDefaultTimeout = 0.5, -- Default timeout untuk GetRemote
    
    -- Character & Movement
    DefaultWalkSpeed = 18,
    DefaultJumpPower = 50,
    TeleportYOffset = 0.5, -- Y offset saat teleport
    
    -- GetHRP Timeout
    HRPWaitTimeout = 5, -- Timeout untuk WaitForChild HumanoidRootPart
    
    -- GetPlayerDataReplion Timeouts
    ReplionPackagesTimeout = 10, -- Timeout untuk WaitForChild Packages
    ReplionDataTimeout = 5, -- Timeout untuk WaitReplion Data
    
    -- Item Processing
    UUIDShortLength = 8, -- Length untuk short UUID display
    CensorPrefixLength = 3, -- Length untuk censor name prefix
    
    -- Enchant System
    EnchantStoneID = 10,
    EnchantAltarPos = Vector3.new(3236.441, -1302.855, 1397.910),
    EnchantAltarLook = Vector3.new(-0.954, -0.000, 0.299),
    EnchantEquipDelay = 0.2, -- Delay setelah equip rod/stone
    EnchantToolDelay = 0.3, -- Delay setelah equip tool
    EnchantActivateDelay = 0.5, -- Delay setelah activate altar
    EnchantUnequipDelay = 0.5, -- Delay setelah unequip
    EnchantSetupWait = 2.5, -- Wait sebelum mulai enchant loop
    EnchantTeleportWait = 1.5, -- Wait setelah teleport ke altar
    
    -- Event System
    EventFoundWait = 900, -- Wait setelah event found (15 minutes)
    EventScanInterval = 10, -- Interval scan event (seconds)
    EventTeleportYOffset = 15, -- Y offset untuk event teleport
    MegalodonTeleportYOffset = 3, -- Y offset khusus untuk Megalodon
    TreasureEventYOffset = 5, -- Y offset untuk Treasure Event
    
    -- Fishing Delays
    SpeedLegitDefault = 0.05, -- Default legit click speed
    SpeedLegitMin = 0.01, -- Minimum legit click speed
    SpeedLegitMax = 0.5, -- Maximum legit click speed
    NormalCompleteDelayDefault = 1.50, -- Default normal instant complete delay
    NormalCompleteDelayMin = 0.5, -- Minimum normal complete delay
    NormalCompleteDelayMax = 5.0, -- Maximum normal complete delay
    NormalFishingDelay = 0.1, -- Delay di normal fishing loop
    NormalCancelDelay = 0.3, -- Delay setelah cancel fishing inputs
    
    -- Blatant Mode Delays
    BlatantCompleteDelay = 3.055,
    BlatantCancelDelay = 0.3,
    BlatantLoopInterval = 1.715,
    BlatantMaxRetries = 2,
    BlatantRetryDelay = 0.5,
    BlatantEquipDelay = 0.2, -- Delay untuk blatant equip thread
    
    -- Auto Sell
    AutoSellDefaultDelay = 50, -- Default delay untuk auto sell (seconds)
    AutoSellDefaultCount = 50, -- Default count untuk auto sell
    AutoSellCooldown = 2, -- Cooldown setelah sell
    AutoSellCheckInterval = 1, -- Interval check untuk auto sell
    
    -- Auto Favorite
    AutoFavoriteActionDelay = 0.5, -- Delay antara favorite actions
    AutoFavoriteWaitTime = 1, -- Wait time antara check cycles
    
    -- Auto Trade
    AutoTradeWait = 2, -- Wait untuk auto accept trade
    AutoTradeDelay = 0.5, -- Delay untuk trade operations
    
    -- Quest System
    QuestTeleportWait = 1.5, -- Wait setelah teleport ke quest location
    QuestFishingWait = 0.5, -- Wait sebelum start fishing di quest
    QuestBoardWait = 2, -- Wait setelah teleport ke quest board
    
    -- Kaitun System
    KaitunEquipCheckInterval = 20, -- Re-check gear every N cycles
    KaitunEquipThreadDelay = 0.1, -- Delay untuk equip thread
    KaitunAutoSellInterval = 30, -- Auto sell interval (seconds)
    
    -- Shop/Merchant
    MerchantUpdateInterval = 1, -- Update interval untuk merchant display (seconds)
    
    -- Notification
    NotificationDefaultDuration = 3, -- Default notification duration (seconds)
    
    -- Artifact/Item IDs
    OxygenTankID = 105, -- ID untuk Oxygen Tank
    
    -- Character Spawn
    CharacterSpawnWait = 1, -- Wait setelah character spawn
    
    -- Anti-AFK
    AntiAFKEnabled = true, -- Enable anti-AFK by default
}

-- [[ 1. CONFIGURATION SYSTEM SETUP ]] --
HookIDConfig = Window.ConfigManager:CreateConfig("hookid")

-- [BARU] Tabel untuk menyimpan semua elemen UI agar bisa dicek valuenya
ElementRegistry = {} 

-- Fungsi Helper Reg yang sudah di-upgrade
function Reg(id, element)
    -- Prevent duplicate registrations
    if ElementRegistry[id] then
        warn(string.format("[Reg] Element '%s' already registered, skipping duplicate registration", id))
        return ElementRegistry[id]
    end
    
    -- Check registration limit
    local currentCount = 0
    for _ in pairs(ElementRegistry) do
        currentCount = currentCount + 1
    end
    
    if currentCount >= 200 then
        warn(string.format("[Reg] Registration limit reached (%d/200), cannot register '%s'", currentCount, id))
        return element -- Return element anyway but don't register
    end
    
    local success, err = pcall(function()
        HookIDConfig:Register(id, element)
    end)
    
    if not success then
        warn(string.format("[Reg] Failed to register '%s': %s", id, tostring(err)))
        return element
    end
    
    -- Simpan elemen ke tabel lokal kita
    ElementRegistry[id] = element 
    return element
end

local HttpService = game:GetService("HttpService")
local BaseFolder = "WindUI/" .. (Window.Folder or "HookID") .. "/config/"

function SmartLoadConfig(configName)
    local path = BaseFolder .. configName .. ".json"
    
    -- 1. Cek File
    if not isfile(path) then 
        WindUI:Notify({ Title = "Failed to Load", Content = "File not found: " .. configName, Duration = 3, Icon = "x" })
        return 
    end

    -- 2. Cek Isi File & Decode
    local content = readfile(path)
    local success, decodedData = pcall(function() return HttpService:JSONDecode(content) end)

    if not success or not decodedData then 
        WindUI:Notify({ Title = "Gagal Load", Content = "File JSON rusak/kosong.", Duration = 3, Icon = "alert-triangle" })
        return 
    end

    -- [FIX PENTING] Ambil data dari '__elements' jika ada
    local realData = decodedData
    if decodedData["__elements"] then
        realData = decodedData["__elements"]
    end

    local changeCount = 0
    local foundCount = 0

    -- Debug: Hitung total registry script saat ini
    for _ in pairs(ElementRegistry) do foundCount = foundCount + 1 end
    print("------------------------------------------------")
    print("[SmartLoad] Target Config: " .. configName)
    print("[SmartLoad] Elements registered in Script: " .. foundCount)

    -- 3. Loop Data
    for id, itemData in pairs(realData) do
        local element = ElementRegistry[id] -- Cari elemen di script kita
        
        if element then
            -- [FIX PENTING] Ambil 'value' dari dalam object JSON WindUI
            -- Struktur JSON kamu: "tognorm": {"value": true, "__type": "Toggle"}
            local finalValue = itemData
            
            if type(itemData) == "table" and itemData.value ~= nil then
                finalValue = itemData.value
            end

            -- Cek Tipe Data (Safety)
            local currentVal = element.Value
            
            -- Cek Perbedaan (Support Table/Array untuk Dropdown)
            local isDifferent = false
            
            if type(finalValue) == "table" then
                -- Jika dropdown/multi-select, kita asumsikan selalu update biar aman
                -- atau bandingkan panjang table (simple check)
                isDifferent = true 
            elseif currentVal ~= finalValue then
                isDifferent = true
            end

            -- Eksekusi Perubahan
            if isDifferent then
                pcall(function() 
                    element:Set(finalValue) 
                end)
                changeCount = changeCount + 1
                
                -- Anti-Freeze: Jeda mikro setiap N perubahan
                if changeCount % CONSTANTS.ConfigUpdateBatchSize == 0 then task.wait() end
            end
        end
    end

    print("[SmartLoad] Done. Total Update: " .. changeCount)
    print("------------------------------------------------")

    WindUI:Notify({ 
        Title = "Config Loaded Successfully", 
        Content = string.format("Updated: %d settings", changeCount), 
        Duration = 3, 
        Icon = "check" 
    })
end

UserInputService = game:GetService("UserInputService")
RunService = game:GetService("RunService")
InfinityJumpConnection = nil
LocalPlayer = game.Players.LocalPlayer
RepStorage = game:GetService("ReplicatedStorage") 
ItemUtility = require(RepStorage:WaitForChild("Shared"):WaitForChild("ItemUtility", 10))
TierUtility = require(RepStorage:WaitForChild("Shared"):WaitForChild("TierUtility", 10))

-- =================================================================
-- FRAME BUDGET SYSTEM (PERFORMANCE OPTIMIZATION)
-- =================================================================
FrameBudgetManager = {
    -- Frame budget allocation (ms per frame)
    MAX_FRAME_TIME = CONSTANTS.FrameBudgetMaxTime,
    
    -- Task queue dengan priority
    taskQueue = {},
    
    -- Active tasks tracking
    activeTasks = {},
    
    -- Frame counter untuk distribusi
    frameCounter = 0,
    
    -- Task execution stats
    stats = {
        totalFrames = 0,
        skippedFrames = 0,
        averageFrameTime = 0,
    }
}

-- Priority levels (higher = more important)
PRIORITY = {
    CRITICAL = 100,   -- Auto fish loops (user action)
    HIGH = 75,        -- Auto sell, equip (important automation)
    MEDIUM = 50,      -- Auto favorite, merchant updates
    LOW = 25,         -- UI updates, stats display
    BACKGROUND = 10,  -- Non-critical monitoring
}

-- Register task dengan priority
function FrameBudgetManager:RegisterTask(id, callback, priority, cooldown)
    cooldown = cooldown or CONSTANTS.FrameBudgetDefaultCooldown
    priority = priority or PRIORITY.MEDIUM
    
    self.taskQueue[id] = {
        callback = callback,
        priority = priority,
        cooldown = cooldown,
        lastExecuted = 0,
        enabled = true,
    }
    
    return id
end

-- Unregister task
function FrameBudgetManager:UnregisterTask(id)
    self.taskQueue[id] = nil
    self.activeTasks[id] = nil
end

-- Enable/Disable task
function FrameBudgetManager:SetTaskEnabled(id, enabled)
    if self.taskQueue[id] then
        self.taskQueue[id].enabled = enabled
    end
end

-- Execute tasks dengan frame budget
function FrameBudgetManager:ProcessFrame()
    local frameStartTime = os.clock()
    self.frameCounter = self.frameCounter + 1
    self.stats.totalFrames = self.stats.totalFrames + 1
    
    -- Sort tasks by priority (higher first)
    local sortedTasks = {}
    for id, task in pairs(self.taskQueue) do
        if task.enabled then
            table.insert(sortedTasks, {id = id, task = task})
        end
    end
    
    table.sort(sortedTasks, function(a, b)
        return a.task.priority > b.task.priority
    end)
    
    -- Execute tasks dalam frame budget
    local elapsedTime = 0
    for _, entry in ipairs(sortedTasks) do
        local id = entry.id
        local task = entry.task
        
        -- Check cooldown
        local currentTime = os.clock()
        if currentTime - task.lastExecuted < task.cooldown then
            continue
        end
        
        -- Check frame budget
        local taskStartTime = os.clock()
        
        -- Execute task dengan pcall untuk safety
        local success, result = pcall(function()
            return task.callback()
        end)
        
        if not success then
            warn("[FrameBudget] Task error (" .. id .. "):", result)
        end
        
        task.lastExecuted = os.clock()
        elapsedTime = elapsedTime + (os.clock() - taskStartTime)
        
        -- Stop jika sudah melebihi budget
        if elapsedTime * 1000 > self.MAX_FRAME_TIME then
            self.stats.skippedFrames = self.stats.skippedFrames + 1
            break
        end
    end
    
    -- Update stats
    local frameTime = (os.clock() - frameStartTime) * 1000
    local smoothing = CONSTANTS.FrameBudgetStatsSmoothing
    self.stats.averageFrameTime = (self.stats.averageFrameTime * smoothing) + (frameTime * (1 - smoothing))
end

-- Start frame budget loop
function FrameBudgetManager:Start()
    if self.connection then
        self.connection:Disconnect()
    end
    
    self.connection = RunService.Heartbeat:Connect(function()
        self:ProcessFrame()
    end)
end

-- Stop frame budget loop
function FrameBudgetManager:Stop()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
end

-- Get performance stats
function FrameBudgetManager:GetStats()
    local activeTaskCount = 0
    for _, task in pairs(self.taskQueue) do
        if task.enabled then
            activeTaskCount = activeTaskCount + 1
        end
    end
    
    return {
        averageFrameTime = self.stats.averageFrameTime,
        totalFrames = self.stats.totalFrames,
        skippedFrames = self.stats.skippedFrames,
        activeTasks = activeTaskCount,
        totalTasks = 0, -- Count total registered tasks
        skipRate = self.stats.totalFrames > 0 and (self.stats.skippedFrames / self.stats.totalFrames * 100) or 0
    }
end

-- Start frame budget system
FrameBudgetManager:Start()

-- Helper function untuk wrap loop ke frame budget
function WrapLoopToBudget(loopId, loopFunction, priority, cooldown, originalState)
    -- Store original state checker
    local stateGetter = originalState or function() return true end
    
    -- Create wrapped callback
    local wrappedCallback = function()
        if stateGetter() then
            return loopFunction()
        end
        return nil
    end
    
    -- Register ke frame budget
    FrameBudgetManager:RegisterTask(loopId, wrappedCallback, priority or PRIORITY.MEDIUM, cooldown)
    
    -- Return control object
    return {
        Enable = function(enabled)
            FrameBudgetManager:SetTaskEnabled(loopId, enabled)
        end,
        Unregister = function()
            FrameBudgetManager:UnregisterTask(loopId)
        end,
        UpdateState = function(newStateGetter)
            stateGetter = newStateGetter
        end
    }
end

print("[HookID] Frame Budget System initialized - Max Frame Time: " .. FrameBudgetManager.MAX_FRAME_TIME .. "ms")

-- =================================================================
-- CONSOLIDATED AUTO EQUIP SYSTEM (OPTIMIZED)
-- =================================================================
-- Menggabungkan semua auto equip loops menjadi satu system untuk mengurangi overhead
ConsolidatedEquipSystem = {
    activeModes = {}, -- Track mode mana yang aktif
    equipCooldown = CONSTANTS.EquipCooldown,
    lastEquipTime = 0,
}

-- Register mode yang memerlukan auto equip
function ConsolidatedEquipSystem:RegisterMode(modeId, stateGetter)
    self.activeModes[modeId] = {
        stateGetter = stateGetter,
        enabled = false,
    }
end

-- Enable/Disable mode
function ConsolidatedEquipSystem:SetModeEnabled(modeId, enabled)
    if self.activeModes[modeId] then
        self.activeModes[modeId].enabled = enabled
    end
end

-- Check if any mode needs equip
function ConsolidatedEquipSystem:ShouldEquip()
    for modeId, mode in pairs(self.activeModes) do
        if mode.enabled and mode.stateGetter() then
            return true
        end
    end
    return false
end

-- Consolidated equip function (registered to frame budget)
local RE_EquipToolFromHotbar = nil -- Will be set later when remotes are loaded

local function ConsolidatedEquipCallback()
    if not RE_EquipToolFromHotbar then return end
    if not ConsolidatedEquipSystem:ShouldEquip() then return end
    
    local currentTime = os.clock()
    if currentTime - ConsolidatedEquipSystem.lastEquipTime < ConsolidatedEquipSystem.equipCooldown then
        return -- Still in cooldown
    end
    
    pcall(function()
        RE_EquipToolFromHotbar:FireServer(1)
    end)
    
    ConsolidatedEquipSystem.lastEquipTime = currentTime
end

-- Register consolidated equip ke frame budget (HIGH priority karena penting untuk prevent stuck)
-- Will be registered after RE_EquipToolFromHotbar is loaded

-- Initialize consolidated equip after remotes are ready (will be called in farm tab)
function InitializeConsolidatedEquip()
    if RE_EquipToolFromHotbar then
    FrameBudgetManager:RegisterTask(
        "consolidatedEquip",
        ConsolidatedEquipCallback,
        PRIORITY.HIGH,
        CONSTANTS.EquipCooldown
    )
        print("[HookID] Consolidated Equip System registered to Frame Budget")
    end
end

local DEFAULT_SPEED = CONSTANTS.DefaultWalkSpeed
local DEFAULT_JUMP = CONSTANTS.DefaultJumpPower

function GetHumanoid()
    local Character = LocalPlayer.Character
    if not Character then
        Character = LocalPlayer.CharacterAdded:Wait()
    end
    return Character:FindFirstChildOfClass("Humanoid")
end

local InitialHumanoid = GetHumanoid()
local currentSpeed = DEFAULT_SPEED
local currentJump = DEFAULT_JUMP

if InitialHumanoid then
    currentSpeed = InitialHumanoid.WalkSpeed
    currentJump = InitialHumanoid.JumpPower
end

RPath = CONSTANTS.RemotePath
PlayerDataReplion = nil

function GetRemote(remotePath, name, timeout)
    local currentInstance = RepStorage
    for _, childName in ipairs(remotePath) do
        currentInstance = currentInstance:WaitForChild(childName, timeout or CONSTANTS.RemoteDefaultTimeout)
        if not currentInstance then return nil end
    end
    return currentInstance:FindFirstChild(name)
end

function GetHRP()
    local Character = game.Players.LocalPlayer.Character
    if not Character then
        Character = game.Players.LocalPlayer.CharacterAdded:Wait()
    end
    return Character:WaitForChild("HumanoidRootPart", 5)
end

pcall(function()
    local player = game:GetService("Players").LocalPlayer
    
    -- Cek semua koneksi yang terhubung ke event Idled pemain lokal
    for i, v in pairs(getconnections(player.Idled)) do
        if v.Disable then
            v:Disable() -- Menonaktifkan koneksi event
            print("[HookID Anti-AFK] ON")
        end
    end
end)

function TeleportToLookAt(position, lookVector)
    local hrp = GetHRP()
    
    if hrp and typeof(position) == "Vector3" and typeof(lookVector) == "Vector3" then
        local targetCFrame = CFrame.new(position, position + lookVector)
        hrp.CFrame = targetCFrame * CFrame.new(0, CONSTANTS.TeleportYOffset, 0)
        
        WindUI:Notify({ Title = "Teleport Sukses!", Duration = 3, Icon = "map-pin", })
    else
        WindUI:Notify({ Title = "Teleport Failed", Content = "Invalid position data.", Duration = 3, Icon = "x", })
    end
end

function GetPlayerDataReplion()
    if PlayerDataReplion then return PlayerDataReplion end
    local ReplionModule = RepStorage:WaitForChild("Packages"):WaitForChild("Replion", CONSTANTS.ReplionPackagesTimeout)
    if not ReplionModule then return nil end
    local ReplionClient = require(ReplionModule).Client
    PlayerDataReplion = ReplionClient:WaitReplion("Data", CONSTANTS.ReplionDataTimeout)
    return PlayerDataReplion
end

RF_SellAllItems = GetRemote(RPath, "RF/SellAllItems", CONSTANTS.ReplionDataTimeout)

function GetFishNameAndRarity(item)
    local name = item.Identifier or "Unknown"
    local rarity = item.Metadata and item.Metadata.Rarity or "COMMON"
    local itemID = item.Id

    local itemData = nil

    if ItemUtility and itemID then
        pcall(function()
            itemData = ItemUtility:GetItemData(itemID)
            if not itemData then
                local numericID = tonumber(item.Id) or tonumber(item.Identifier)
                if numericID then
                    itemData = ItemUtility:GetItemData(numericID)
                end
            end
        end)
    end

    if itemData and itemData.Data and itemData.Data.Name then
        name = itemData.Data.Name
    end

    if item.Metadata and item.Metadata.Rarity then
        rarity = item.Metadata.Rarity
    elseif itemData and itemData.Probability and itemData.Probability.Chance and TierUtility then
        local tierObj = nil
        pcall(function()
            tierObj = TierUtility:GetTierFromRarity(itemData.Probability.Chance)
        end)

        if tierObj and tierObj.Name then
            rarity = tierObj.Name
        end
    end

    return name, rarity
end

function GetItemMutationString(item)
    if item.Metadata and item.Metadata.Shiny == true then return "Shiny" end
    return item.Metadata and item.Metadata.VariantId or ""
end

ShopItems = {
    ["Rods"] = {
        {Name = "Luck Rod", ID = 79, Price = 325}, {Name = "Carbon Rod", ID = 76, Price = 750},
        {Name = "Grass Rod", ID = 85, Price = 1500}, {Name = "Demascus Rod", ID = 77, Price = 3000},
        {Name = "Ice Rod", ID = 78, Price = 5000}, {Name = "Lucky Rod", ID = 4, Price = 15000},
        {Name = "Midnight Rod", ID = 80, Price = 50000}, {Name = "Steampunk Rod", ID = 6, Price = 215000},
        {Name = "Chrome Rod", ID = 7, Price = 437000}, {Name = "Flourescent Rod", ID = 255, Price = 715000},
        {Name = "Astral Rod", ID = 5, Price = 1000000}, {Name = "Ares Rod", ID = 126, Price = 3000000},
        {Name = "Angler Rod", ID = 168, Price = 8000000},{Name = "Bamboo Rod", ID = 258, Price = 12000000}
    },
    ["Bobbers"] = {
        {Name = "Floral Bait", ID = 20, Price = 4000000}, {Name = "Aether Bait", ID = 16, Price = 3700000},
        {Name = "Corrupt Bait", ID = 15, Price = 1148484}, {Name = "Dark Matter Bait", ID = 8, Price = 630000},
        {Name = "Chroma Bait", ID = 6, Price = 290000}, {Name = "Nature Bait", ID = 17, Price = 83500},
        {Name = "Midnight Bait", ID = 3, Price = 3000}, {Name = "Luck Bait", ID = 2, Price = 1000},
        {Name = "Topwater Bait", ID = 10, Price = 100},
    },
    ["Boats"] = {
        {Name = "Mini Yach", ID = 14, Price = 1200000}, {Name = "Fish Boat", ID = 6, Price = 180000},
        {Name = "Speed Boat", ID = 5, Price = 70000}, {Name = "Highfield Boat", ID = 4, Price = 25000},
        {Name = "Jetski", ID = 3, Price = 7500}, {Name = "Kayak", ID = 2, Price = 1100},
        {Name = "Small Boat", ID = 1, Price = 100},
    },
}

do
    local PromptController = nil
    local Promise = nil
    
    pcall(function()
        PromptController = require(RepStorage:WaitForChild("Controllers").PromptController)
        Promise = require(RepStorage:WaitForChild("Packages").Promise)
    end)
    
    _G.HookID_AutoAcceptTradeEnabled = false 

    if PromptController and PromptController.FirePrompt and Promise then
        local oldFirePrompt = PromptController.FirePrompt
        PromptController.FirePrompt = function(self, promptText, ...)
            
            if _G.HookID_AutoAcceptTradeEnabled and type(promptText) == "string" and promptText:find("Accept") and promptText:find("from:") then
                
                local initiatorName = string.match(promptText, "from: ([^\n]+)") or "Seseorang"
                
                
                return Promise.new(function(resolve)
                    task.wait(2)
                    resolve(true)
                end)
            end
            
            return oldFirePrompt(self, promptText, ...)
        end
    else
        warn("[HookID] Failed to load PromptController/Promise for Auto Accept Trade.")
    end
end

ENCHANT_MAPPING = {
    ["Cursed I"] = 12,
    ["Big Hunter I"] = 3,
    ["Empowered I"] = 9,
    ["Glistening I"] = 1,
    ["Gold Digger I"] = 4,
    ["Leprechaun I"] = 5,
    ["Leprechaun II"] = 6,
    ["Mutation Hunter I"] = 7,
    ["Mutation Hunter II"] = 14,
    ["Perfection"] = 15,
    ["Prismatic I"] = 13,
    ["Reeler I"] = 2,
    ["Stargazer I"] = 8,
    ["Stormhunter I"] = 11,
    ["Experienced I"] = 10,
}
ENCHANT_NAMES = {} 
for name, id in pairs(ENCHANT_MAPPING) do table.insert(ENCHANT_NAMES, name) end

-- These will be managed by automatic tab module
-- autoEnchantState = false
-- autoEnchantThread = nil
-- selectedRodUUID = nil
-- selectedEnchantNames = {}

ENCHANT_STONE_ID = CONSTANTS.EnchantStoneID
_G.HookID_EnchantStoneUUIDs = {}

function GetEnchantNameFromId(id)
    id = tonumber(id)
    if not id then return nil end
    for name, eid in pairs(ENCHANT_MAPPING) do
        if eid == id then
            return name
        end
    end
    return nil
end

function GetRodOptions()
    local rodOptions = {}
    local replion = GetPlayerDataReplion()
    if not replion then return {"(Failed to load Inventory)"} end

    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData["Fishing Rods"] then
        return {"(No Rod found)"}
    end

    local Rods = inventoryData["Fishing Rods"]
    for _, rod in ipairs(Rods) do
        local rodUUID = rod.UUID
        
        if typeof(rodUUID) ~= "string" or string.len(rodUUID) < 10 then
            continue
        end
        
        local rodName, _ = GetFishNameAndRarity(rod)
        
        if not string.find(rodName, "Rod", 1, true) then
            continue
        end

        local enchantStatus = ""
        local metadata = rod.Metadata or {}
        local enchants = {}

        if metadata.EnchantId then table.insert(enchants, metadata.EnchantId) end
        --if metadata.EnchantId2 then table.insert(enchants, metadata.EnchantId2) end

        local resolvedEnchantNames = {}
        for _, eid in ipairs(enchants) do
            local name = GetEnchantNameFromId(eid) or "ID:" .. eid
            table.insert(resolvedEnchantNames, name)
        end
        
        if #resolvedEnchantNames > 0 then
            enchantStatus = " [" .. table.concat(resolvedEnchantNames, ", ") .. "]"
        end

        local shortUUID = string.sub(rodUUID, 1, 8) .. "..."
        table.insert(rodOptions, rodName .. " (" .. shortUUID .. ")" .. enchantStatus)
    end
    
    return rodOptions
end


function GetUUIDFromFormattedName(formattedName)
    local uuidMatch = formattedName:match("%(([^%)]+)%.%.%.%)")
    if not uuidMatch then return nil end

    local replion = GetPlayerDataReplion()
    local Rods = replion:GetExpect("Inventory")["Fishing Rods"] or {}

    for _, rod in ipairs(Rods) do
        if string.sub(rod.UUID, 1, 8) == uuidMatch then
            return rod.UUID
        end
    end
    return nil
end

function CheckIfEnchantReached(rodUUID)
    local replion = GetPlayerDataReplion()
    local Rods = replion:GetExpect("Inventory")["Fishing Rods"] or {}
    
    local targetRod = nil
    for _, rod in ipairs(Rods) do
        if rod.UUID == rodUUID then
            targetRod = rod
            break
        end
    end

    if not targetRod then return true end
    
    local metadata = targetRod.Metadata or {}
    local currentEnchants = {}
    if metadata.EnchantId then table.insert(currentEnchants, metadata.EnchantId) end
    --if metadata.EnchantId2 then table.insert(currentEnchants, metadata.EnchantId2) end

    for _, targetName in ipairs(selectedEnchantNames) do
        local targetID = ENCHANT_MAPPING[targetName]
        if targetID and table.find(currentEnchants, targetID) then
            return true
        end
    end

    return false
end

function GetFirstStoneUUID()
    local replion = GetPlayerDataReplion()
    if not replion then return nil end

    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then
        return nil
    end

    local GeneralItems = inventoryData.Items or {}
    for _, item in ipairs(GeneralItems) do
        if tonumber(item.Id) == ENCHANT_STONE_ID and item.UUID and item.Type ~= "Fishing Rods" and item.Type ~= "Bait" then
            return item.UUID
        end
    end
    return nil
end

function UnequipAllEquippedItems()
    local RE_UnequipItem = GetRemote(RPath, "RE/UnequipItem")
    if not RE_UnequipItem then 
        warn("[Auto Enchant] Failed to find RE/UnequipItem remote.")
        return 
    end

    local replion = GetPlayerDataReplion()
    local EquippedItems = replion:GetExpect("EquippedItems") or {}
    local EquippedSkinUUID = replion:Get("EquippedSkinUUID")

    if EquippedSkinUUID and EquippedSkinUUID ~= "" then
         -- Unequip Rod Skin
         pcall(function() RE_UnequipItem:FireServer(EquippedSkinUUID) end)
         task.wait(0.1)
    end

    for _, uuid in ipairs(EquippedItems) do
        pcall(function() RE_UnequipItem:FireServer(uuid) end)
        task.wait(0.05)
    end
end

ARTIFACT_IDS = {
    ["Arrow Artifact"] = 265,
    ["Crescent Artifact"] = 266,
    ["Diamond Artifact"] = 267,
    ["Hourglass Diamond Artifact"] = 271
}

-- Helper: Cek Item di Backpack pakai Hardcoded ID
function HasArtifactItem(artifactName)
    local replion = GetPlayerDataReplion()
    if not replion then return false end
    
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return false end

    -- Ambil Target ID dari tabel Hardcode
    local targetId = ARTIFACT_IDS[artifactName]
    
    if not targetId then 
        warn("[HookID] ID for " .. artifactName .. " not found in hardcode table!")
        return false 
    end

    -- Loop inventory, cari angka ID yang cocok
    for _, item in ipairs(inventoryData.Items) do
        -- Pastikan item.Id dibaca sebagai angka
        if tonumber(item.Id) == targetId then 
            return true 
        end
    end
    
    return false
end


function RunAutoEnchantLoop(rodUUID)
    if autoEnchantThread then 
        ThreadManager:Cancel("autoEnchantThread", false)
        autoEnchantThread = nil
    end
    
    local ENCHANT_ALTAR_POS = CONSTANTS.EnchantAltarPos
    local ENCHANT_ALTAR_LOOK = CONSTANTS.EnchantAltarLook
    
    local RE_UnequipItem = GetRemote(RPath, "RE/UnequipItem")
    local RE_EquipItem = GetRemote(RPath, "RE/EquipItem")
    local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")
    local RE_ActivateEnchantingAltar = GetRemote(RPath, "RE/ActivateEnchantingAltar")

    if not (RE_UnequipItem and RE_EquipItem and RE_EquipToolFromHotbar and RE_ActivateEnchantingAltar) then
        WindUI:Notify({ Title = "Error Remote", Content = "Remote Enchanting not found.", Duration = 4, Icon = "x" })
        autoEnchantState = false
        return
    end

    autoEnchantThread = SafeSpawnThread("autoEnchantThread", function()
        
        UnequipAllEquippedItems()

        task.wait(CONSTANTS.EnchantSetupWait) 

        TeleportToLookAt(ENCHANT_ALTAR_POS, ENCHANT_ALTAR_LOOK)
        task.wait(CONSTANTS.EnchantTeleportWait)

        WindUI:Notify({ Title = "Auto Enchant Started", Content = "Starting Enchant Roll...", Duration = 2, Icon = "zap" })

        while autoEnchantState do
            
            if CheckIfEnchantReached(rodUUID) then
                WindUI:Notify({ Title = "Enchant Completed!", Content = "Rod reached one of the target enchant.", Duration = 5, Icon = "check" })
                break
            end
            
            local enchantStoneUUID = GetFirstStoneUUID() 
            if not enchantStoneUUID then
                WindUI:Notify({ Title = "Stone Habis!", Content = "No Enchant Stone left in inventory.", Duration = 5, Icon = "stop-circle" })
                break
            end

            pcall(function() RE_EquipItem:FireServer(rodUUID, "Fishing Rods") end)
            task.wait(CONSTANTS.EnchantEquipDelay)

            pcall(function() RE_EquipItem:FireServer(enchantStoneUUID, "Enchant Stones") end)
            task.wait(CONSTANTS.EnchantEquipDelay)
            
            pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
            task.wait(CONSTANTS.EnchantToolDelay)

            pcall(function() RE_ActivateEnchantingAltar:FireServer() end)
            
            task.wait(CONSTANTS.AutoTradeDelay) 

            pcall(function() RE_EquipToolFromHotbar:FireServer(0) end) 
            
            task.wait(CONSTANTS.EnchantUnequipDelay)
        end

        autoEnchantState = false
        local toggle = Window:GetElementByTitle("Enable Auto Enchant") 
        if toggle and toggle.Set then toggle:Set(false) end
        
        WindUI:Notify({ Title = "Auto Enchant Stopped", Duration = 3, Icon = "x" })
    end)
end

eventsList = { 
    "Shark Hunt", "Ghost Shark Hunt", "Worm Hunt", "Admin Event", "Black Hole", "Shocked", 
    "Ghost Worm", "Meteor Rain", "Megalodon Hunt", "Treasure Event"
}

-- These will be managed by teleport tab module
-- autoEventTargetName = nil 
-- autoEventTeleportState = false
-- autoEventTeleportThread = nil


function FindAndTeleportToTargetEvent()
    local targetName = autoEventTargetName
    if not targetName or targetName == "" then return false end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local eventModel = nil

    -- =========================
    -- FIND EVENT MODEL
    -- =========================
    if targetName == "Treasure Event" then
        local sunken = workspace:FindFirstChild("Sunken Wreckage")
        if sunken then
            eventModel = sunken:FindFirstChild("Treasure")
        end

    elseif targetName == "Megalodon Hunt" 
        or targetName == "Shark Hunt"
        or targetName == "Ghost Shark Hunt" then

        for _, v in ipairs(workspace:GetChildren()) do
            if v.Name == "Props" then
                local found = v:FindFirstChild(targetName)
                if found then
                    eventModel = found
                    break
                end
            end
        end

    elseif targetName == "Worm Hunt" then
        for _, v in ipairs(workspace:GetChildren()) do
            local model = v:FindFirstChild("Model")
            if model then
                local bh = model:FindFirstChild("BlackHole")
                if bh then
                    eventModel = bh
                    break
                end
            end
        end

    elseif targetName == "Admin Event" or targetName == "Black Hole" then
        for _, v in ipairs(workspace:GetChildren()) do
            if v.Name == "Props" then
                local bh = v:FindFirstChild("Black Hole")
                if bh then
                    eventModel = bh
                    break
                end
            end
        end

    else
        local rings = workspace:FindFirstChild("!!! MENU RINGS")
        if rings then
            for _, c in ipairs(rings:GetChildren()) do
                if c:FindFirstChild(targetName) then
                    eventModel = c:FindFirstChild(targetName)
                    break
                end
            end
        end
    end

    if not eventModel then return false end

    -- =========================
    -- TARGET PART
    -- =========================
    local targetPart
    local offset = Vector3.new(0, 10, 0)

    if targetName == "Megalodon Hunt" then
        local top = eventModel:FindFirstChild("Top")
        targetPart = top or eventModel
        offset = Vector3.new(0,3,0)

    elseif targetName == "Worm Hunt" then
        targetPart = eventModel.PrimaryPart or eventModel:FindFirstChildWhichIsA("BasePart")
        offset = Vector3.new(0,5,0)

    elseif targetName == "Shark Hunt" or targetName == "Ghost Shark Hunt" then
        targetPart = eventModel:FindFirstChild("Fishing Boat") or eventModel
        offset = Vector3.new(0,5,0)

    elseif targetName == "Treasure Event" then
        targetPart = eventModel
        offset = Vector3.new(0,5,0)

    else
        targetPart = eventModel:FindFirstChild("Fishing Boat") or eventModel
    end

    if not targetPart then return false end

    -- =========================
    -- TELEPORT
    -- =========================
    local cf
    if targetPart:IsA("Model") then
        cf = targetPart:GetPivot()
    else
        cf = targetPart.CFrame
    end

    TeleportToLookAt(cf.Position + offset, cf.LookVector)

    if WindUI then
        WindUI:Notify({
            Title = "Event Found!",
            Content = "Teleported to: " .. targetName,
            Icon = "map-pin",
            Duration = 3
        })
    end

    return true
end


function RunAutoEventTeleportLoop()
    if autoEventTeleportThread then 
        ThreadManager:Cancel("autoEventTeleportThread", false)
        autoEventTeleportThread = nil
    end

    autoEventTeleportThread = SafeSpawnThread("autoEventTeleportThread", function()
        WindUI:Notify({ Title = "Auto Event TP ON", Content = "Starting to scan selected event.", Duration = 3, Icon = "search" })
        
        while autoEventTeleportState do
            
            if FindAndTeleportToTargetEvent() then
                
                task.wait(900) 
            else
                
                task.wait(10)
            end
        end
        
        ThreadManager:Unregister("autoEventTeleportThread")
        WindUI:Notify({ Title = "Auto Event TP Disabled", Duration = 3, Icon = "x" })
    end, "Auto Event Teleport Loop")
end

function CensorName(name)
    if not name or type(name) ~= "string" or #name < 1 then
        return "N/A (Not Available)" 
    end
    
    if #name <= 3 then
        return name
    end

    local prefix = name:sub(1, 3)
    
    local censureLength = #name - 3
    
    local censorString = string.rep("*", censureLength)
    
    return prefix .. censorString
end

FishingAreas = {
        ["Christmas Island"] = {Pos = Vector3.new(1138.058, 32.129, 1595.619), Look = Vector3.new(0.050, -0.220, -0.974)},
        ["Ancient Jungle"] = {Pos = Vector3.new(1535.639, 3.159, -193.352), Look = Vector3.new(0.505, -0.000, 0.863)},
        ["Arrow Lever"] = {Pos = Vector3.new(898.296, 8.449, -361.856), Look = Vector3.new(0.023, -0.000, 1.000)},
        ["Coral Reef"] = {Pos = Vector3.new(-3207.538, 6.087, 2011.079), Look = Vector3.new(0.973, 0.000, 0.229)},
        ["Crater Island"] = {Pos = Vector3.new(1058.976, 2.330, 5032.878), Look = Vector3.new(-0.789, 0.000, 0.615)},
        ["Cresent Lever"] = {Pos = Vector3.new(1419.750, 31.199, 78.570), Look = Vector3.new(0.000, -0.000, -1.000)},
        ["Crystalline Passage"] = {Pos = Vector3.new(6051.567, -538.900, 4370.979), Look = Vector3.new(0.109, 0.000, 0.994)},
        ["Ancient Ruin"] = {Pos = Vector3.new(6031.981, -585.924, 4713.157), Look = Vector3.new(0.316, -0.000, -0.949)},
        ["Diamond Lever"] = {Pos = Vector3.new(1818.930, 8.449, -284.110), Look = Vector3.new(0.000, 0.000, -1.000)},
        ["Enchant Room"] = {Pos = Vector3.new(3255.670, -1301.530, 1371.790), Look = Vector3.new(-0.000, -0.000, -1.000)},
        ["Esoteric Island"] = {Pos = Vector3.new(2164.470, 3.220, 1242.390), Look = Vector3.new(-0.000, -0.000, -1.000)},
        ["Fisherman Island"] = {Pos = Vector3.new(74.030, 9.530, 2705.230), Look = Vector3.new(-0.000, -0.000, -1.000)},
        ["Hourglass Diamond Lever"] = {Pos = Vector3.new(1484.610, 8.450, -861.010), Look = Vector3.new(-0.000, -0.000, -1.000)},
        ["Kohana"] = {Pos = Vector3.new(-668.732, 3.000, 681.580), Look = Vector3.new(0.889, -0.000, 0.458)},
        ["Lost Isle"] = {Pos = Vector3.new(-3804.105, 2.344, -904.653), Look = Vector3.new(-0.901, -0.000, 0.433)},
        ["Sacred Temple"] = {Pos = Vector3.new(1461.815, -22.125, -670.234), Look = Vector3.new(-0.990, -0.000, 0.143)},
        ["Second Enchant Altar"] = {Pos = Vector3.new(1479.587, 128.295, -604.224), Look = Vector3.new(-0.298, 0.000, -0.955)},
        ["Sisyphus Statue"] = {Pos = Vector3.new(-3743.745, -135.074, -1007.554), Look = Vector3.new(0.310, 0.000, 0.951)},
        ["Treasure Room"] = {Pos = Vector3.new(-3598.440, -281.274, -1645.855), Look = Vector3.new(-0.065, 0.000, -0.998)},
        ["Tropical Island"] = {Pos = Vector3.new(-2162.920, 2.825, 3638.445), Look = Vector3.new(0.381, -0.000, 0.925)},
        ["Underground Cellar"] = {Pos = Vector3.new(2118.417, -91.448, -733.800), Look = Vector3.new(0.854, 0.000, 0.521)},
        ["Volcano"] = {Pos = Vector3.new(-605.121, 19.516, 160.010), Look = Vector3.new(0.854, 0.000, 0.520)},
        ["Weather Machine"] = {Pos = Vector3.new(-1518.550, 2.875, 1916.148), Look = Vector3.new(0.042, 0.000, 0.999)},
    }
    AreaNames = {}
    for name, _ in pairs(FishingAreas) do
        table.insert(AreaNames, name)
    end

-- =================================================================
-- EVENT GUI HELPER
-- =================================================================
function GetEventGUI()
    local success, gui = pcall(function()
        local menuRings = workspace:WaitForChild("!!! MENU RINGS", 5)
        local eventTracker = workspace:WaitForChild("!!! DEPENDENCIES"):WaitForChild("Event Tracker", 5)
        local contentItems = eventTracker.Main.Gui.Content.Items

        local countdown = contentItems.Countdown:WaitForChild("Label")	
        local statsContainer = contentItems:WaitForChild("Stats")	
        local timer = statsContainer.Timer:WaitForChild("Label")	
        
        local quantity = statsContainer:WaitForChild("Quantity")	
        local odds = statsContainer:WaitForChild("Odds")

        return {
            Countdown = countdown,
            Timer = timer,
            Quantity = quantity,
            Odds = odds,
        }
    end)
    
    if success and gui then
        return gui
    else
        return nil
    end
end

















