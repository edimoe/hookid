do
    local premium = Window:Tab({
        Icon = "star",
        Title = "",
        Locked = false,
    })

    -- =================================================================
    -- [CONFIG] REMOTES & VARIABLES
    -- =================================================================
    local RPath = {"Packages", "_Index", "sleitnick_net@0.2.0", "net"}
    local RepStorage = game:GetService("ReplicatedStorage")
    local ItemUtility = require(RepStorage.Shared.ItemUtility)

    local function GetRemote(remotePath, name, timeout)
        local currentInstance = RepStorage
        for _, childName in ipairs(remotePath) do
            currentInstance = currentInstance:WaitForChild(childName, timeout or 0.5)
            if not currentInstance then return nil end
        end
        return currentInstance:FindFirstChild(name)
    end

    -- Remote Definitions
    local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")
    local RE_EquipItem = GetRemote(RPath, "RE/EquipItem") -- Rod (UUID)
    local RE_EquipBait = GetRemote(RPath, "RE/EquipBait") -- Bait (ID Number)
    local RE_UnequipItem = GetRemote(RPath, "RE/UnequipItem")
    
    local RF_PurchaseFishingRod = GetRemote(RPath, "RF/PurchaseFishingRod")
    local RF_PurchaseBait = GetRemote(RPath, "RF/PurchaseBait")
    local RF_SellAllItems = GetRemote(RPath, "RF/SellAllItems")
    
    local RF_ChargeFishingRod = GetRemote(RPath, "RF/ChargeFishingRod")
    local RF_RequestFishingMinigameStarted = GetRemote(RPath, "RF/RequestFishingMinigameStarted")
    local RE_FishingCompleted = GetRemote(RPath, "RE/FishingCompleted")
    local RF_CancelFishingInputs = GetRemote(RPath, "RF/CancelFishingInputs")

    local RF_PlaceLeverItem = GetRemote(RPath, "RE/PlaceLeverItem")
    local RE_SpawnTotem = GetRemote(RPath, "RE/SpawnTotem")
    local RF_CreateTranscendedStone = GetRemote(RPath, "RF/CreateTranscendedStone")
    local RF_ConsumePotion = GetRemote(RPath, "RF/ConsumePotion")
    local RF_UpdateAutoFishingState = GetRemote(RPath, "RF/UpdateAutoFishingState")
    
    -- [LOCATIONS]
    local ENCHANT_ROOM_POS = Vector3.new(3255.670, -1301.530, 1371.790)
    local ENCHANT_ROOM_LOOK = Vector3.new(-0.000, -0.000, -1.000)
    local TREASURE_ROOM_POS = Vector3.new(-3598.440, -281.274, -1645.855)
    local TREASURE_ROOM_LOOK = Vector3.new(-0.065, 0.000, -0.998)
    local SISYPHUS_POS = Vector3.new(-3743.745, -135.074, -1007.554)
    local SISYPHUS_LOOK = Vector3.new(0.310, 0.000, 0.951)
    local ANCIENT_JUNGLE_POS = Vector3.new(1535.639, 3.159, -193.352)
    local ANCIENT_JUNGLE_LOOK = Vector3.new(0.505, -0.000, 0.863)
    local SACRED_TEMPLE_POS = Vector3.new(1461.815, -22.125, -670.234)
    local SACRED_TEMPLE_LOOK = Vector3.new(-0.990, -0.000, 0.143)
    local SECOND_ALTAR_POS = Vector3.new(1479.587, 128.295, -604.224)
    local SECOND_ALTAR_LOOK = Vector3.new(-0.298, 0.000, -0.955)

    local AUTO_LEVER_ACTIVE = false
    local AUTO_LEVER_THREAD = nil
    local LEVER_INSTANT_DELAY = 1.7
    local LEVER_STATUS_PARAGRAPH

    local AUTO_POTION_ACTIVE = false
    local AUTO_POTION_THREAD = nil
    local selectedPotions = {}
    local potionTimers = {}
    local POTION_DATA = {["Luck I Potion"]={Id=1,Duration=900},["Luck II Potion"]={Id=6,Duration=900},["Mutation I Potion"]={Id=4,Duration=900}}
    local POTION_NAMES_LIST = {"Luck I Potion", "Luck II Potion", "Mutation I Potion"}
    local POTION_STATUS_PARAGRAPH

    -- [DATA QUEST ARTIFACT]
    local ArtifactData = {
        ["Hourglass Diamond Artifact"] = {
            ItemName = "Hourglass Diamond Artifact", LeverName = "Hourglass Diamond Lever", ChildReference = 6, CrystalPathSuffix = "Crystal",
            UnlockColor = Color3.fromRGB(255, 248, 49),
            FishingPos = {Pos = Vector3.new(1490.144, 3.312, -843.171), Look = Vector3.new(0.115, 0.000, 0.993)},
        },
        ["Diamond Artifact"] = {
            ItemName = "Diamond Artifact", LeverName = "Diamond Lever", ChildReference = "TempleLever", CrystalPathSuffix = "Crystal",
            UnlockColor = Color3.fromRGB(219, 38, 255),
            FishingPos = {Pos = Vector3.new(1844.159, 2.530, -288.755), Look = Vector3.new(0.981, 0.000, -0.193)},
        },
        ["Arrow Artifact"] = {
            ItemName = "Arrow Artifact", LeverName = "Arrow Lever", ChildReference = 5, CrystalPathSuffix = "Crystal",
            UnlockColor = Color3.fromRGB(255, 47, 47),
            FishingPos = {Pos = Vector3.new(874.365, 2.530, -358.484), Look = Vector3.new(-0.990, 0.000, 0.144)},
        },
        ["Crescent Artifact"] = {
            ItemName = "Crescent Artifact", LeverName = "Crescent Lever", ChildReference = 4, CrystalPathSuffix = "Crystal",
            UnlockColor = Color3.fromRGB(112, 255, 69),
            FishingPos = {Pos = Vector3.new(1401.070, 6.489, 116.738), Look = Vector3.new(-0.500, -0.000, 0.866)},
        },
    }
    local ArtifactOrder = {"Hourglass Diamond Artifact", "Diamond Artifact", "Arrow Artifact", "Crescent Artifact"}

    -- =================================================================
    -- [HELPERS]
    -- =================================================================
    local function GetPlayerDataReplion()
        local ReplionModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Replion", 5)
        if not ReplionModule then return nil end
        return require(ReplionModule).Client:WaitReplion("Data", 5)
    end

    local function TeleportToLookAt(position, lookVector)
        local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(position, position + lookVector) * CFrame.new(0,0.5,0) end
    end

    -- =================================================================
    -- [QUEST HELPERS]
    -- =================================================================
    local function GetGhostfinProgressSafe()
        local data = { Header = "Loading...", Q1={Text="...",Done=false}, Q2={Text="...",Done=false}, Q3={Text="...",Done=false}, Q4={Text="...",Done=false}, AllDone=false, BoardFound=false }
        local board = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Deep Sea Tracker") and workspace["!!! MENU RINGS"]["Deep Sea Tracker"]:FindFirstChild("Board")
        if board then
            data.BoardFound = true 
            pcall(function()
                local c = board.Gui.Content
                data.Header = c.Header.ContentText ~= "" and c.Header.ContentText or c.Header.Text
                local function proc(lbl) local t = lbl.ContentText~="" and lbl.ContentText or lbl.Text return {Text=t, Done=string.find(t, "100%%")~=nil} end
                data.Q1 = proc(c.Label1); data.Q2 = proc(c.Label2); data.Q3 = proc(c.Label3); data.Q4 = proc(c.Label4)
                if data.Q1.Done and data.Q2.Done and data.Q3.Done and data.Q4.Done then data.AllDone = true end
            end)
        end
        return data
    end

    local function GetElementProgressSafe()
        local data = { Header = "Loading...", Q1={Text="...",Done=false}, Q2={Text="...",Done=false}, Q3={Text="...",Done=false}, Q4={Text="...",Done=false}, AllDone=false, BoardFound=false }
        local board = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Element Tracker") and workspace["!!! MENU RINGS"]["Element Tracker"]:FindFirstChild("Board")
        if board then
            data.BoardFound = true
            pcall(function()
                local c = board.Gui.Content
                data.Header = c.Header.ContentText ~= "" and c.Header.ContentText or c.Header.Text
                local function proc(lbl) local t = lbl.ContentText~="" and lbl.ContentText or lbl.Text return {Text=t, Done=string.find(t, "100%%")~=nil} end
                data.Q1 = proc(c.Label1); data.Q2 = proc(c.Label2); data.Q3 = proc(c.Label3); data.Q4 = proc(c.Label4)
                if data.Q1.Done and data.Q2.Done and data.Q3.Done and data.Q4.Done then data.AllDone = true end
            end)
        end
        return data
    end

    local function IsLeverUnlocked(artifactName)
        local JUNGLE = workspace:FindFirstChild("JUNGLE INTERACTIONS")
        if not JUNGLE then return false end
        local data = ArtifactData[artifactName]
        if not data then return false end
        local folder = nil
        if type(data.ChildReference) == "string" then folder = JUNGLE:FindFirstChild(data.ChildReference) end
        if not folder and type(data.ChildReference) == "number" then local c = JUNGLE:GetChildren() folder = c[data.ChildReference] end
        if not folder then return false end
        local crystal = folder:FindFirstChild(data.CrystalPathSuffix)
        if not crystal or not crystal:IsA("BasePart") then return false end
        local cC, tC = crystal.Color, data.UnlockColor
        return (math.abs(cC.R*255 - tC.R*255) < 1.1 and math.abs(cC.G*255 - tC.G*255) < 1.1 and math.abs(cC.B*255 - tC.B*255) < 1.1)
    end

    local function RunQuestInstantFish(dynamicDelay)
        if not (RE_EquipToolFromHotbar and RF_ChargeFishingRod and RF_RequestFishingMinigameStarted) then return end
        local ts = os.time() + os.clock()
        pcall(function() RF_ChargeFishingRod:InvokeServer(ts) end)
        pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.6, 0.99) end)
        task.wait(dynamicDelay)
        pcall(function() RE_FishingCompleted:FireServer() end)
        task.wait(0.3)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    end

    -- =================================================================
    -- [UI CONTROLS]
    -- =================================================================
    -- =================================================================
    -- AUTO LEVER (STANDALONE)
    -- =================================================================
    local temple = premium:Section({ Title = "Auto Temple Lever", TextSize = 20 })
    LEVER_STATUS_PARAGRAPH = temple:Paragraph({ Title = "Status Lever", Content = "Checking...", Icon = "wand-2" })
    local templeslid = temple:Slider({ Title = "Lever Instant Delay", Desc = "Delay farming.", Step = 0.1, Value = { Min = 0.5, Max = 4.0, Default = 1.7 }, Callback = function(value) LEVER_INSTANT_DELAY = tonumber(value) or 1.7 end })
    
    local AUTO_LEVER_EQUIP_THREAD = nil
    local LEVER_FARMING_MODE = false
    
    local function RunAutoLeverLoop()
        -- Bersihkan thread lama jika ada
        if AUTO_LEVER_THREAD then task.cancel(AUTO_LEVER_THREAD) end
        if AUTO_LEVER_EQUIP_THREAD then task.cancel(AUTO_LEVER_EQUIP_THREAD) end

        -- [THREAD 1] BACKGROUND EQUIPPER (Jaga Rod tetep di tangan)
        AUTO_LEVER_EQUIP_THREAD = task.spawn(function()
            while AUTO_LEVER_ACTIVE do
                -- Hanya equip rod jika kita sedang dalam mode FARMING (bukan pasang lever)
                if LEVER_FARMING_MODE then
                    pcall(function() 
                        -- Equip Slot 1 (Biasanya Rod)
                        RE_EquipToolFromHotbar:FireServer(1) 
                    end)
                end
                task.wait(0.5) -- Cek setiap 0.5 detik
            end
        end)

        -- [THREAD 2] MAIN LOGIC LOOP
        AUTO_LEVER_THREAD = task.spawn(function()
            local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            while AUTO_LEVER_ACTIVE do
                local allUnlocked = true
                local artifactToProcess = nil
                local statusStr = ""
                
                -- Cek status semua lever
                for _, artifactName in ipairs(ArtifactOrder) do
                    local isUnlocked = IsLeverUnlocked(artifactName)
                    local statusIcon = isUnlocked and "UNLOCKED ￢ﾜﾅ" or "LOCKED ￰ﾟﾔﾒ"
                    statusStr = statusStr .. ArtifactData[artifactName].LeverName .. ": " .. statusIcon .. "\n"
                    
                    if not isUnlocked and not artifactToProcess then
                        artifactToProcess = artifactName
                    end
                    
                    if not isUnlocked then allUnlocked = false end
                end
                
                LEVER_STATUS_PARAGRAPH:SetDesc(statusStr)

                if allUnlocked then
                    LEVER_STATUS_PARAGRAPH:SetTitle("ALL LEVERS UNLOCKED ￢ﾜﾅ")
                    WindUI:Notify({ Title = "Selesai", Content = "Semua Lever terbuka!", Duration = 5, Icon = "check" })
                    break
                elseif artifactToProcess then
                    local artData = ArtifactData[artifactToProcess]
                    
                    -- Cek apakah item ada di backpack (Menggunakan fungsi FIX ID dari global)
                    if HasArtifactItem(artifactToProcess) then
                        -- === MODE PASANG (HOLD ARTIFACT) ===
                        LEVER_FARMING_MODE = false -- [PENTING] Matikan auto equip rod biar ga ganggu
                        
                        LEVER_STATUS_PARAGRAPH:SetTitle("MEMASANG: " .. artifactToProcess)
                        
                        -- 1. Teleport ke titik pasang
                        TeleportToLookAt(artData.FishingPos.Pos, artData.FishingPos.Look)
                        
                        -- 2. Anchor biar ga jatuh
                        if hrp then hrp.Anchored = true end
                        task.wait(0.5)
                        
                        -- 3. Unequip Rod dulu biar aman, lalu Equip Artifact (Otomatis oleh game biasanya, tapi kita bantu unequip)
                        pcall(function() RE_UnequipItem:FireServer("all") end)
                        task.wait(0.2)

                        -- 4. Pasang
                        pcall(function() RF_PlaceLeverItem:FireServer(artifactToProcess) end)
                        task.wait(2.0) -- Tunggu server merespon
                        
                        -- 5. Unanchor
                        if hrp then hrp.Anchored = false end
                    else
                        -- === MODE FARMING (HOLD ROD) ===
                        LEVER_FARMING_MODE = true -- [PENTING] Nyalakan auto equip rod
                        
                        LEVER_STATUS_PARAGRAPH:SetTitle("FARMING: " .. artifactToProcess)
                        
                        -- Cek jarak, kalau jauh teleport dulu
                        if hrp and (hrp.Position - artData.FishingPos.Pos).Magnitude > 10 then
                            TeleportToLookAt(artData.FishingPos.Pos, artData.FishingPos.Look)
                            task.wait(0.5)
                        else
                            RunQuestInstantFish(LEVER_INSTANT_DELAY)
                            task.wait(0.1) -- Loop cepat buat cek inventory lagi
                        end
                    end
                end
                task.wait(0.1)
            end
            
            -- Cleanup saat stop
            AUTO_LEVER_ACTIVE = false
            LEVER_FARMING_MODE = false
            if AUTO_LEVER_EQUIP_THREAD then task.cancel(AUTO_LEVER_EQUIP_THREAD) end
            premium:GetElementByTitle("Enable Auto Lever"):Set(false)
        end)
    end

    local enablelever = temple:Toggle({
        Title = "Enable Auto Lever",
        Value = false,
        Callback = function(state)
            AUTO_LEVER_ACTIVE = state
            if state then 
                RunAutoLeverLoop() 
            else 
                if AUTO_LEVER_THREAD then task.cancel(AUTO_LEVER_THREAD) end
                if AUTO_LEVER_EQUIP_THREAD then task.cancel(AUTO_LEVER_EQUIP_THREAD) end -- Matikan thread equip
                LEVER_FARMING_MODE = false
            end
        end
    })

    premium:Divider()

    -- =================================================================
    -- AUTO TOTEM
    -- =================================================================
    local AUTO_TOTEM_ACTIVE = false
    local AUTO_TOTEM_THREAD = nil
    local currentTotemExpiry = 0
    local selectedTotemName = "Luck Totem"
    local TOTEM_DATA = {
        ["Luck Totem"] = { Id = 1, Duration = 3601 },
        ["Mutation Totem"] = { Id = 3, Duration = 3601 },
        ["Shiny Totem"] = { Id = 2, Duration = 3601 },
    }
    local TOTEM_NAMES = { "Luck Totem", "Shiny Totem", "Mutation Totem" }

    local totem = premium:Section({ Title = "Auto Totem", TextSize = 20 })
    TOTEM_STATUS_PARAGRAPH = totem:Paragraph({
        Title = "Totem Status",
        Content = "Status: OFF",
        Icon = "timer"
    })

    -- =================================================================
    -- HELPER
    -- =================================================================
    local function GetTotemUUID(name)
        local r = GetPlayerDataReplion() if not r then return nil end
        local s, d = pcall(function() return r:GetExpect("Inventory") end)
        if s and d.Totems then 
            for _, i in ipairs(d.Totems) do 
                if tonumber(i.Id) == TOTEM_DATA[name].Id and (i.Count or 1) >= 1 then return i.UUID end 
            end 
        end
    end

    -- =================================================================
    -- UI & SINGLE TOGGLE
    -- =================================================================
    local function RunAutoTotemLoop()
        if AUTO_TOTEM_THREAD then task.cancel(AUTO_TOTEM_THREAD) end
        AUTO_TOTEM_THREAD = task.spawn(function()
            while AUTO_TOTEM_ACTIVE do
                local totemData = TOTEM_DATA[selectedTotemName]
                if not totemData then
                    TOTEM_STATUS_PARAGRAPH:SetDesc("Invalid totem selected.")
                    task.wait(1)
                    continue
                end
                local timeLeft = currentTotemExpiry - os.time()
                if timeLeft > 0 then
                    local m = math.floor((timeLeft % 3600) / 60); local s = math.floor(timeLeft % 60)
                    TOTEM_STATUS_PARAGRAPH:SetDesc(string.format("Next Spawn: %02d:%02d", m, s))
                else
                    TOTEM_STATUS_PARAGRAPH:SetDesc("Spawning Single...")
                    local uuid = GetTotemUUID(selectedTotemName)
                    if uuid then
                        pcall(function() RE_SpawnTotem:FireServer(uuid) end)
                        currentTotemExpiry = os.time() + totemData.Duration
                        task.spawn(function() for i=1,3 do task.wait(0.2) pcall(function() RE_EquipToolFromHotbar:FireServer(1) end) end end)
                    end
                end
                task.wait(1)
            end
        end)
    end

    local choosetot = totem:Dropdown({ Title = "Pilih Jenis Totem", Values = TOTEM_NAMES, Value = selectedTotemName, Multi = false, Callback = function(n) selectedTotemName = n; currentTotemExpiry = 0 end })

    local togtot = totem:Toggle({ Title = "Enable Auto Totem (Single)", Desc = "Mode Normal", Value = false, Flag = "toggletotem", Callback = function(s) AUTO_TOTEM_ACTIVE = s; if s then RunAutoTotemLoop() else if AUTO_TOTEM_THREAD then task.cancel(AUTO_TOTEM_THREAD) end end end })

    premium:Divider()
    local potion = premium:Section({ Title = "Auto Consume Potions", TextSize = 20})
    POTION_STATUS_PARAGRAPH = potion:Paragraph({ Title = "Potion Status", Content = "Status: OFF", Icon = "timer" })

    local function GetPotionUUID(name)
        local r = GetPlayerDataReplion() if not r then return nil end
        local s, d = pcall(function() return r:GetExpect("Inventory") end)
        if s and d.Potions then for _, i in ipairs(d.Potions) do if tonumber(i.Id) == POTION_DATA[name].Id and (i.Count or 1) >= 1 then return i.UUID end end end
    end

    local function RunAutoPotionLoop()
        if AUTO_POTION_THREAD then task.cancel(AUTO_POTION_THREAD) end
        AUTO_POTION_THREAD = task.spawn(function()
            while AUTO_POTION_ACTIVE do
                local cur = os.time()
                for _, name in ipairs(selectedPotions) do
                    local exp = potionTimers[name] or 0
                    if cur >= exp then
                        local uuid = GetPotionUUID(name)
                        if uuid then
                            pcall(function() RF_ConsumePotion:InvokeServer(uuid, 1) end)
                            potionTimers[name] = cur + POTION_DATA[name].Duration + 2
                        end
                    end
                end
                -- Update UI
                if POTION_STATUS_PARAGRAPH then
                    local txt = ""
                    for _, n in ipairs(selectedPotions) do
                        local lf = (potionTimers[n] or 0) - cur
                        if lf > 0 then txt = txt .. string.format("￰ﾟﾟﾢ %s: %ds\n", n, lf) else txt = txt .. string.format("￰ﾟﾟﾡ %s: Checking...\n", n) end
                    end
                    POTION_STATUS_PARAGRAPH:SetDesc(txt~="" and txt or "No Potion Selected")
                end
                task.wait(1)
            end
        end)
    end

    local choosepot = potion:Dropdown({ Title = "Select Potions", Values = POTION_NAMES_LIST, Multi = true, AllowNone = true, Callback = function(v) selectedPotions = v or {} end })
    local togpot = potion:Toggle({ Title = "Enable Auto Potion", Value = false, Callback = function(s) AUTO_POTION_ACTIVE = s if s then RunAutoPotionLoop() else if AUTO_POTION_THREAD then task.cancel(AUTO_POTION_THREAD) end end end })
end
