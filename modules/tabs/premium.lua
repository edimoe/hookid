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
    local RE_ObtainedNewFishNotification = GetRemote(RPath, "RE/ObtainedNewFishNotification") 

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
    local CORAL_REEF_POS = Vector3.new(-3207.538, 6.087, 2011.079)
    local CORAL_REEF_LOOK = Vector3.new(0.973, 0.000, 0.229)
    -- NOTE: Tropical Grove location assumed to be Tropical Island.
    local TROPICAL_GROVE_POS = Vector3.new(-2162.920, 2.825, 3638.445)
    local TROPICAL_GROVE_LOOK = Vector3.new(0.381, -0.000, 0.925)
    local RUBY_POS = Vector3.new(-3598.440, -281.274, -1645.855)
    local RUBY_LOOK = Vector3.new(-0.065, 0.000, -0.998)
    local LOCHNESS_POS = Vector3.new(-668.732, 3.000, 681.580)
    local LOCHNESS_LOOK = Vector3.new(0.889, -0.000, 0.458)

    -- [VARIABLES]
    local KAITUN_ACTIVE = false
    local KAITUN_THREAD = nil
    local KAITUN_AUTOSELL_THREAD = nil
    local KAITUN_EQUIP_THREAD = nil
    local KAITUN_OVERLAY = nil
    local KAITUN_CATCH_CONN = nil
    
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

    -- [DATA SHOP HARDCODE LENGKAP]
    local ShopItems = {
        ["Rods"] = {
            {Name="Luck Rod",ID=79,Price=325},{Name="Carbon Rod",ID=76,Price=750},{Name="Grass Rod",ID=85,Price=1500},{Name="Demascus Rod",ID=77,Price=3000},
            {Name="Ice Rod",ID=78,Price=5000},{Name="Lucky Rod",ID=4,Price=15000},{Name="Midnight Rod",ID=80,Price=50000},{Name="Steampunk Rod",ID=6,Price=215000},
            {Name="Chrome Rod",ID=7,Price=437000},{Name="Flourescent Rod",ID=255,Price=715000},{Name="Astral Rod",ID=5,Price=1000000},
            {Name="Ares Rod",ID=126,Price=3000000},{Name="Angler Rod",ID=168,Price=8000000}, {Name="Hazmat Rod",ID=256,Price=1380000},{Name="Angler Rod",ID=168,Price=8000000},{Name = "Bamboo Rod", ID = 258, Price = 12000000}
        },
        ["Bobbers"] = {
            {Name="Starter Bait", ID=1, Price=0},
            {Name="Luck Bait", ID=2, Price=1000},
            {Name="Midnight Bait", ID=3, Price=3000},
            {Name="Royal Bait", ID=4, Price=425000},
            {Name="Chroma Bait", ID=6, Price=290000}, 
            {Name="Dark Matter Bait", ID=8, Price=630000}, 
            {Name="Topwater Bait", ID=10, Price=100},
            {Name="Corrupt Bait", ID=15, Price=1148484},   
            {Name="Aether Bait", ID=16, Price=3700000},
            {Name="Nature Bait", ID=17, Price=83500},
            {Name="Floral Bait", ID=20, Price=4000000},
            {Name="Singularity Bait", ID=18, Price=8200000},
        }
    }
    
    local ROD_DELAYS = {
        [79]=4.6, [76]=4.35, [85]=4.2, [77]=4.35, [78]=3.85, [4]=3.5, [80]=2.7,
        [6]=2.3, [7]=2.2, [255]=2.2,[256]=1.9, [5]=1.85, [126]=1.7, [168]=1.6, [169]=1.2, [257]=1, [559]=1
    }
    local DEFAULT_ROD_DELAY = 3.85
    local CURRENT_KAITUN_DELAY = DEFAULT_ROD_DELAY

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

    local function ForceResetAndTeleport(targetPos, targetLook)
        local plr = game.Players.LocalPlayer
        pcall(function() RF_UpdateAutoFishingState:InvokeServer(false) end)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then plr.Character.Humanoid.Health = 0 end
        plr.CharacterAdded:Wait()
        local newChar = plr.Character or plr.CharacterAdded:Wait()
        local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
        task.wait(1)
        if hrp and targetPos then TeleportToLookAt(targetPos, targetLook or Vector3.new(0,0,-1)) end
        task.wait(0.5)
        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
    end

    local function GetRodPriceByID(id)
        for _, item in ipairs(ShopItems["Rods"]) do if item.ID == tonumber(id) then return item.Price end end
        return 0
    end
    
    local function GetBaitInfo(id)
        id = tonumber(id)
        for _, item in ipairs(ShopItems["Bobbers"]) do 
            if item.ID == id then 
                return item.Name, item.Price 
            end 
        end
        return "Unknown Bait (ID:"..id..")", 0
    end

    -- =================================================================
    -- [LOGIC] GEAR SELECTION (ROD & BAIT - FIX ID DETECTION)
    -- =================================================================
    local function EquipBestGear()
        local replion = GetPlayerDataReplion()
        if not replion then return DEFAULT_ROD_DELAY end
        local s, d = pcall(function() return replion:GetExpect("Inventory") end)
        if not s or not d then return DEFAULT_ROD_DELAY end

        -- 1. BEST ROD (UUID)
        local bestRodUUID, bestRodPrice, bestRodId = nil, -1, nil
        if d["Fishing Rods"] then
            for _, r in ipairs(d["Fishing Rods"]) do
                local p = GetRodPriceByID(r.Id)
                if tonumber(r.Id) == 169 then p = 99999999 end
                if tonumber(r.Id) == 257 then p = 999999999 end
                if tonumber(r.Id) == 559 then p = 9999999999 end
                
                if p > bestRodPrice then bestRodPrice = p; bestRodUUID = r.UUID; bestRodId = tonumber(r.Id) end
            end
        end

        -- 2. BEST BAIT (ID NUMBER)
        local bestBaitId, bestBaitPrice = nil, -1
        local baitList = d["Bait"] or d["Baits"]
        if baitList then
            for _, b in ipairs(baitList) do
                local bName, bPrice = GetBaitInfo(b.Id) 
                
                if bPrice >= bestBaitPrice then 
                    bestBaitPrice = bPrice
                    bestBaitId = tonumber(b.Id) 
                end
            end
        end

        -- 3. EQUIP ACTIONS
        if bestRodUUID then 
            pcall(function() RE_EquipItem:FireServer(bestRodUUID, "Fishing Rods") end) 
        end
        
        if bestBaitId then 
            pcall(function() RE_EquipBait:FireServer(bestBaitId) end) 
        end
        
        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)

        -- 4. DELAY
        CURRENT_KAITUN_DELAY = (bestRodId and ROD_DELAYS[bestRodId]) and ROD_DELAYS[bestRodId] or DEFAULT_ROD_DELAY
        return CURRENT_KAITUN_DELAY
    end

    local function GetCurrentBestGear()
        local replion = GetPlayerDataReplion()
        if not replion then return "Loading...", "Loading...", 0 end
        local s, d = pcall(function() return replion:GetExpect("Inventory") end)
        
        local bR, hRP = "None", -1
        if d["Fishing Rods"] then
            for _, r in ipairs(d["Fishing Rods"]) do
                local p = GetRodPriceByID(r.Id)
                if tonumber(r.Id) == 169 then p = 99999999 end
                if tonumber(r.Id) == 257 then p = 999999999 end
                if tonumber(r.Id) == 559 then p = 9999999999 end
                if p > hRP then 
                    hRP = p
                    local data = ItemUtility:GetItemData(r.Id)
                    bR = data and data.Data.Name or "Unknown"
                end
            end
        end

        local bB, hBP = "None", -1
        local bList = d["Bait"] or d["Baits"]
        if bList then
            for _, b in ipairs(bList) do
                local bName, bPrice = GetBaitInfo(b.Id)
                
                if bPrice >= hBP then 
                    hBP = bPrice
                    bB = bName
                end
            end
        end
        return bR, bB, hRP
    end

    -- =================================================================
    -- [LOGIC] BAIT BUYING STRATEGY (UPDATED: MIDNIGHT LIMIT & SMART CHECK)
    -- =================================================================
    local function ManageBaitPurchases(currentCoins, nextRodTargetPrice)
        if not RF_PurchaseBait then return end
        
        local replion = GetPlayerDataReplion()
        local inv = replion and replion:GetExpect("Inventory")
        local baitList = inv and (inv["Bait"] or inv["Baits"]) or {}

        -- 1. Cek Bait Terbaik yang Dimiliki Saat Ini
        local highestOwnedBaitPrice = 0
        local hasLuckBait = false     -- ID 2
        local hasMidnightBait = false -- ID 3

        for _, b in ipairs(baitList) do
            local _, price = GetBaitInfo(b.Id)
            if price > highestOwnedBaitPrice then
                highestOwnedBaitPrice = price
            end
            
            if tonumber(b.Id) == 2 then hasLuckBait = true end
            if tonumber(b.Id) == 3 then hasMidnightBait = true end
        end

        -- 2. STOP BUYING Jika sudah punya bait di atas Midnight (Price > 3000)
        -- Ini mencegah downgrade equip atau buang duit kalau lu udah punya Corrupt/Floral
        if highestOwnedBaitPrice > 3000 then
            return 
        end

        -- 3. LOGIC FARMING BARENGAN (Prioritas Bait Murah untuk Multiplier)
        
        -- Target 1: Luck Bait (Harga 1000)
        if not hasLuckBait and not hasMidnightBait then
            if currentCoins >= 1000 then
                pcall(function() RF_PurchaseBait:InvokeServer(2) end)
                WindUI:Notify({ Title = "Kaitun Strategy", Content = "Membeli Luck Bait (Multiplier Boost)", Duration = 2, Icon = "shopping-cart" })
            end
            return -- Fokus beli ini dulu sebelum lanjut
        end

        -- Target 2: Midnight Bait (Harga 3000)
        if not hasMidnightBait then
            -- Langsung beli jika uang cukup (tidak peduli target rod, karena bait ini murah & penting)
            if currentCoins >= 3000 then
                pcall(function() RF_PurchaseBait:InvokeServer(3) end)
                WindUI:Notify({ Title = "Membeli Midnight Bait", Duration = 2, Icon = "shopping-cart" })
            end
            return
        end
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

    local function EnsureQuestListOpen()
        local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local questRoot = playerGui:FindFirstChild("QuestList", true)
        if not questRoot then return end
        
        -- QuestList bisa berupa Folder/Frame (bukan ScreenGui), jadi cek properti aman.
        if questRoot:IsA("ScreenGui") and questRoot.Enabled ~= nil then
            questRoot.Enabled = true
        elseif questRoot.Visible ~= nil then
            questRoot.Visible = true
        end
        
        local background = questRoot:FindFirstChild("Background", true)
        if background and background.Visible ~= nil then
            background.Visible = true
        end
        
        task.wait(0.1)
    end

    local function GetDiamondProgressSafe()
        local data = {
            Header = "Loading...",
            Q1={Text="...",Done=false}, Q2={Text="...",Done=false}, Q3={Text="...",Done=false},
            Q4={Text="...",Done=false}, Q5={Text="...",Done=false}, Q6={Text="...",Done=false},
            AllDone=false, BoardFound=false
        }
        local npcFolder = workspace:FindFirstChild("NPC")
        local researcher = npcFolder and npcFolder:FindFirstChild("Diamond Researcher")
        local tracker = researcher and researcher:FindFirstChild("Tracker - Diamond Researcher", true)
        local board = nil
        if tracker and tracker.FindFirstChild then
            board = tracker:FindFirstChild("Board") or tracker
        end
        if board and board:FindFirstChild("Gui") and board.Gui:FindFirstChild("Content") then
            data.BoardFound = true
            pcall(function()
                local c = board.Gui.Content
                data.Header = c.Header.ContentText ~= "" and c.Header.ContentText or c.Header.Text
                local function proc(lbl)
                    if not lbl then return {Text="...",Done=false} end
                    local t = lbl.ContentText~="" and lbl.ContentText or lbl.Text
                    return {Text=t, Done=string.find(t, "100%%")~=nil}
                end
                data.Q1 = proc(c.Label1); data.Q2 = proc(c.Label2); data.Q3 = proc(c.Label3)
                data.Q4 = proc(c.Label4); data.Q5 = proc(c.Label5); data.Q6 = proc(c.Label6)
                if data.Q1.Done and data.Q2.Done and data.Q3.Done and data.Q4.Done and data.Q5.Done and data.Q6.Done then
                    data.AllDone = true
                end
            end)
            return data
        end

        -- Fallback: read from Quest UI in PlayerGui (QuestList)
        if EnsureQuestListOpen then
            EnsureQuestListOpen()
        end
        local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        local questRoot = playerGui and playerGui:FindFirstChild("QuestList")
        local background = questRoot and questRoot:FindFirstChild("Background")
        local content = background and background:FindFirstChild("Content")
        local rightPanel = content and content:FindFirstChild("Right")
        if rightPanel then
            local entries = {}
            local list = rightPanel:FindFirstChild("List")
            if list then
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("Frame") and child.Visible then
                        local desc = child:FindFirstChild("Desc")
                        if desc and desc:IsA("TextLabel") and desc.Visible then
                            table.insert(entries, {template = child, desc = desc})
                        end
                    end
                end
            end
            
            if #entries == 0 then
                for _, d in ipairs(rightPanel:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Name == "Desc" and d.Visible then
                        table.insert(entries, {template = d.Parent, desc = d})
                    end
                end
            end
            
            if #entries == 0 then
                for _, d in ipairs(rightPanel:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Visible then
                        local t = d.ContentText ~= "" and d.ContentText or d.Text
                        if t and (t:find("Catch") or t:find("Bring") or t:find("Own") or t:find("PERFECT")) then
                            table.insert(entries, {template = d.Parent, desc = d})
                        end
                    end
                end
            end
            
            if #entries > 0 then
                table.sort(entries, function(a, b)
                    local ao = a.template and a.template.LayoutOrder or 0
                    local bo = b.template and b.template.LayoutOrder or 0
                    if ao == bo then
                        return a.desc.AbsolutePosition.Y < b.desc.AbsolutePosition.Y
                    end
                    return ao < bo
                end)
                
                local function NormalizeQuestText(text)
                    if not text then return "" end
                    -- Strip rich text tags and trim whitespace
                    local cleaned = text:gsub("<[^>]+>", "")
                    cleaned = cleaned:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                    return cleaned
                end

                local function procFromLabel(entry)
                    local lbl = entry.desc
                    local rawText = lbl.ContentText ~= "" and lbl.ContentText or lbl.Text
                    local t = NormalizeQuestText(rawText)
                    local done = false
                    local parent = entry.template or lbl.Parent
                    local completed = parent and parent:FindFirstChild("Completed")
                    if not completed and parent and parent.Parent then
                        completed = parent.Parent:FindFirstChild("Completed")
                    end
                    if completed and completed.Visible then
                        done = true
                    end
                    
                    -- Fallback: cek progress bar jika ada
                    if not done and parent then
                        local barFrame = parent:FindFirstChild("BarFrame")
                        if not barFrame and parent.Parent then
                            barFrame = parent.Parent:FindFirstChild("BarFrame")
                        end
                        if barFrame then
                            for _, child in ipairs(barFrame:GetChildren()) do
                                if child:IsA("Frame") and child.Size and child.Size.X and child.Size.X.Scale then
                                    if child.Size.X.Scale >= 0.99 then
                                        done = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    return {Text = t or "...", Done = done}
                end
                
                local leftList = content and content:FindFirstChild("Left") and content.Left:FindFirstChild("List")
                local leftItem = leftList and leftList:GetChildren()[11]
                if leftItem and leftItem:FindFirstChild("Desc") then
                    data.Header = leftItem.Desc.Text
                else
                    data.Header = "Diamond Researcher (UI)"
                end
                data.Q1 = procFromLabel(entries[1])
                data.Q2 = procFromLabel(entries[2])
                data.Q3 = procFromLabel(entries[3])
                data.Q4 = procFromLabel(entries[4])
                data.Q5 = procFromLabel(entries[5])
                data.Q6 = procFromLabel(entries[6])
                data.BoardFound = true
                
                -- Override: "Own an Element Rod" berdasarkan inventory
                local function HasElementRod()
                    local replion = GetPlayerDataReplion()
                    if not replion then return false end
                    local ok, inv = pcall(function() return replion:GetExpect("Inventory") end)
                    if not ok or not inv or not inv["Fishing Rods"] then return false end
                    for _, rod in ipairs(inv["Fishing Rods"]) do
                        if tonumber(rod.Id) == 257 then
                            return true
                        end
                    end
                    return false
                end
                
                local hasElement = HasElementRod()
                for _, q in ipairs({data.Q1, data.Q2, data.Q3, data.Q4, data.Q5, data.Q6}) do
                    if q and q.Text then
                        local qt = NormalizeQuestText(q.Text):lower()
                        if qt:find("own an element rod") or (qt:find("element") and qt:find("rod")) then
                            q.Done = hasElement
                        end
                    end
                end
                
                if data.Q1.Done and data.Q2.Done and data.Q3.Done and data.Q4.Done and data.Q5.Done and data.Q6.Done then
                    data.AllDone = true
                end
            end
        end
        return data
    end


    local function GetDiamondResearcherPart()
        local npcFolder = workspace:FindFirstChild("NPC")
        local researcher = npcFolder and npcFolder:FindFirstChild("Diamond Researcher")
        if not researcher then return nil end
        return researcher:FindFirstChild("Head") or researcher:FindFirstChildWhichIsA("BasePart")
    end

    local function TryUseDiamondResearcherPrompt()
        local npcFolder = workspace:FindFirstChild("NPC")
        local researcher = npcFolder and npcFolder:FindFirstChild("Diamond Researcher")
        if not researcher then return false end
        local ok = false
        for _, desc in ipairs(researcher:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                if fireproximityprompt then
                    pcall(function() fireproximityprompt(desc) end)
                end
                ok = true
            end
        end
        return ok
    end

    local function FindInventoryItemById(itemId, variantId)
        local replion = GetPlayerDataReplion()
        if not replion then return nil end
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData.Items then return nil end
        
        for _, item in ipairs(inventoryData.Items) do
            if tonumber(item.Id) == itemId then
                if variantId == nil or (item.Metadata and tonumber(item.Metadata.VariantId) == variantId) then
                    return item.UUID
                end
            end
        end
        return nil
    end

    local function GetNextDiamondObjectiveText(p)
        if not p then return nil end
        for _, q in ipairs({p.Q1, p.Q2, p.Q3, p.Q4, p.Q5, p.Q6}) do
            if q and not q.Done then
                return q.Text
            end
        end
        return nil
    end

    local function HasRodById(rodId)
        local replion = GetPlayerDataReplion()
        if not replion then return false end
        local ok, inv = pcall(function() return replion:GetExpect("Inventory") end)
        if not ok or not inv or not inv["Fishing Rods"] then return false end
        for _, rod in ipairs(inv["Fishing Rods"]) do
            if tonumber(rod.Id) == rodId then
                return true
            end
        end
        return false
    end

    local function HasSecretFishAt(locationName)
        local replion = GetPlayerDataReplion()
        if not replion then return false end
        local ok, inv = pcall(function() return replion:GetExpect("Inventory") end)
        if not ok or not inv or not inv.Items then return false end
        
        for _, item in ipairs(inv.Items) do
            local rarity = item.Metadata and item.Metadata.Rarity or "Unknown"
            if tostring(rarity):upper() == "SECRET" then
                local location = nil
                if item.Metadata then
                    location = item.Metadata.Location or item.Metadata.Zone or item.Metadata.Region or item.Metadata.FishingArea or item.Metadata.Area
                end
                if location and tostring(location):lower():find(locationName:lower()) then
                    return true
                end
            end
        end
        return false
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

    local function GetLowestWeightSecrets(limit)
        local secrets = {}
        local r = GetPlayerDataReplion() if not r then return {} end
        local s, d = pcall(function() return r:GetExpect("Inventory") end)
        if s and d.Items then
            for _, item in ipairs(d.Items) do
                local r = item.Metadata and item.Metadata.Rarity or "Unknown"
                if r:upper() == "SECRET" and item.Metadata and item.Metadata.Weight then
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

    -- =================================================================
    -- [UI] KAITUN OVERLAY (FIX Z-INDEX)
    -- =================================================================
    local function CreateKaitunUI()
        local old = game.CoreGui:FindFirstChild("HookIDKaitunStats")
        if old then old:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "HookIDKaitunStats"
        sg.Parent = game.CoreGui
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = -50 
        
        local mf = Instance.new("Frame")
        mf.Size = UDim2.new(1,0,1,0)
        mf.BackgroundColor3 = Color3.new(0,0,0)
        mf.BackgroundTransparency = 0.35
        mf.Parent = sg

        local function txt(t,y,c,s)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1,0,0.05,0)
            l.Position = UDim2.new(0,0,y,0)
            l.BackgroundTransparency = 1
            l.Text = t
            l.TextColor3 = c or Color3.new(1,1,1)
            l.Font = Enum.Font.GothamBold
            l.TextSize = s or 24
            l.TextStrokeTransparency = 0.5
            l.Parent = mf
            return l
        end
        
        txt("KAITUN HookID (PREMIUM)", 0.2, Color3.fromRGB(255,0,255), 35)
        local lLC = txt("Last Catch: None", 0.3, Color3.fromRGB(0,255,255))
        local lCoins = txt("Coins: ...", 0.4, Color3.fromRGB(255,215,0))
        local lGear = txt("Best Rod: ... | Best Bait: ...", 0.45) 
        local lStat = txt("Status: Idle", 0.55, Color3.fromRGB(0,255,127))
        local lQuest = txt("", 0.65, Color3.fromRGB(255,100,100))
        lQuest.TextScaled = true; lQuest.Size = UDim2.new(0.8,0,0.08,0); lQuest.Position = UDim2.new(0.1,0,0.65,0)

        return {Gui=sg, Labels={Coins=lCoins, LastCatch=lLC, Gear=lGear, Status=lStat, Quest=lQuest}}
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
    -- [MAIN] KAITUN LOOP
    -- =================================================================
    local function RunKaitunLogic()
        if KAITUN_THREAD then task.cancel(KAITUN_THREAD) end
        if KAITUN_AUTOSELL_THREAD then task.cancel(KAITUN_AUTOSELL_THREAD) end
        if KAITUN_EQUIP_THREAD then task.cancel(KAITUN_EQUIP_THREAD) end
        if KAITUN_CATCH_CONN then KAITUN_CATCH_CONN:Disconnect() end

        local uiData = CreateKaitunUI()
        KAITUN_OVERLAY = uiData.Gui
        local lastDiamondStage = nil

        -- Catch Listener
        if RE_ObtainedNewFishNotification then
            KAITUN_CATCH_CONN = RE_ObtainedNewFishNotification.OnClientEvent:Connect(function(id, meta)
                local name = "Unknown"
                if ItemUtility then 
                    local d = ItemUtility:GetItemData(id) 
                    if d then name = d.Data.Name end
                end
                uiData.Labels.LastCatch.Text = string.format("Last Catch: %s (%.1fkg)", name, meta.Weight or 0)
            end)
        end

        -- Auto Sell
        KAITUN_AUTOSELL_THREAD = task.spawn(function()
            while KAITUN_ACTIVE do pcall(function() RF_SellAllItems:InvokeServer() end) task.wait(30) end
        end)

        -- Auto Equip
        KAITUN_EQUIP_THREAD = task.spawn(function()
            local lc = 0
            CURRENT_KAITUN_DELAY = EquipBestGear()
            while KAITUN_ACTIVE do
                pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                if lc % 20 == 0 then EquipBestGear() end -- Re-check gear every 2s
                lc = lc + 1
                task.wait(0.1)
            end
        end)

        -- Main Progression
        KAITUN_THREAD = task.spawn(function()
            -- [CONFIG HARGA]
            local luckPrice = 325       -- Step 1 (NEW)
            local midPrice = 50000      -- Step 2
            local steamPrice = 215000   -- Step 3
            local astralPrice = 1000000 -- Step 4
            
            local currentTarget = "None"
            
            while KAITUN_ACTIVE do
                local r = GetPlayerDataReplion()
                local coins = 0
                if r then 
                    coins = r:Get("Coins") or 0 
                    if coins == 0 then
                         local s, c = pcall(function() return require(game:GetService("ReplicatedStorage").Modules.CurrencyUtility.Currency) end)
                         if s and c then coins = r:Get(c["Coins"].Path) or 0 end
                    end
                end

                local bRod, bBait, bRodPrice = GetCurrentBestGear()
                uiData.Labels.Coins.Text = string.format("Coins: %s", coins)
                uiData.Labels.Gear.Text = string.format("Rod: %s | Bait: %s", bRod, bBait)

                -- [LOGIKA STEP BARU]
                local step = 0
                local targetPrice = 0
                
                -- Step 1: Luck Rod
                if bRodPrice < luckPrice then 
                    step = 1; targetPrice = luckPrice
                
                -- Step 2: Midnight Rod
                elseif bRodPrice < midPrice then 
                    step = 2; targetPrice = midPrice
                
                -- Step 3: Steampunk Rod
                elseif bRodPrice < steamPrice then 
                    step = 3; targetPrice = steamPrice
                
                -- Step 4: Astral Rod
                elseif bRodPrice < astralPrice then 
                    step = 4; targetPrice = astralPrice
                
                -- Step 5: Ghostfin Quest
                elseif bRodPrice < 99999999 then 
                    step = 5 
                
                -- Step 6: Element Quest
                elseif bRodPrice < 999999999 then 
                    step = 6 
                
                -- Step 7: Diamond Quest
                elseif bRodPrice < 9999999999 then
                    step = 7
                
                -- Step 8: Completed
                else 
                    step = 8 
                end 

                -- Bait Strategy (Prioritas Bait tetap jalan)
                ManageBaitPurchases(coins, targetPrice)

                -- [EKSEKUSI STEP]
                if step <= 4 then
                    -- Buying Rods Phase (Luck -> Midnight -> Steampunk -> Astral)
                    local tName = "Unknown"
                    local tId = 0

                    if step == 1 then
                        tName = "Luck Rod"; tId = 79
                    elseif step == 2 then
                        tName = "Midnight Rod"; tId = 80
                    elseif step == 3 then
                        tName = "Steampunk Rod"; tId = 6
                    elseif step == 4 then
                        tName = "Astral Rod"; tId = 5
                    end
                    
                    if coins >= targetPrice then
                        uiData.Labels.Status.Text = "Buying " .. tName
                        ForceResetAndTeleport(nil,nil)
                        pcall(function() RF_PurchaseFishingRod:InvokeServer(tId) end)
                        task.wait(1.5)
                        EquipBestGear()
                    else
                        uiData.Labels.Status.Text = string.format("Farming for %s (%d/%d)", tName, coins, targetPrice)
                        local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        
                        -- Logic Farming: Jika uang masih dikit (untuk Luck Rod), farm di tempat aman (Docks) atau Enchant Room
                        -- Disini kita set ke Enchant Room default karena aman
                        if hrp and (hrp.Position - ENCHANT_ROOM_POS).Magnitude > 10 then
                            TeleportToLookAt(ENCHANT_ROOM_POS, ENCHANT_ROOM_LOOK)
                            task.wait(0.5)
                        end
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    end

                elseif step == 5 then
                    -- Ghostfin Phase (Sama seperti sebelumnya)
                    uiData.Labels.Status.Text = "Auto Quest: Ghostfin Rod"
                    local p = GetGhostfinProgressSafe()
                    
                    if not p.BoardFound then
                        uiData.Labels.Quest.Text = "Loading Board..."
                        TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK)
                        task.wait(2)
                    else
                        if p.AllDone then
                            uiData.Labels.Quest.Text = "Completed! Buying Ghostfin..."
                            ForceResetAndTeleport(nil,nil)
                            pcall(function() RF_PurchaseFishingRod:InvokeServer(169) end)
                            task.wait(1.5)
                            EquipBestGear()
                        else
                            local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            uiData.Labels.Quest.Text = not p.Q1.Done and p.Q1.Text or p.Q2.Text
                            
                            if not p.Q1.Done then
                                if (hrp.Position - TREASURE_ROOM_POS).Magnitude > 15 then TeleportToLookAt(TREASURE_ROOM_POS, TREASURE_ROOM_LOOK) task.wait(0.5) end
                                RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                            else
                                if (hrp.Position - SISYPHUS_POS).Magnitude > 15 then TeleportToLookAt(SISYPHUS_POS, SISYPHUS_LOOK) task.wait(0.5) end
                                RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                            end
                        end
                    end
                    
                elseif step == 6 then
                    -- === ELEMENT QUEST (Sama seperti sebelumnya) ===
                    uiData.Labels.Status.Text = "Auto Quest: Element Rod"
                    local p = GetElementProgressSafe()

                    if not p.BoardFound then
                        uiData.Labels.Quest.Text = "Mencari Papan Element..."
                        TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK)
                        task.wait(2)
                    else
                        local currentTaskText = "Quest Complete!"
                        
                        if not p.Q2.Done then currentTaskText = "Current: " .. p.Q2.Text
                        elseif not p.Q3.Done then
                            local missingLever = nil
                            for _, n in ipairs(ArtifactOrder) do 
                                if not IsLeverUnlocked(n) then missingLever = n break end 
                            end
                            
                            if missingLever then
                                if HasArtifactItem(missingLever) then 
                                    currentTaskText = "Current: MEMASANG " .. ArtifactData[missingLever].LeverName
                                else 
                                    currentTaskText = "Current: MENCARI " .. ArtifactData[missingLever].ItemName 
                                end
                            else 
                                currentTaskText = "Current: " .. p.Q3.Text 
                            end
                        elseif not p.Q4.Done then currentTaskText = "Current: Sacrifice Secret Fish" end
                        
                        uiData.Labels.Quest.Text = currentTaskText

                        if p.AllDone then
                            uiData.Labels.Status.Text = "Element Selesai! Membeli..."
                            -- Logic beli Element Rod (ID 257) - Manual function karena di shop ga ada tombol direct
                            pcall(function() RF_PurchaseFishingRod:InvokeServer(257) end) 
                            task.wait(1.5)
                            EquipBestGear()
                        else
                            local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            
                            -- [SUB-QUEST 1] Catch Fish in Jungle
                            if not p.Q2.Done then
                                if (hrp.Position - ANCIENT_JUNGLE_POS).Magnitude > 15 then 
                                    TeleportToLookAt(ANCIENT_JUNGLE_POS, ANCIENT_JUNGLE_LOOK) 
                                    task.wait(0.5) 
                                end
                                RunQuestInstantFish(CURRENT_KAITUN_DELAY)

                            -- [SUB-QUEST 2] Unlock Levers
                            elseif not p.Q3.Done then
                                local missingLever = nil
                                for _, n in ipairs(ArtifactOrder) do 
                                    if not IsLeverUnlocked(n) then missingLever = n break end 
                                end

                                if missingLever then
                                    local artData = ArtifactData[missingLever]
                                    if HasArtifactItem(missingLever) then
                                        uiData.Labels.Status.Text = "MEMASANG: " .. missingLever
                                        TeleportToLookAt(artData.FishingPos.Pos, artData.FishingPos.Look)
                                        if hrp then hrp.Anchored = true end
                                        task.wait(0.5)
                                        pcall(function() RF_PlaceLeverItem:FireServer(missingLever) end)
                                        task.wait(2.0)
                                        if hrp then hrp.Anchored = false end
                                    else
                                        uiData.Labels.Status.Text = "FARMING: " .. missingLever
                                        if (hrp.Position - artData.FishingPos.Pos).Magnitude > 10 then
                                            TeleportToLookAt(artData.FishingPos.Pos, artData.FishingPos.Look)
                                            task.wait(0.5)
                                        else
                                            RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                                            task.wait(0.1) 
                                        end
                                    end
                                else
                                    -- Bug visual fix
                                    if (hrp.Position - SACRED_TEMPLE_POS).Magnitude > 15 then 
                                        TeleportToLookAt(SACRED_TEMPLE_POS, SACRED_TEMPLE_LOOK) 
                                        task.wait(0.5) 
                                    end
                                    RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                                end

                            -- [SUB-QUEST 3] Sacrifice Secret Fish
                            elseif not p.Q4.Done then
                                local trash = GetLowestWeightSecrets(1)
                                if #trash > 0 then
                                    TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK)
                                    local r = GetPlayerDataReplion()
                                    if r then
                                        local e = r:GetExpect("EquippedItems")
                                        for _, u in ipairs(e) do pcall(function() RE_UnequipItem:FireServer(u) end) end
                                    end
                                    task.wait(0.5)
                                    pcall(function() RE_EquipItem:FireServer(trash[1], "Fish") end)
                                    task.wait(0.5)
                                    pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
                                    task.wait(0.5)
                                    pcall(function() RF_CreateTranscendedStone:InvokeServer() end)
                                    task.wait(2)
                                else
                                    uiData.Labels.Status.Text = "Farming Secret Fish..."
                                    TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK) 
                                    RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                                end
                            end
                        end
                    end

                elseif step == 7 then
                    -- === DIAMOND QUEST (inventory-based) ===
                    uiData.Labels.Status.Text = "Auto Quest: Diamond Rod"
                    
                    local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    
                    -- 1) Pastikan sudah punya Element Rod (prasyarat)
                    if not HasRodById(257) then
                        local stage = "Need Element Rod"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Need: Own an Element Rod"
                        uiData.Labels.Status.Text = "Diamond Quest: Wait Element Rod"
                        task.wait(1)
                    
                    -- 2) Secret fish Coral Reefs
                    elseif not HasSecretFishAt("Coral Reefs") then
                        local stage = "Secret Coral Reefs"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Catch a SECRET fish at Coral Reefs"
                        uiData.Labels.Status.Text = "Diamond Quest: Coral Reefs (SECRET)"
                        if hrp and (hrp.Position - CORAL_REEF_POS).Magnitude > 15 then
                            TeleportToLookAt(CORAL_REEF_POS, CORAL_REEF_LOOK)
                            task.wait(0.5)
                        end
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    
                    -- 3) Secret fish Tropical Grove
                    elseif not HasSecretFishAt("Tropical Grove") then
                        local stage = "Secret Tropical Grove"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Catch a SECRET fish at Tropical Grove"
                        uiData.Labels.Status.Text = "Diamond Quest: Tropical Grove (SECRET)"
                        if hrp and (hrp.Position - TROPICAL_GROVE_POS).Magnitude > 15 then
                            TeleportToLookAt(TROPICAL_GROVE_POS, TROPICAL_GROVE_LOOK)
                            task.wait(0.5)
                        end
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    
                    -- 4) Mutated Gemstone Ruby
                    elseif not FindInventoryItemById(243, 3) then
                        local stage = "Find Gemstone Ruby (mutated)"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Bring Lary a mutated Gemstone Ruby"
                        uiData.Labels.Status.Text = "Cari Gemstone Ruby (mutated)"
                        if hrp and (hrp.Position - RUBY_POS).Magnitude > 15 then
                            TeleportToLookAt(RUBY_POS, RUBY_LOOK)
                            task.wait(0.5)
                        end
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    
                    -- 5) Lochness Monster
                    elseif not FindInventoryItemById(228, nil) then
                        local stage = "Find Lochness Monster"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Bring Lary a Lochness Monster"
                        uiData.Labels.Status.Text = "Cari Lochness Monster"
                        if hrp and (hrp.Position - LOCHNESS_POS).Magnitude > 15 then
                            TeleportToLookAt(LOCHNESS_POS, LOCHNESS_LOOK)
                            task.wait(0.5)
                        end
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    
                    -- 6) Turn-in items if we have them
                    elseif FindInventoryItemById(243, 3) or FindInventoryItemById(228, nil) then
                        local stage = "Turn-in to Lary"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Turn-in items to Lary"
                        uiData.Labels.Status.Text = "Diamond Quest: Turn-in"
                        local npcPart = GetDiamondResearcherPart()
                        if npcPart then
                            TeleportToLookAt(npcPart.Position, npcPart.CFrame.LookVector)
                            task.wait(0.6)
                            local rubyUUID = FindInventoryItemById(243, 3)
                            if rubyUUID then
                                pcall(function() RE_EquipItem:FireServer(rubyUUID, "Fish") end)
                                task.wait(0.3)
                                pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
                                task.wait(0.3)
                                TryUseDiamondResearcherPrompt()
                            end
                            local lochUUID = FindInventoryItemById(228, nil)
                            if lochUUID then
                                pcall(function() RE_EquipItem:FireServer(lochUUID, "Fish") end)
                                task.wait(0.3)
                                pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
                                task.wait(0.3)
                                TryUseDiamondResearcherPrompt()
                            end
                        end
                    
                    -- 7) Perfect throw 1,000 fish
                    else
                        local stage = "Perfect throw 1000"
                        if lastDiamondStage ~= stage then
                            lastDiamondStage = stage
                            print("[Kaitun Diamond] Stage:", stage)
                        end
                        uiData.Labels.Quest.Text = "Catch 1,000 fish while using PERFECT! throw"
                        uiData.Labels.Status.Text = "Diamond Quest: PERFECT throw"
                        RunQuestInstantFish(CURRENT_KAITUN_DELAY)
                    end
                
                elseif step == 8 then
                    uiData.Labels.Status.Text = "KAITUN COMPLETED!"
                    uiData.Labels.Quest.Text = "All Rods Unlocked."
                    task.wait(5)
                end
                
                task.wait(0.1)
            end
        end)
    end

    -- =================================================================
    -- [UI CONTROLS]
    -- =================================================================
    local kaitun = premium:Section({ Title = "Kaitun Mode", TextSize = 20})
    local tkaitun = Reg("kaitunt",kaitun:Toggle({
        Title = "Start Auto Kaitun (Full AFK)",
        Desc = "Auto Farm -> Buy Rods -> Auto Buy Bait -> Auto Quests.",
        Value = false,
        Callback = function(state)
            KAITUN_ACTIVE = state
            if state then
                WindUI:Notify({ Title = "Kaitun Started",Duration = 3, Icon = "play" })
                RunKaitunLogic()
            else
                if KAITUN_THREAD then task.cancel(KAITUN_THREAD) end
                if KAITUN_AUTOSELL_THREAD then task.cancel(KAITUN_AUTOSELL_THREAD) end
                if KAITUN_EQUIP_THREAD then task.cancel(KAITUN_EQUIP_THREAD) end
                if KAITUN_OVERLAY then KAITUN_OVERLAY:Destroy() end
                pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
                WindUI:Notify({ Title = "Kaitun Stopped", Duration = 2, Icon = "square" })
            end
        end
    }))

premium:Divider()

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
    -- AUTO TOTEM (V3 ENGINE + ANTI-FALL STATE ENFORCER)
    -- =================================================================
    local totem = premium:Section({ Title = "Auto Spawn Totem", TextSize = 20})
    local TOTEM_STATUS_PARAGRAPH = totem:Paragraph({ Title = "Status", Content = "Waiting...", Icon = "clock" })
    
    local TOTEM_DATA = {
        ["Luck Totem"]={Id=1,Duration=3601}, 
        ["Mutation Totem"]={Id=2,Duration=3601}, 
        ["Shiny Totem"]={Id=3,Duration=3601}
    }
    local TOTEM_NAMES = {"Luck Totem", "Mutation Totem", "Shiny Totem"}
    local selectedTotemName = "Luck Totem"
    local currentTotemExpiry = 0
    local AUTO_TOTEM_ACTIVE = false
    local AUTO_TOTEM_THREAD = nil

    local RunService = game:GetService("RunService")

    local stateConnection = nil -- Untuk loop pemaksa state

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

    -- Pastikan 2 baris ini ada di bagian atas Tab Premium (di bawah deklarasi Remote lainnya)
    local RF_EquipOxygenTank = GetRemote(RPath, "RF/EquipOxygenTank")
    local RF_UnequipOxygenTank = GetRemote(RPath, "RF/UnequipOxygenTank")

    -- =================================================================
    -- UI & SINGLE TOGGLE
    -- =================================================================
    local function RunAutoTotemLoop()
        if AUTO_TOTEM_THREAD then task.cancel(AUTO_TOTEM_THREAD) end
        AUTO_TOTEM_THREAD = task.spawn(function()
            while AUTO_TOTEM_ACTIVE do
                local timeLeft = currentTotemExpiry - os.time()
                if timeLeft > 0 then
                    local m = math.floor((timeLeft % 3600) / 60); local s = math.floor(timeLeft % 60)
                    TOTEM_STATUS_PARAGRAPH:SetDesc(string.format("Next Spawn: %02d:%02d", m, s))
                else
                    TOTEM_STATUS_PARAGRAPH:SetDesc("Spawning Single...")
                    local uuid = GetTotemUUID(selectedTotemName)
                    if uuid then
                        pcall(function() RE_SpawnTotem:FireServer(uuid) end)
                        currentTotemExpiry = os.time() + TOTEM_DATA[selectedTotemName].Duration
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
