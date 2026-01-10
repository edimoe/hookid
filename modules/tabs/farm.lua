do
    local farm = Window:Tab({
        Icon = "fish",
        Title = "",
        Locked = false,
    })

    -----------------------------------------------------------------
    -- ￰ﾟﾚﾩ VARIABEL GLOBAL UNTUK TAB FARM
    -----------------------------------------------------------------
    -- Variabel Auto Fishing
    local legitAutoState = false
    local normalInstantState = false
    local blatantInstantState = false
    
    -- Thread Utama
    local normalLoopThread = nil
    local blatantLoopThread = nil
    
    -- Thread Khusus Auto Equip (Anti-Stuck)
    local normalEquipThread = nil
    local blatantEquipThread = nil
    local legitEquipThread = nil -- Thread baru untuk Legit

    local NormalInstantSlider = nil

    -- Variabel Fishing Area
    local isTeleportFreezeActive = false
    local freezeToggle = nil
    local selectedArea = nil
    
    local savedPosition = nil -- Menyimpan {Pos = Vector3, Look = Vector3}

    -----------------------------------------------------------------
    -- ￰ﾟﾛﾠ￯ﾸﾏ FUNGSI HELPER
    -----------------------------------------------------------------
    
    local function GetHRP()
        local Character = game.Players.LocalPlayer.Character
        if not Character then
            Character = game.Players.LocalPlayer.CharacterAdded:Wait()
        end
        return Character:WaitForChild("HumanoidRootPart", 5)
    end
    
    local function TeleportToLookAt(position, lookVector)
        local hrp = GetHRP()
        
        if hrp and typeof(position) == "Vector3" and typeof(lookVector) == "Vector3" then
            local targetCFrame = CFrame.new(position, position + lookVector)
            hrp.CFrame = targetCFrame * CFrame.new(0, 0.5, 0)
            
            WindUI:Notify({ Title = "Teleport Sukses!", Duration = 3, Icon = "map-pin", })
        else
            WindUI:Notify({ Title = "Teleport Gagal", Duration = 3, Icon = "x", })
        end
    end
    
    local RPath = {"Packages", "_Index", "sleitnick_net@0.2.0", "net"}
    local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")
    local RF_ChargeFishingRod = GetRemote(RPath, "RF/ChargeFishingRod")
    local RF_RequestFishingMinigameStarted = GetRemote(RPath, "RF/RequestFishingMinigameStarted")
    local RE_FishingCompleted = GetRemote(RPath, "RE/FishingCompleted")
    local RF_CancelFishingInputs = GetRemote(RPath, "RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = GetRemote(RPath, "RF/UpdateAutoFishingState")

    local function checkFishingRemotes(silent)
        local remotes = { RE_EquipToolFromHotbar, RF_ChargeFishingRod, RF_RequestFishingMinigameStarted,
                          RE_FishingCompleted, RF_CancelFishingInputs, RF_UpdateAutoFishingState }
        for _, remote in ipairs(remotes) do
            if not remote then
                if not silent then
                    WindUI:Notify({ Title = "Remote Error!", Content = "Remote Fishing tidak ditemukan! Cek jalur RPath.", Duration = 5, Icon = "x", })
                end
                return false
            end
        end
        return true
    end

    local function disableOtherModes(currentMode)
        pcall(function()
            -- Find Toggles based on titles
            local toggleLegit = farm:GetElementByTitle("Auto Fish (Legit)")
            local toggleNormal = farm:GetElementByTitle("Normal Instant Fish")
            local toggleBlatant = farm:GetElementByTitle("Instant Fishing (Blatant)")

            if currentMode ~= "legit" and legitAutoState then 
                legitAutoState = false
                if toggleLegit and toggleLegit.Set then toggleLegit:Set(false) end
                if legitClickThread then 
                    ThreadManager:Cancel("legitClickThread", false)
                    legitClickThread = nil
                end
                if legitEquipThread then 
                    ThreadManager:Cancel("legitEquipThread", false)
                    legitEquipThread = nil
                end
            end
            if currentMode ~= "normal" and normalInstantState then 
                normalInstantState = false
                if toggleNormal and toggleNormal.Set then toggleNormal:Set(false) end
                if normalLoopThread then 
                    ThreadManager:Cancel("normalLoopThread", false)
                    normalLoopThread = nil
                end
                if normalEquipThread then 
                    ThreadManager:Cancel("normalEquipThread", false)
                    normalEquipThread = nil
                end
            end
            if currentMode ~= "blatant" and blatantInstantState then 
                blatantInstantState = false
                if toggleBlatant and toggleBlatant.Set then toggleBlatant:Set(false) end
                if blatantLoopThread then 
                    ThreadManager:Cancel("blatantLoopThread", false)
                    blatantLoopThread = nil
                end
                if blatantEquipThread then 
                    ThreadManager:Cancel("blatantEquipThread", false)
                    blatantEquipThread = nil
                end
            end
        end)
        
        -- Reset server-side auto fishing state if moving away from Legit mode
        if currentMode ~= "legit" then
            pcall(function() if RF_UpdateAutoFishingState then RF_UpdateAutoFishingState:InvokeServer(false) end end)
        end
    end
    
    -- ===================================================================
    -- LOGIKA BARU UNTUK AUTO FISH LEGIT
    -- ===================================================================

    local FishingController = require(RepStorage:WaitForChild("Controllers").FishingController)
    local AutoFishingController = require(RepStorage:WaitForChild("Controllers").AutoFishingController)

    local AutoFishState = {
        IsActive = false,
        MinigameActive = false
    }

    local SPEED_LEGIT = CONSTANTS.SpeedLegitDefault
    local legitClickThread = nil

    local function performClick()
        if FishingController then
            FishingController:RequestFishingMinigameClick()
            task.wait(SPEED_LEGIT)
        end
    end
    
    -- Hook FishingRodStarted (Minigame Aktif)
    local originalRodStarted = FishingController.FishingRodStarted
    FishingController.FishingRodStarted = function(self, arg1, arg2)
        originalRodStarted(self, arg1, arg2)

        if AutoFishState.IsActive and not AutoFishState.MinigameActive then
            AutoFishState.MinigameActive = true

            if legitClickThread then
                task.cancel(legitClickThread)
            end

            legitClickThread = task.spawn(function()
                while AutoFishState.IsActive and AutoFishState.MinigameActive do
                    performClick()
                end
            end)
        end
    end

    -- Hook FishingStopped
    local originalFishingStopped = FishingController.FishingStopped
    FishingController.FishingStopped = function(self, arg1)
        originalFishingStopped(self, arg1)

        if AutoFishState.MinigameActive then
            AutoFishState.MinigameActive = false
        end
    end

    local function ensureServerAutoFishingOn()
        local replionClient = require(RepStorage:WaitForChild("Packages").Replion).Client
        local replionData = replionClient:WaitReplion("Data", 5)

        local remoteFunctionName = "RF/UpdateAutoFishingState"
        local UpdateAutoFishingRemote = GetRemote(RPath, remoteFunctionName)

        if UpdateAutoFishingRemote then
            pcall(function()
                UpdateAutoFishingRemote:InvokeServer(true)
            end)
        end
    end
    
    local function ToggleAutoClick(shouldActivate)
        if not FishingController or not AutoFishingController then
            WindUI:Notify({ Title = "Error", Content = "Gagal memuat Fishing Controllers.", Duration = 4, Icon = "x" })
            return
        end
        
        AutoFishState.IsActive = shouldActivate

        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local fishingGui = playerGui:FindFirstChild("Fishing") and playerGui.Fishing:FindFirstChild("Main")
        local chargeGui = playerGui:FindFirstChild("Charge") and playerGui.Charge:FindFirstChild("Main")


        if shouldActivate then
            -- 1. Equip Rod Awal
            pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
            
            -- 2. Force Server AutoFishing State
            ensureServerAutoFishingOn()
            
            -- 3. Sembunyikan UI Minigame
            if fishingGui then fishingGui.Visible = false end
            if chargeGui then chargeGui.Visible = false end

            WindUI:Notify({ Title = "Auto Fish Legit ON!", Content = "Auto-Equip Protection Active.", Duration = 3, Icon = "check" })

        else
            if legitClickThread then
                task.cancel(legitClickThread)
                legitClickThread = nil
            end
            AutoFishState.MinigameActive = false
            
            -- 4. Tampilkan kembali UI Minigame
            if fishingGui then fishingGui.Visible = true end
            if chargeGui then chargeGui.Visible = true end

            WindUI:Notify({ Title = "Auto Fish Legit OFF!", Duration = 3, Icon = "x" })
        end
    end

    -- =================================================================
    -- ￰ﾟﾎﾣ AUTO FISHING SECTION UI
    -- =================================================================
    local autofish = farm:Section({
        Title = "Auto Fishing",
        TextSize = 20,
        FontWeight = Enum.FontWeight.SemiBold,
    })

    -- 1. TOGGLE AUTO FISH (LEGIT - UPDATED)
    local slidlegit = Reg("klikd",autofish:Slider({
        Title = "Legit Click Speed (Delay)",
        Step = 0.01,
        Value = { Min = CONSTANTS.SpeedLegitMin, Max = CONSTANTS.SpeedLegitMax, Default = SPEED_LEGIT },
        Callback = function(value)
            local newSpeed = tonumber(value)
            if newSpeed and newSpeed >= CONSTANTS.SpeedLegitMin then
                SPEED_LEGIT = newSpeed
            end
        end
    }))

    local toglegit = Reg("legit",autofish:Toggle({
        Title = "Auto Fish (Legit)",
        Value = false,
        Callback = function(state)
            if not checkFishingRemotes() then return false end
            disableOtherModes("legit")
            legitAutoState = state
            ToggleAutoClick(state)

            -- [THREAD BARU] AUTO EQUIP BACKGROUND - LEGIT MODE
            if state then
                if legitEquipThread then task.cancel(legitEquipThread) end
                legitEquipThread = task.spawn(function()
                    while legitAutoState do
                        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                        task.wait(0.1) -- Delay spam 0.1 detik
                    end
                end)
            else
                if legitEquipThread then task.cancel(legitEquipThread) legitEquipThread = nil end
            end
        end
    }))

    farm:Divider()
    
    -- Variabel & Slider Delay
    local normalCompleteDelay = CONSTANTS.NormalCompleteDelayDefault

    NormalInstantSlider = Reg("normalslid",autofish:Slider({
        Title = "Normal Complete Delay",
        Step = 0.05,
        Value = { Min = CONSTANTS.NormalCompleteDelayMin, Max = CONSTANTS.NormalCompleteDelayMax, Default = normalCompleteDelay },
        Callback = function(value) normalCompleteDelay = tonumber(value) end
    }))

    -- Fungsi Utama Mancing (Looping Action)
    local function runNormalInstant()
        if not normalInstantState then return end
        if not checkFishingRemotes(true) then normalInstantState = false return end
        
        local timestamp = os.time() + os.clock()
        pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
        pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.630452165, 0.99647927980797) end)
        
        task.wait(normalCompleteDelay)
        
        pcall(function() RE_FishingCompleted:FireServer() end)
        task.wait(0.3)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    end

    local normalins = Reg("tognorm",autofish:Toggle({
        Title = "Normal Instant Fish",
        Value = false,
        Callback = function(state)
            if not checkFishingRemotes() then return end
            disableOtherModes("normal")
            normalInstantState = state
            
            if state then
                -- THREAD 1: Logic Mancing Utama
                normalLoopThread = SafeSpawnThread("normalLoopThread", function()
                    while normalInstantState do
                        runNormalInstant()
                        task.wait(CONSTANTS.NormalFishingDelay) 
                    end
                    ThreadManager:Unregister("normalLoopThread")
                end, "Normal Instant Fish Loop")

                -- THREAD 2: Background Auto Equip (Anti-Stuck)
                if normalEquipThread then task.cancel(normalEquipThread) end
                normalEquipThread = task.spawn(function()
                    while normalInstantState do
                        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                        task.wait(0.1) -- Delay spam 0.1 detik
                    end
                end)
                
                WindUI:Notify({ Title = "Auto Fish ON", Content = "Auto-Equip Protection Active.", Duration = 3, Icon = "fish" })
            else
                -- Matikan kedua thread saat toggle OFF
                if normalLoopThread then task.cancel(normalLoopThread) normalLoopThread = nil end
                if normalEquipThread then task.cancel(normalEquipThread) normalEquipThread = nil end
                
                pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
                WindUI:Notify({ Title = "Auto Fish OFF", Duration = 3, Icon = "x" })
            end
        end
    }))

    -- =============================
    -- BLATANT SMART THROTTLE
    -- =============================
    local BLATANT_THROTTLE = 0.14  -- Delay aman untuk menurunkan recv
    local lastBlatantAction = 0
    
    local function CanBlatant()
        local now = os.clock()
        if now - lastBlatantAction >= BLATANT_THROTTLE then
            lastBlatantAction = now
            return true
        end
        return false
    end

    -- 3. INSTANT FISHING (BLATANT) - V5 (PERFECTION + GHOST UI)
    local blatant = farm:Section({ Title = "Blatant Mode", TextSize = 20, })

    local completeDelay = CONSTANTS.BlatantCompleteDelay
    local cancelDelay = CONSTANTS.BlatantCancelDelay
    local loopInterval = CONSTANTS.BlatantLoopInterval
    local maxRetries = CONSTANTS.BlatantMaxRetries
    local retryDelay = CONSTANTS.BlatantRetryDelay
    
    _G.HookID_BlatantActive = false
    _G.BlatantLastCatchTime = 0  -- Track last successful catch

    -- [[ 1. LOGIC KILLER: LUMPUHKAN CONTROLLER ]]
    task.spawn(function()
        local S1, FishingController = pcall(function() return require(game:GetService("ReplicatedStorage").Controllers.FishingController) end)
        if S1 and FishingController then
            local Old_Charge = FishingController.RequestChargeFishingRod
            local Old_Cast = FishingController.SendFishingRequestToServer
            
            -- Matikan fungsi charge & cast game asli saat Blatant ON
            FishingController.RequestChargeFishingRod = function(...)
                if _G.HookID_BlatantActive then return end 
                return Old_Charge(...)
            end
            FishingController.SendFishingRequestToServer = function(...)
                if _G.HookID_BlatantActive then return false, "Blocked by HookID" end
                return Old_Cast(...)
            end
        end
    end)

    -- [[ 2. REMOTE KILLER: BLOKIR KOMUNIKASI ]]
    local mt = getrawmetatable(game)
    local old_namecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if _G.HookID_BlatantActive and not checkcaller() then
            -- Cegah game mengirim request mancing atau request update state
            if method == "InvokeServer" and (self.Name == "RequestFishingMinigameStarted" or self.Name == "ChargeFishingRod" or self.Name == "UpdateAutoFishingState") then
                return nil 
            end
            if method == "FireServer" and self.Name == "FishingCompleted" then
                return nil
            end
        end
        return old_namecall(self, ...)
    end)
    setreadonly(mt, true)

    -- [[ 3. UI & NOTIF KILLER (VISUAL SPOOFING) ]]
    -- Ini yang bikin UI tetep kelihatan mati padahal server taunya idup
    local function SuppressGameVisuals(active)
        -- A. Hook Notifikasi biar ga spam "Auto Fishing: Enabled"
        local Succ, TextController = pcall(function() return require(game.ReplicatedStorage.Controllers.TextNotificationController) end)
        if Succ and TextController then
            if active then
                if not TextController._OldDeliver then 
                    TextController._OldDeliver = TextController.DeliverNotification 
                end
                TextController.DeliverNotification = function(self, data)
                    -- Filter pesan Auto Fishing
                    if data and data.Text and (string.find(tostring(data.Text), "Auto Fishing") or string.find(tostring(data.Text), "Reach Level")) then
                        return 
                    end
                    -- Safety check: ensure _OldDeliver exists before calling
                    if TextController._OldDeliver then
                        return TextController._OldDeliver(self, data)
                    else
                        -- Fallback: if _OldDeliver is nil, just return (don't call original)
                        return
                    end
                end
            elseif TextController._OldDeliver then
                TextController.DeliverNotification = TextController._OldDeliver
                TextController._OldDeliver = nil
            end
        end

        -- B. Paksa Tombol Jadi Merah (Inactive) Setiap Frame
        if active then
            task.spawn(function()
                local RunService = game:GetService("RunService")
                local CollectionService = game:GetService("CollectionService")
                local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
                
                -- Warna Merah (Inactive) dari kode game yang kamu kasih
                local InactiveColor = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHex("ff5d60")), 
                    ColorSequenceKeypoint.new(1, Color3.fromHex("ff2256"))
                })

                while _G.HookID_BlatantActive do
                    -- Cari tombol Auto Fishing (Bisa di Backpack atau tagged)
                    local targets = {}
                    
                    -- Cek Tag (Cara paling akurat sesuai script game)
                    for _, btn in ipairs(CollectionService:GetTagged("AutoFishingButton")) do
                        table.insert(targets, btn)
                    end
                    
                    -- Fallback cek path manual
                    if #targets == 0 then
                        local btn = PlayerGui:FindFirstChild("Backpack") and PlayerGui.Backpack:FindFirstChild("AutoFishingButton")
                        if btn then table.insert(targets, btn) end
                    end

                    -- Paksa Gradientnya jadi Merah
                    for _, btn in ipairs(targets) do
                        local grad = btn:FindFirstChild("UIGradient")
                        if grad then
                            grad.Color = InactiveColor -- Timpa animasi spr game
                        end
                    end
                    
                    RunService.RenderStepped:Wait()
                end
            end)
        end
    end

    -- [[ UI CONFIG ]]
    local LoopIntervalInput = Reg("blatantint", blatant:Input({
        Title = "Blatant Speed", Value = tostring(loopInterval), Icon = "fast-forward", Type = "Input", Placeholder = "1.58",
        Callback = function(input)
            local newInterval = tonumber(input)
            if newInterval and newInterval >= 0.4 then loopInterval = newInterval end  -- OPTIMASI: Minimal 0.4 (dari 0.5)
        end
    }))

    local CompleteDelayInput = Reg("blatantcom", blatant:Input({
        Title = "Complete Delay", Value = tostring(completeDelay), Icon = "loader", Type = "Input", Placeholder = "2.75",
        Callback = function(input)
            local newDelay = tonumber(input)
            if newDelay and newDelay >= 0.3 then completeDelay = newDelay end  -- OPTIMASI: Minimal 0.3 (dari 0.5)
        end
    }))

    local CancelDelayInput = Reg("blatantcanc",blatant:Input({
        Title = "Cancel Delay", Value = tostring(cancelDelay), Icon = "clock", Type = "Input", Placeholder = "0.3", Flag = "canlay",
        Callback = function(input)
            local newDelay = tonumber(input)
            if newDelay and newDelay >= 0.05 then cancelDelay = newDelay end  -- OPTIMASI: Minimal 0.05 (dari 0.1)
        end
    }))

    local function runBlatantInstant()
        if not blatantInstantState then return end
        if not checkFishingRemotes(true) then blatantInstantState = false return end

        task.spawn(function()
            local startTime = os.clock()
            local timestamp = os.time() + os.clock()
            local success = false
            local attempts = 0
            
            -- OPTIMASI: Koordinat yang lebih akurat (dari normal instant yang lebih stabil)
            local minigameX = -139.630452165
            local minigameY = 0.99647927980797
            
            -- Retry loop untuk no miss
            while attempts <= maxRetries and not success do
                attempts = attempts + 1
                
                -- 1. Charge rod dengan timestamp presisi
                local chargeSuccess = pcall(function() 
                    RF_ChargeFishingRod:InvokeServer(timestamp) 
                end)
                
                if not chargeSuccess then
                    task.wait(0.1)
                    continue
                end
                
                -- OPTIMASI: Kurangi delay antara charge dan cast (dari 0.001 ke 0.0005)
                task.wait(0.0005)
                
                -- 2. Start minigame dengan koordinat optimal
                local castSuccess = pcall(function() 
                    RF_RequestFishingMinigameStarted:InvokeServer(minigameX, minigameY) 
                end)
                
                if not castSuccess then
                    task.wait(retryDelay)
                    continue
                end
                
                -- 3. Calculate precise wait time
                local elapsed = os.clock() - startTime
                local completeWaitTime = completeDelay - elapsed
                
                -- OPTIMASI: Pastikan wait time tidak negatif dan cukup
                if completeWaitTime > 0.1 then
                    task.wait(completeWaitTime)
                else
                    task.wait(0.1)  -- Minimum safety delay
                end
                
                -- 4. Complete fishing
                local completeSuccess = pcall(function() 
                    RE_FishingCompleted:FireServer() 
                end)
                
                if completeSuccess then
                    success = true
                    _G.BlatantLastCatchTime = os.clock()
                else
                    -- Retry jika complete gagal
                    task.wait(retryDelay)
                    continue
                end
                
                -- 5. Cancel inputs (non-blocking)
                task.wait(cancelDelay)
                pcall(function() RF_CancelFishingInputs:InvokeServer() end)
            end
            
            -- Log jika semua retry gagal (untuk debugging)
            if not success and attempts > maxRetries then
                warn("[Blatant] Failed after " .. attempts .. " attempts")
            end
        end)
    end

    local togblat = Reg("blatantt",blatant:Toggle({
        Title = "Instant Fishing (Blatant)",
        Value = false,
        Callback = function(state)
            if not checkFishingRemotes() then return end
            disableOtherModes("blatant")
            blatantInstantState = state
            _G.HookID_BlatantActive = state
            
            -- Jalankan Visual Killer
            SuppressGameVisuals(state)
            
            if state then
                -- OPTIMASI: Server State ON (lebih efisien - hanya 2x dengan delay lebih pendek)
                if RF_UpdateAutoFishingState then
                    pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end)
                    task.wait(0.2)  -- Kurangi dari 0.5 ke 0.2
                    pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end)
                end

                -- OPTIMASI: Pre-validate remotes sebelum loop
                if not checkFishingRemotes(true) then
                    WindUI:Notify({ Title = "Error", Content = "Fishing remotes not ready!", Duration = 3, Icon = "x" })
                    blatantInstantState = false
                    _G.HookID_BlatantActive = false
                    return
                end

                -- 2. Loop Kita (OPTIMASI: Kurangi overhead dengan pre-check)
                blatantLoopThread = SafeSpawnThread("blatantLoopThread", function()
                    while blatantInstantState do
                        if checkFishingRemotes(true) then
                            -- Gunakan throttle untuk menurunkan recv
                            if CanBlatant() then
                                runBlatantInstant()
                            end
                        else
                            task.wait(1)
                            continue
                        end
                
                        -- Dynamic interval seperti sebelumnya
                        local timeSinceLastCatch = os.clock() - (_G.BlatantLastCatchTime or 0)
                        if timeSinceLastCatch > 5 then
                            task.wait(loopInterval + 0.2)
                        else
                            task.wait(loopInterval)
                        end
                    end
                end)


                -- 3. Auto Equip (OPTIMASI: Kurangi spam, hanya saat perlu)
                if blatantEquipThread then 
                    ThreadManager:Cancel("blatantEquipThread", false)
                    blatantEquipThread = nil
                end
                blatantEquipThread = SafeSpawnThread("blatantEquipThread", function()
                    while blatantInstantState do
                        -- OPTIMASI: Cek apakah rod sudah equipped sebelum spam
                        local character = LocalPlayer.Character
                        if character then
                            local tool = character:FindFirstChildOfClass("Tool")
                            if not tool or not tool.Name:find("Rod") then
                                pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                            end
                        else
                            pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                        end
                        task.wait(CONSTANTS.BlatantEquipDelay)
                    end
                    ThreadManager:Unregister("blatantEquipThread")
                end, "Blatant Auto Equip Thread")
                
                WindUI:Notify({ Title = "Blatant Mode ON", Duration = 3, Icon = "zap" })
            else
                -- 4. Server State: OFF
                if RF_UpdateAutoFishingState then
                    pcall(function() RF_UpdateAutoFishingState:InvokeServer(false) end)
                end

                if blatantLoopThread then 
                    ThreadManager:Cancel("blatantLoopThread", false)
                    blatantLoopThread = nil
                end
                if blatantEquipThread then 
                    ThreadManager:Cancel("blatantEquipThread", false)
                    blatantEquipThread = nil
                end
                
                WindUI:Notify({ Title = "Stopped", Duration = 2 })
            end
        end
    }))

    farm:Divider()

    -- -----------------------------------------------------------------
    -- ￰ﾟﾎﾯ FISHING AREA SECTION (POSITION + LOOKVECTOR)
    -- -----------------------------------------------------------------
    local areafish = farm:Section({
        Title = "Fishing Area",
        TextSize = 20,
    })

    -- 1. DROPDOWN Choose Area
    local choosearea = areafish:Dropdown({
        Title = "Choose Area",
        Values = AreaNames,
        AllowNone = true,
        Value = nil,
        Callback = function(option)
            selectedArea = option
            local display = option or "None"
        end
    })

    local freezeToggle = areafish:Toggle({
        Title = "Teleport & Freeze",
        Desc = "Teleport -> Wait for Server Sync -> Freeze.",
        Value = false,
        Callback = function(state)
            isTeleportFreezeActive = state
            
            local hrp = GetHRP()
            if not hrp then
                if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
                return
            end

            if state then
                if not selectedArea then
                    WindUI:Notify({ Title = "Action Failed", Content = "Select Area first in Dropdown!", Duration = 3, Icon = "alert-triangle", })
                    if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
                    return
                end
                
                local areaData = (selectedArea == "Custom: Saved" and savedPosition) or FishingAreas[selectedArea]

                if not areaData or not areaData.Pos or not areaData.Look then
                    WindUI:Notify({ Title = "Action Failed", Duration = 3, Icon = "alert-triangle", })
                    if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
                    return
                end
                
                -- 1. Unanchor dulu
                hrp.Anchored = false
                
                -- 2. Teleport ke Posisi Target
                TeleportToLookAt(areaData.Pos, areaData.Look)
                
                -- 3. [FIX] Tahan posisi tanpa Anchor selama 1.5 detik agar Server update Zona
                WindUI:Notify({ Title = "Syncing Zone...", Content = "Holding position so server can read new location...", Duration = 1.5, Icon = "wifi" })
                
                local startTime = os.clock()
                -- Loop selama 1.5 detik: Paksa diam tapi Physics tetap jalan (Server Update)
                while (os.clock() - startTime) < 1.5 and isTeleportFreezeActive do
                    if hrp then
                        hrp.Velocity = Vector3.new(0,0,0)
                        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                        -- Sedikit koreksi posisi biar server sadar kita disana
                        hrp.CFrame = CFrame.new(areaData.Pos, areaData.Pos + areaData.Look) * CFrame.new(0, 0.5, 0)
                    end
                    game:GetService("RunService").Heartbeat:Wait()
                end
                
                -- 4. Baru Freeze Total (Anchored) setelah server sync
                if isTeleportFreezeActive and hrp then
                    hrp.Anchored = true
                    WindUI:Notify({ Title = "Ready to Fish", Content = "Position locked & Zone updated.", Duration = 2, Icon = "check" })
                end
                
            else
                -- Matikan Freeze (UNANCHORED)
                if hrp then hrp.Anchored = false end
                WindUI:Notify({ Title = "Unfrozen", Content = "Gerakan kembali normal.", Duration = 2, Icon = "unlock" })
            end
        end
    })

    local teleto = areafish:Button({
        Title = "Teleport to Choosen Area",
        Icon = "corner-down-right",
        Callback = function()
            if not selectedArea then
                WindUI:Notify({ Title = "Teleport Failed", Content = "Select Area first in Dropdown!", Duration = 3, Icon = "alert-triangle", })
                return
            end

            local areaData = (selectedArea == "Custom: Saved" and savedPosition) or FishingAreas[selectedArea]
            
            if not areaData or not areaData.Pos or not areaData.Look then
                WindUI:Notify({ Title = "Teleport Failed",Duration = 3, Icon = "alert-triangle", })
                return
            end

            if isTeleportFreezeActive and freezeToggle then
                freezeToggle:Set(false)
                task.wait(0.1)
            end
            
            TeleportToLookAt(areaData.Pos, areaData.Look)
        end
    })

    farm:Divider()

    -- 3. BUTTON Save Current Position
    local savepos = areafish:Button({
        Title = "Save Current Position",
        Icon = "map-pin",
        Callback = function()
            local hrp = GetHRP()
            if hrp then
                savedPosition = {
                    Pos = hrp.Position,
                    Look = hrp.CFrame.LookVector
                }
                FishingAreas["Custom: Saved"] = savedPosition
                WindUI:Notify({
                    Title = "Position Saved!",
                    Duration = 3,
                    Icon = "save",
                })
            else
                WindUI:Notify({ Title = "Failed to Save", Duration = 3, Icon = "x", })
            end
        end
    })

    
    -- 6. BUTTON Teleport to SAVED POS
    local teletosave = areafish:Button({
        Title = "Teleport to SAVED Pos",
        Icon = "navigation",
        Callback = function()
            if not savedPosition then
                WindUI:Notify({ Title = "Teleport Failed", Content = "No position saved.", Duration = 3, Icon = "alert-triangle", })
                return
            end
            
            local areaData = savedPosition
            
            if isTeleportFreezeActive and freezeToggle then
                freezeToggle:Set(false)
                task.wait(0.1)
            end
            
            TeleportToLookAt(areaData.Pos, areaData.Look)
        end
    })
end
