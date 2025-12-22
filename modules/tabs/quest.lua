do
    local quest = Window:Tab({
        Icon = "scroll",
        Title = "",
        Locked = false,
    })

    -- =================================================================
    -- CONFIG & VARIABLES
    -- =================================================================
    local ID_GHOSTFIN_ROD = 169
    
    local GHOSTFIN_QUEST_ACTIVE = false
    local GHOSTFIN_MAIN_THREAD = nil
    
    local ELEMENT_QUEST_ACTIVE = false
    local ELEMENT_MAIN_THREAD = nil

    -- [THREAD] AUTO EQUIP (Background)
    local QUEST_AUTO_EQUIP_THREAD = nil 

    -- Controller & Remotes
    local RPath = {"Packages", "_Index", "sleitnick_net@0.2.0", "net"}
    
    local function GetRemote(remotePath, name, timeout)
        local currentInstance = game:GetService("ReplicatedStorage")
        for _, childName in ipairs(remotePath) do
            currentInstance = currentInstance:WaitForChild(childName, timeout or 0.5)
            if not currentInstance then return nil end
        end
        return currentInstance:FindFirstChild(name)
    end

    local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")
    local RF_ChargeFishingRod = GetRemote(RPath, "RF/ChargeFishingRod")
    local RF_RequestFishingMinigameStarted = GetRemote(RPath, "RF/RequestFishingMinigameStarted")
    local RE_FishingCompleted = GetRemote(RPath, "RE/FishingCompleted")
    local RF_CancelFishingInputs = GetRemote(RPath, "RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = GetRemote(RPath, "RF/UpdateAutoFishingState")
    
    -- Remotes Tambahan
    local RF_CreateTranscendedStone = GetRemote(RPath, "RF/CreateTranscendedStone")
    local RF_PlaceLeverItem = GetRemote(RPath, "RE/PlaceLeverItem")
    local RE_EquipItem = GetRemote(RPath, "RE/EquipItem")
    local RE_UnequipItem = GetRemote(RPath, "RE/UnequipItem")

    -- Lokasi Penting
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

    -- Data Artifact
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
    -- [DATA] PRICES FOR LOGIC
    -- =================================================================
    local SPECIAL_ROD_IDS = {[169] = {Name = "Ghostfin Rod", Price = 99999999}, [257] = {Name = "Element Rod", Price = 999999999}}
    local ShopItems = {
        ["Rods"] = {
            {Name="Luck Rod",ID=79,Price=325},{Name="Carbon Rod",ID=76,Price=750},{Name="Grass Rod",ID=85,Price=1500},{Name="Demascus Rod",ID=77,Price=3000},
            {Name="Ice Rod",ID=78,Price=5000},{Name="Lucky Rod",ID=4,Price=15000},{Name="Midnight Rod",ID=80,Price=50000},{Name="Steampunk Rod",ID=6,Price=215000},
            {Name="Chrome Rod",ID=7,Price=437000},{Name="Flourescent Rod",ID=255,Price=715000},{Name="Astral Rod",ID=5,Price=1000000},
            {Name="Ares Rod",ID=126,Price=3000000},{Name="Angler Rod",ID=168,Price=8000000},{Name = "Bamboo Rod", ID = 258, Price = 12000000}
        }
    }
    
    local ROD_DELAYS = {
    -- [Starter / Cheap Rods]
    [79]  = 4.6, -- Luck Rod
    [76]  = 4.35, -- Carbon Rod
    [85]  = 4.2, -- Grass Rod
    [77]  = 4.35, -- Demascus Rod
    [78]  = 3.85, -- Ice Rod
    
    -- [Mid Tier Rods]
    [4]   = 3.5, -- Lucky Rod
    [80]  = 2.7, -- Midnight Rod
    
    -- [High Tier Rods]
    [6]   = 2.3, -- Steampunk Rod
    [7]   = 2.2, -- Chrome Rod
    [255] = 2.2, -- Flourescent Rod
    [5]   = 1.85, -- Astral Rod
    
    -- [God Tier Rods]
    [126] = 1.7, -- Ares Rod
    [168] = 1.6, -- Angler Rod
    
    -- [Quest / Special Rods]
    [169] = 1.2, -- Ghostfin Rod
    [257] = 1, -- Element Rod
}

local DEFAULT_ROD_DELAY = 3.85

    local function GetRodPriceByID(id)
        id = tonumber(id)
        if SPECIAL_ROD_IDS[id] then return SPECIAL_ROD_IDS[id].Price, SPECIAL_ROD_IDS[id].Name end
        for _, item in ipairs(ShopItems["Rods"]) do if item.ID == id then return item.Price, item.Name end end
        return 0, "Unknown Rod"
    end

    -- =================================================================
    -- [CORE] EQUIP BEST ROD ONLY & GET PRECISE DELAY
    -- =================================================================
    local function EquipBestRod()
        local replion = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Replion")).Client:WaitReplion("Data", 5)
        if not replion then return DEFAULT_ROD_DELAY end 
        
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData then return DEFAULT_ROD_DELAY end

        -- 1. Find Best Rod (Highest Price logic is still good for selection)
        local bestRodUUID, bestRodPrice = nil, -1
        local bestRodId = nil -- Kita simpan ID-nya untuk cek delay

        if inventoryData["Fishing Rods"] then
            for _, rod in ipairs(inventoryData["Fishing Rods"]) do
                local price = GetRodPriceByID(rod.Id)
                if price > bestRodPrice then 
                    bestRodPrice = price
                    bestRodUUID = rod.UUID 
                    bestRodId = tonumber(rod.Id) -- Simpan ID
                end
            end
        end

        -- 2. Equip Best Rod
        if bestRodUUID then 
            pcall(function() RE_EquipItem:FireServer(bestRodUUID, "Fishing Rods") end) 
        end
        
        -- 3. Hold Tool
        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)

        -- 4. Calculate Delay (NEW PRECISE LOGIC)
        if bestRodId and ROD_DELAYS[bestRodId] then
            return ROD_DELAYS[bestRodId]
        else
            return DEFAULT_ROD_DELAY
        end
    end

    -- =================================================================
    -- [CORE] INSTANT FISH (DYNAMIC DELAY)
    -- =================================================================
    local function RunQuestInstantFish(dynamicDelay)
        if not (RE_EquipToolFromHotbar and RF_ChargeFishingRod and RF_RequestFishingMinigameStarted and RE_FishingCompleted and RF_CancelFishingInputs) then return end
        
        -- 1. Charge Rod
        local timestamp = os.time() + os.clock()
        pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
        
        -- 2. Cast Rod
        pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.630452165, 0.99647927980797) end)
        
        -- 3. Wait Smart Delay
        task.wait(dynamicDelay)
        
        -- 4. Complete & Reset
        pcall(function() RE_FishingCompleted:FireServer() end)
        task.wait(0.3)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    end

    -- [THREAD] AUTO EQUIP BACKGROUND (Rod Only)
    local function StartQuestAutoEquip()
        if QUEST_AUTO_EQUIP_THREAD then task.cancel(QUEST_AUTO_EQUIP_THREAD) end
        QUEST_AUTO_EQUIP_THREAD = task.spawn(function()
            local tick = 0
            while GHOSTFIN_QUEST_ACTIVE or ELEMENT_QUEST_ACTIVE do
                -- Equip Rod Slot 1 setiap 0.5 detik
                pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                
                -- Setiap 5 detik, paksa re-check & equip best rod (jaga-jaga ganti item)
                if tick % 10 == 0 then
                    EquipBestRod() 
                end
                
                tick = tick + 1
                task.wait(0.5)
            end
        end)
    end

    local function StopQuestAutoEquip()
        if QUEST_AUTO_EQUIP_THREAD then task.cancel(QUEST_AUTO_EQUIP_THREAD) QUEST_AUTO_EQUIP_THREAD = nil end
        pcall(function() RE_EquipToolFromHotbar:FireServer(0) end) 
    end

    -- =================================================================
    -- QUEST LOGIC HELPERS
    -- =================================================================
    local function HasGhostfinRod()
        local replion = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Replion")).Client:WaitReplion("Data", 5)
        if not replion then return false end
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData["Fishing Rods"] then return false end
        for _, rod in ipairs(inventoryData["Fishing Rods"]) do
            if tonumber(rod.Id) == ID_GHOSTFIN_ROD then return true end
        end
        return false
    end

    local function GetLowestWeightSecrets(limit)
        local secrets = {}
        local replion = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Replion")).Client:WaitReplion("Data", 5)
        if not replion then return {} end
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if success and inventoryData and inventoryData.Items then
            for _, item in ipairs(inventoryData.Items) do
                local rarity = item.Metadata and item.Metadata.Rarity or "Unknown"
                if rarity:upper() == "SECRET" and item.Metadata and item.Metadata.Weight then
                    if not (item.IsFavorite or item.Favorited or item.Locked) then
                        table.insert(secrets, {UUID = item.UUID, Weight = item.Metadata.Weight})
                    end
                end
            end
        end
        table.sort(secrets, function(a, b) return a.Weight < b.Weight end)
        local result = {}
        for i = 1, math.min(limit, #secrets) do table.insert(result, secrets[i].UUID) end
        return result
    end

    -- Lever Helpers
    local function IsLeverUnlocked(artifactName)
        local JUNGLE_INTERACTIONS = workspace:FindFirstChild("JUNGLE INTERACTIONS")
        if not JUNGLE_INTERACTIONS then return false end
        local data = ArtifactData[artifactName]
        if not data then return false end
        
        local leverFolder = nil
        if type(data.ChildReference) == "string" then leverFolder = JUNGLE_INTERACTIONS:FindFirstChild(data.ChildReference) end
        if not leverFolder and type(data.ChildReference) == "number" then local c = JUNGLE_INTERACTIONS:GetChildren() leverFolder = c[data.ChildReference] end
        if not leverFolder then return false end
        
        local crystal = leverFolder:FindFirstChild(data.CrystalPathSuffix)
        if not crystal or not crystal:IsA("BasePart") then return false end
        
        local cC, tC = crystal.Color, data.UnlockColor
        return (math.abs(cC.R*255 - tC.R*255) < 1.1 and math.abs(cC.G*255 - tC.G*255) < 1.1 and math.abs(cC.B*255 - tC.B*255) < 1.1)
    end


    -- =================================================================
    -- QUEST 1: GHOSTFIN
    -- =================================================================
    local ghostfin = quest:Section({ Title = "Ghostfin Rod Quest", TextSize = 20 })
    local GhostfinStatus = ghostfin:Paragraph({ Title = "Quest Status: Idle", Content = "Waiting...", Icon = "activity" })

    -- Fungsi Baca Data Aman
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

    local function RunGhostfinLoop()
        if GHOSTFIN_MAIN_THREAD then task.cancel(GHOSTFIN_MAIN_THREAD) end
        StartQuestAutoEquip() -- Nyalakan Auto Equip Background

        GHOSTFIN_MAIN_THREAD = task.spawn(function()
            local currentTarget = "None"
            
            while GHOSTFIN_QUEST_ACTIVE do
                local p = GetGhostfinProgressSafe()
                
                -- Teleport ke Altar jika board tidak ketemu
                if not p.BoardFound then
                    GhostfinStatus:SetTitle("Status: Loading Board Data...")
                    GhostfinStatus:SetDesc("Mendekat ke Altar untuk membaca Quest...")
                    local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - SECOND_ALTAR_POS).Magnitude > 20 then
                        local tCFrame = CFrame.new(SECOND_ALTAR_POS, SECOND_ALTAR_POS + SECOND_ALTAR_LOOK)
                        hrp.CFrame = tCFrame
                        task.wait(2) 
                    end
                    task.wait(1)
                    continue 
                end

                GhostfinStatus:SetTitle(p.Header)
                GhostfinStatus:SetDesc(string.format("1. %s [%s]\n2. %s [%s]\n3. %s [%s]\n4. %s [%s]", p.Q1.Text, p.Q1.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q2.Text, p.Q2.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q3.Text, p.Q3.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q4.Text, p.Q4.Done and "￢ﾜﾅ" or "￢ﾝﾌ"))

                if p.AllDone then 
                    WindUI:Notify({ Title = "Selesai!", Content = "Ghostfin Quest Complete.", Duration = 5, Icon = "trophy" }) 
                    break 
                end

                local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(1) continue end
                
                -- Auto Equip & Hitung Delay Cerdas
                local smartDelay = EquipBestRod() -- Returns 2.0 or 3.0 based on rod price

                -- LOGIC FARMING
                if not p.Q1.Done then
                    if currentTarget ~= "Treasure" then
                        local tCFrame = CFrame.new(TREASURE_ROOM_POS, TREASURE_ROOM_POS + TREASURE_ROOM_LOOK)
                        hrp.CFrame = tCFrame
                        currentTarget = "Treasure"
                        task.wait(1.5)
                    elseif (hrp.Position - TREASURE_ROOM_POS).Magnitude > 15 then
                        local tCFrame = CFrame.new(TREASURE_ROOM_POS, TREASURE_ROOM_POS + TREASURE_ROOM_LOOK)
                        hrp.CFrame = tCFrame
                        task.wait(0.5)
                    else
                        RunQuestInstantFish(smartDelay) -- Pakai delay dari best rod
                    end

                elseif not p.Q2.Done or not p.Q3.Done or not p.Q4.Done then
                    if currentTarget ~= "Sisyphus" then
                        local tCFrame = CFrame.new(SISYPHUS_POS, SISYPHUS_POS + SISYPHUS_LOOK)
                        hrp.CFrame = tCFrame
                        currentTarget = "Sisyphus"
                        task.wait(1.5)
                    elseif (hrp.Position - SISYPHUS_POS).Magnitude > 15 then
                        local tCFrame = CFrame.new(SISYPHUS_POS, SISYPHUS_POS + SISYPHUS_LOOK)
                        hrp.CFrame = tCFrame
                        task.wait(0.5)
                    else
                        RunQuestInstantFish(smartDelay) -- Pakai delay dari best rod
                    end
                end
                
                task.wait(0.1)
            end
            
            GHOSTFIN_QUEST_ACTIVE = false
            StopQuestAutoEquip()
            local toggle = ghostfin:GetElementByTitle("Auto Quest Ghostfin")
            if toggle and toggle.Set then toggle:Set(false) end
        end)
    end

    local tghostfin = ghostfin:Toggle({
        Title = "Auto Quest Ghostfin",
        Value = false,
        Callback = function(state)
            GHOSTFIN_QUEST_ACTIVE = state
            if state then
                WindUI:Notify({ Title = "Ghostfin Quest", Content = "Started (Auto Best Rod & Smart Delay).", Duration = 3, Icon = "play" })
                RunGhostfinLoop()
            else
                StopQuestAutoEquip()
                if GHOSTFIN_MAIN_THREAD then task.cancel(GHOSTFIN_MAIN_THREAD) end
                WindUI:Notify({ Title = "Ghostfin Quest", Content = "Stopped.", Duration = 3, Icon = "square" })
            end
        end
    })

    -- =================================================================
    -- SECTION 2: ELEMENT ROD QUEST
    -- =================================================================
    quest:Divider()
    local element = quest:Section({ Title = "Element Rod Quest", TextSize = 20 })
    local ElementStatus = element:Paragraph({ Title = "Quest Status: Idle", Content = "Waiting...", Icon = "activity" })

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
    

    local function RunElementLoop()
        if ELEMENT_MAIN_THREAD then task.cancel(ELEMENT_MAIN_THREAD) end
        
        if not HasGhostfinRod() then
            WindUI:Notify({ Title = "Gagal", Content = "Butuh Ghostfin Rod (ID 169) di Inventory.", Duration = 5, Icon = "x" })
            quest:GetElementByTitle("Auto Quest Element"):Set(false)
            return
        end

        StartQuestAutoEquip()

        ELEMENT_MAIN_THREAD = task.spawn(function()
            local currentTarget = "None"

            while ELEMENT_QUEST_ACTIVE do
                local p = GetElementProgressSafe()
                
                if not p.BoardFound then
                    ElementStatus:SetTitle("Status: Loading Board Data...")
                    ElementStatus:SetDesc("Mendekat ke Altar untuk membaca Quest Element...")
                    local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - SECOND_ALTAR_POS).Magnitude > 20 then
                        local tCFrame = CFrame.new(SECOND_ALTAR_POS, SECOND_ALTAR_POS + SECOND_ALTAR_LOOK)
                        hrp.CFrame = tCFrame
                        task.wait(2)
                    end
                    task.wait(1)
                    continue
                end

                ElementStatus:SetTitle(p.Header)
                ElementStatus:SetDesc(string.format("1. %s [%s]\n2. %s [%s]\n3. %s [%s]\n4. %s [%s]", p.Q1.Text, p.Q1.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q2.Text, p.Q2.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q3.Text, p.Q3.Done and "￢ﾜﾅ" or "￢ﾝﾌ", p.Q4.Text, p.Q4.Done and "￢ﾜﾅ" or "￢ﾝﾌ"))

                if p.AllDone then WindUI:Notify({ Title = "Selesai!", Content = "Element Quest Complete.", Duration = 5, Icon = "trophy" }) break end

                local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(1) continue end

                -- Hitung Delay Cerdas
                local smartDelay = EquipBestRod()

                if not p.Q2.Done then
                    -- Quest Catch Fish in Ancient Jungle
                    if currentTarget ~= "Jungle" then
                        local tCFrame = CFrame.new(ANCIENT_JUNGLE_POS, ANCIENT_JUNGLE_POS + ANCIENT_JUNGLE_LOOK)
                        hrp.CFrame = tCFrame
                        currentTarget = "Jungle"
                        task.wait(1.5)
                    elseif (hrp.Position - ANCIENT_JUNGLE_POS).Magnitude > 15 then
                        local tCFrame = CFrame.new(ANCIENT_JUNGLE_POS, ANCIENT_JUNGLE_POS + ANCIENT_JUNGLE_LOOK)
                        hrp.CFrame = tCFrame
                        task.wait(0.5)
                    else
                        RunQuestInstantFish(smartDelay)
                    end

                elseif not p.Q3.Done then
                                -- Quest Levers
                                local allLeversOpen = true
                                local missingLever = nil
                                
                                -- Cek status lever
                                for _, artName in ipairs(ArtifactOrder) do
                                    if not IsLeverUnlocked(artName) then
                                        allLeversOpen = false
                                        missingLever = artName
                                        break
                                    end
                                end

                                if not allLeversOpen and missingLever then
                                    local artData = ArtifactData[missingLever]
                                    
                                    -- [FIX] Panggil Helper ID Baru di sini
                                    local hasIt = HasArtifactItem(missingLever) 
                                    
                                    if hasIt then
                                        -- === PUNYA ITEM (PASANG) ===
                                        if currentTarget ~= "PlaceLever" then
                                            local tCFrame = CFrame.new(artData.FishingPos.Pos, artData.FishingPos.Pos + artData.FishingPos.Look)
                                            hrp.CFrame = tCFrame
                                            currentTarget = "PlaceLever"
                                            
                                            WindUI:Notify({ Title = "Puzzle", Content = "Memasang " .. missingLever, Duration = 3 })
                                            
                                            -- [Tips] Tambah Anchor sebentar biar ga jatuh pas animasi
                                            if hrp then hrp.Anchored = true end
                                            task.wait(1.5)
                                        end
                                        
                                        pcall(function() RF_PlaceLeverItem:FireServer(missingLever) end)
                                        task.wait(2.0) -- Tunggu server merespon
                                        
                                        if hrp then hrp.Anchored = false end -- Lepas Anchor
                                    else
                                        -- === GAK PUNYA ITEM (MANCING) ===
                                        if currentTarget ~= missingLever then
                                            local tCFrame = CFrame.new(artData.FishingPos.Pos, artData.FishingPos.Pos + artData.FishingPos.Look)
                                            hrp.CFrame = tCFrame
                                            currentTarget = missingLever
                                            WindUI:Notify({ Title = "Puzzle", Content = "Farming " .. missingLever, Duration = 3 })
                                            task.wait(1.5)
                                        elseif (hrp.Position - artData.FishingPos.Pos).Magnitude > 10 then
                                            -- Cek kalau kejauhan/jatuh
                                            local tCFrame = CFrame.new(artData.FishingPos.Pos, artData.FishingPos.Pos + artData.FishingPos.Look)
                                            hrp.CFrame = tCFrame
                                            task.wait(0.5)
                                        else
                                            -- Mancing
                                            RunQuestInstantFish(smartDelay)
                                            -- [PENTING] Jeda dikit biar loop berikutnya sempet baca inventory baru
                                            task.wait(0.1) 
                                        end
                                    end
                                else
                                    -- Semua lever terbuka tapi quest belum done (Bug Visual/Delay)
                                    -- Refresh di Temple
                                    if currentTarget ~= "TempleWait" then
                                        if (hrp.Position - SACRED_TEMPLE_POS).Magnitude > 15 then 
                                            TeleportToLookAt(SACRED_TEMPLE_POS, SACRED_TEMPLE_LOOK) 
                                            task.wait(0.5) 
                                        end
                                        currentTarget = "TempleWait"
                                    end
                                    RunQuestInstantFish(smartDelay)
                                end

                elseif not p.Q4.Done then
                    -- Quest Create Stone (Sacrifice Secrets)
                    if currentTarget ~= "Altar" then
                        local tCFrame = CFrame.new(SECOND_ALTAR_POS, SECOND_ALTAR_POS + SECOND_ALTAR_LOOK)
                        hrp.CFrame = tCFrame
                        currentTarget = "Altar"
                        task.wait(1.5)
                    end
                    
                    local trashSecrets = GetLowestWeightSecrets(3)
                    if #trashSecrets == 0 then
                        WindUI:Notify({ Title = "Bahan Kurang", Content = "Tidak ada ikan SECRET di tas.", Duration = 5, Icon = "alert-triangle" })
                        task.wait(5)
                    else
                        pcall(function() if RE_UnequipItem then RE_UnequipItem:FireServer("all") end end)
                        task.wait(0.5)
                        for i, fishUUID in ipairs(trashSecrets) do
                            if not ELEMENT_QUEST_ACTIVE then break end
                            pcall(function() RE_EquipItem:FireServer(fishUUID, "Fish") end)
                            task.wait(0.3)
                            pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
                            task.wait(0.5)
                            pcall(function() RF_CreateTranscendedStone:InvokeServer() end)
                            task.wait(1.5)
                        end
                        pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
                        task.wait(2)
                    end
                end
                task.wait(0.1)
            end
            
            ELEMENT_QUEST_ACTIVE = false
            StopQuestAutoEquip()
            local toggle = element:GetElementByTitle("Auto Quest Element")
            if toggle and toggle.Set then toggle:Set(false) end
        end)
    end

    local telement = element:Toggle({
        Title = "Auto Quest Element",
        Value = false,
        Callback = function(state)
            ELEMENT_QUEST_ACTIVE = state
            if state then
                WindUI:Notify({ Title = "Element Quest", Content = "Started (Auto Best Rod & Smart Delay).", Duration = 3, Icon = "play" })
                RunElementLoop()
            else
                if ELEMENT_MAIN_THREAD then task.cancel(ELEMENT_MAIN_THREAD) end
                StopQuestAutoEquip()
                WindUI:Notify({ Title = "Element Quest", Content = "Stopped.", Duration = 3, Icon = "square" })
            end
        end
    })
end

-- =================================================================
-- VARIABLES & CORE HELPERS FOR EVENTS TAB (UPDATED)
-- =================================================================

local lastPositionBeforeEvent = nil
local autoJoinEventActive = false
local LOCHNESS_POS = Vector3.new(6063.347, -585.925, 4713.696)
local LOCHNESS_LOOK = Vector3.new(-0.376, -0.000, -0.927)

-- Christmas Cave Event Variables
local lastPositionBeforeChristmasCave = nil
local autoJoinChristmasCaveActive = false
local CHRISTMAS_CAVE_POS = Vector3.new(605.353, -580.581, 8885.047)
local CHRISTMAS_CAVE_LOOK = Vector3.new(-1.000, -0.000, -0.012)

-- *** AUTO UNLOCK RUIN DOOR ***
local AUTO_UNLOCK_STATE = false
local AUTO_UNLOCK_THREAD = nil
local AUTO_UNLOCK_ATTEMPT_THREAD = nil -- NEW THREAD FOR AGGRESSIVE UNLOCK
local RUIN_COMPLETE_DELAY = 1.5
local RUIN_DOOR_PATH = workspace["RUIN INTERACTIONS"] and workspace["RUIN INTERACTIONS"].Door
local ITEM_FISH_NAMES = {"Freshwater Piranha", "Goliath Tiger", "Sacred Guardian Squid", "Crocodile"}
local SACRED_TEMPLE_POS = FishingAreas["Sacred Temple"].Pos
local SACRED_TEMPLE_LOOK = FishingAreas["Sacred Temple"].Look
local RUIN_DOOR_REMOTE = GetRemote(RPath, "RE/PlacePressureItem")
local RUIN_DOOR_STATUS_PARAGRAPH
local RUIN_AUTO_UNLOCK_TOGGLE
local RF_UpdateAutoFishingState = GetRemote(RPath, "RF/UpdateAutoFishingState")
local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")
local RF_ChargeFishingRod = GetRemote(RPath, "RF/ChargeFishingRod")
local RF_RequestFishingMinigameStarted = GetRemote(RPath, "RF/RequestFishingMinigameStarted")
local RE_FishingCompleted = GetRemote(RPath, "RE/FishingCompleted")
local RF_CancelFishingInputs = GetRemote(RPath, "RF/CancelFishingInputs")


local function GetEventGUI()
	local success, gui = pcall(function()
		local menuRings = workspace:WaitForChild("!!! MENU RINGS", 5)
		local eventTracker = menuRings:WaitForChild("Event Tracker", 5)
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
	end
	return nil
end

-- Fungsi Anda yang sudah diperbaiki (dan kini selalu mengupdate UI)
local function GetRuinDoorStatus()
	local ruinDoor = RUIN_DOOR_PATH -- Pathing ke model pintu
	local status = "LOCKED ￰ﾟﾔﾒ"
	
	if ruinDoor and ruinDoor:FindFirstChild("RuinDoor") then
		local LDoor = ruinDoor.RuinDoor:FindFirstChild("LDoor")
		
		if LDoor then
			local currentX = nil
			
			if LDoor:IsA("BasePart") then
				currentX = LDoor.Position.X
			elseif LDoor:IsA("Model") then
				-- Menggunakan GetPivot() untuk model
				local success, pivot = pcall(function() return LDoor:GetPivot() end)
                if success and pivot then
                    currentX = pivot.Position.X
                end
			end
			
			if currentX ~= nil then
				-- Gunakan ambang batas 6075 atau yang Anda temukan
				if currentX > 6075 then
					status = "UNLOCKED ￢ﾜﾅ"
				end
			end
		end
	end
	
    -- PENTING: Update elemen UI di sini
	RUIN_DOOR_STATUS_PARAGRAPH:SetTitle("Ruin Door Status: " .. status)
	return status
end



local function IsItemAvailable(itemName)
	local replion = GetPlayerDataReplion()
	if not replion then return false end
	local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
	if not success or not inventoryData or not inventoryData.Items then return false end

	for _, item in ipairs(inventoryData.Items) do
		if item.Identifier == itemName then
			return true
		end
		
		local name, _ = GetFishNameAndRarity(item)
		if name == itemName and (item.Count or 1) >= 1 then
			return true
		end
	end
	return false
end

local function GetMissingItem()
	for _, name in ipairs(ITEM_FISH_NAMES) do
		if not IsItemAvailable(name) then
			return name
		end
	end
	return nil
end

local function runInstantFish()
	if not (RE_EquipToolFromHotbar and RF_ChargeFishingRod and RF_RequestFishingMinigameStarted and RE_FishingCompleted and RF_CancelFishingInputs) then
		return false
	end
	
	pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
	
	local timestamp = os.time() + os.clock()
	pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
	pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.630452165, 0.99647927980797) end)
	
	task.wait(RUIN_COMPLETE_DELAY)

	pcall(function() RE_FishingCompleted:FireServer() end)
	task.wait(0.3)
	pcall(function() RF_CancelFishingInputs:FireServer() end)
	
	return true
end

local function RunRuinDoorUnlockAttemptLoop()
	if AUTO_UNLOCK_ATTEMPT_THREAD then task.cancel(AUTO_UNLOCK_ATTEMPT_THREAD) end

	if not RUIN_DOOR_REMOTE then
		WindUI:Notify({ Title = "Error Remote", Content = "Remote Ruin Door (RE/PlacePressureItem) not found.", Duration = 4, Icon = "x" })
		return
	end
	
	AUTO_UNLOCK_ATTEMPT_THREAD = task.spawn(function()
		local RUIN_DOOR_POS = FishingAreas["Ancient Ruin"].Pos
		local RUIN_DOOR_LOOK = FishingAreas["Ancient Ruin"].Look
		
		TeleportToLookAt(RUIN_DOOR_POS, RUIN_DOOR_LOOK)
		task.wait(1.5)
		
		WindUI:Notify({ Title = "Unlock Attempt ON", Content = "Starting aggressive send remote PlacePressureItem...", Duration = 3, Icon = "zap" })

		while AUTO_UNLOCK_STATE and GetRuinDoorStatus() == "LOCKED ￰ﾟﾔﾒ" do
			for i, name in ipairs(ITEM_FISH_NAMES) do
				task.wait(2.1)
				pcall(function() RUIN_DOOR_REMOTE:FireServer(name) end)
			end
			
			task.wait(5)
		end
	end)
end

local function RunAutoUnlockLoop()
	if AUTO_UNLOCK_THREAD then task.cancel(AUTO_UNLOCK_THREAD) end
	if AUTO_UNLOCK_ATTEMPT_THREAD then task.cancel(AUTO_UNLOCK_ATTEMPT_THREAD) end
	
	pcall(function()
		local toggleLegit = Window:GetElementByTitle("Auto Fish (Legit)")
		local toggleNormal = Window:GetElementByTitle("Normal Instant Fish")
		local toggleBlatant = Window:GetElementByTitle("Instant Fishing (Blatant)")
		
		if toggleLegit and toggleLegit.Value then toggleLegit:Set(false) end
		if toggleNormal and toggleNormal.Value then toggleNormal:Set(false) end
		if toggleBlatant and toggleBlatant.Value then toggleBlatant:Set(false) end
		if RF_UpdateAutoFishingState then RF_UpdateAutoFishingState:InvokeServer(false) end
	end)

	AUTO_UNLOCK_THREAD = task.spawn(function()
		local isFarming = false
		local lastPositionBeforeEvent_Ruin = nil
		
		RunRuinDoorUnlockAttemptLoop()
		
		while AUTO_UNLOCK_STATE do
			local doorStatus = GetRuinDoorStatus()
			RUIN_DOOR_STATUS_PARAGRAPH:SetTitle("Ruin Door Status: " .. doorStatus)

			if doorStatus == "LOCKED ￰ﾟﾔﾒ" then
				local missingItem = GetMissingItem()

				if missingItem then
					
					if not isFarming then
						local hrp = GetHRP()
						if hrp and lastPositionBeforeEvent_Ruin == nil then
							lastPositionBeforeEvent_Ruin = {Pos = hrp.Position, Look = hrp.CFrame.LookVector}
							WindUI:Notify({ Title = "Position Saved", Content = "Position before Ruin Door farm saved.", Duration = 2, Icon = "save" })
						end
						TeleportToLookAt(SACRED_TEMPLE_POS, SACRED_TEMPLE_LOOK)
						task.wait(1.5)
						isFarming = true
						WindUI:Notify({ Title = "Ruin Door: Farming", Content = "Searching for " .. missingItem .. ". Fishing ON (Delay: "..RUIN_COMPLETE_DELAY.."s).", Duration = 4, Icon = "fish" })
					end
					
					RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("Searching for item: " .. missingItem .. ". Fishing...")
					runInstantFish()
					task.wait(RUIN_COMPLETE_DELAY + 0.5)
					
				else
					RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("All items found! Aggressive Unlock Loop running...")
					isFarming = false
					
					task.wait(1)
				end
				
			elseif doorStatus == "UNLOCKED ￢ﾜﾅ" then
				RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("Door already unlocked. Auto Unlock stopped.")
				
				if lastPositionBeforeEvent_Ruin then
					TeleportToLookAt(lastPositionBeforeEvent_Ruin.Pos, lastPositionBeforeEvent_Ruin.Look)
					lastPositionBeforeEvent_Ruin = nil
					WindUI:Notify({ Title = "Back to Original Position", Content = "Door UNLOCKED, continuing farm.", Duration = 4, Icon = "repeat" })
				end
				break
				
			else
				RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("Door status not detected. Checking again...")
				task.wait(5)
			end
		end
		
		pcall(function()
			if RE_EquipToolFromHotbar then RE_EquipToolFromHotbar:FireServer(0) end
		end)
		
		AUTO_UNLOCK_STATE = false
		if AUTO_UNLOCK_ATTEMPT_THREAD then task.cancel(AUTO_UNLOCK_ATTEMPT_THREAD) AUTO_UNLOCK_ATTEMPT_THREAD = nil end
		if RUIN_AUTO_UNLOCK_TOGGLE and RUIN_AUTO_UNLOCK_TOGGLE.Set then RUIN_AUTO_UNLOCK_TOGGLE:Set(false) end
		WindUI:Notify({ Title = "Auto Unlock OFF", Content = "Ruin Door process stopped.", Duration = 3, Icon = "x" })
	end)
