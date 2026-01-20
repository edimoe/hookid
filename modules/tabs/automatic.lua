do
    local automatic = Window:Tab({
        Icon = "cpu",
        Title = "",
        Locked = false,
    })

    -- Variabel Auto Favorite/Unfavorite
    local autoFavoriteState = false
    local autoFavoriteThread = nil
    local autoUnfavoriteState = false
    local autoUnfavoriteThread = nil
    local selectedRarities = {}
    local selectedItemNames = {}
    local selectedMutations = {}

    local RE_FavoriteItem = GetRemote(RPath, "RE/FavoriteItem")

    -- Helper Function: Get Fish/Item Count
    local function GetFishCount()
        local replion = GetPlayerDataReplion()
        if not replion then return 0 end

        local totalFishCount = 0
        local success, inventoryData = pcall(function()
            return replion:GetExpect("Inventory")
        end)
        
        if not success or not inventoryData or not inventoryData.Items or typeof(inventoryData.Items) ~= "table" then
            return 0
        end

        for _, item in ipairs(inventoryData.Items) do
            local isSellableFish = false

            -- EKSKLUSI GEAR/CRATE/ETC.
            if item.Type == "Fishing Rods" or item.Type == "Boats" or item.Type == "Bait" or item.Type == "Pets" or item.Type == "Chests" or item.Type == "Crates" or item.Type == "Totems" then
                continue
            end
            if item.Identifier and (item.Identifier:match("Artifact") or item.Identifier:match("Key") or item.Identifier:match("Token") or item.Identifier:match("Booster") or item.Identifier:match("hourglass")) then
                continue
            end
            
            -- INKLUSI JIKA ITEM MEMILIKI WEIGHT METADATA
            if item.Metadata and item.Metadata.Weight then
                isSellableFish = true
            elseif item.Type == "Fish" or (item.Identifier and item.Identifier:match("fish")) then
                isSellableFish = true
            end

            if isSellableFish then
                totalFishCount = totalFishCount + (item.Count or 1)
            end
        end
        
        return totalFishCount
    end

   -- =================================================================
    -- ￰ﾟﾒﾰ UNIFIED AUTO SELL SYSTEM (BY DELAY / BY COUNT)
    -- =================================================================
    local sellall = automatic:Section({ Title = "Autosell Fish", TextSize = 20 })

    -- Variabel Global Auto Sell Baru
    local autoSellMethod = "Delay" -- Default: Delay
    local autoSellValue = 50       -- Default Value (Detik atau Jumlah)
    local autoSellState = false
    local autoSellThread = nil

    -- 1. Helper: Unified Loop Logic
    local function RunAutoSellLoop()
        if autoSellThread then task.cancel(autoSellThread) end
        
        autoSellThread = task.spawn(function()
            while autoSellState do
                if autoSellMethod == "Delay" then
                    -- === LOGIC BY DELAY ===
                    if RF_SellAllItems then
                        pcall(function() RF_SellAllItems:InvokeServer() end)
                    end
                    -- Wait sesuai input (minimal 1 detik biar ga crash)
                    task.wait(math.max(autoSellValue, 1))

                elseif autoSellMethod == "Count" then
                    -- === LOGIC BY COUNT ===
                    local currentCount = GetFishCount() -- Pastikan fungsi GetFishCount ada di atas
                    
                    if currentCount >= autoSellValue then
                        if RF_SellAllItems then
                            pcall(function() RF_SellAllItems:InvokeServer() end)
                            WindUI:Notify({ Title = "Auto Sell", Content = "Menjual " .. currentCount .. " items.", Duration = 2, Icon = "dollar-sign" })
                            task.wait(2) -- Cooldown sebentar setelah jual
                        end
                    end
                    task.wait(1) -- Cek setiap 1 detik
                end
            end
        end)
    end

    -- 2. UI Elements
    
    -- Dropdown untuk memilih metode
    local inputElement -- Forward declaration untuk update judul input
    
    local dropMethod = sellall:Dropdown({
        Title = "Select Method",
        Values = {"Delay", "Count"},
        Value = "Delay",
        Multi = false,
        AllowNone = false,
        Callback = function(val)
            autoSellMethod = val
            
            -- Update Judul Input agar user paham
            if inputElement then
                if val == "Delay" then
                    inputElement:SetTitle("Sell Delay (Seconds)")
                    inputElement:SetPlaceholder("e.g. 50")
                else
                    inputElement:SetTitle("Sell at Item Count")
                    inputElement:SetPlaceholder("e.g. 100")
                end
            end
            
            -- Restart loop jika sedang aktif agar logika langsung berubah
            if autoSellState then
                RunAutoSellLoop()
            end
        end
    })

    -- Input Tunggal (Dinamis)
    inputElement = Reg("sellval",sellall:Input({
        Title = "Sell Delay (Seconds)", -- Judul awal
        Value = tostring(autoSellValue),
        Placeholder = "50",
        Icon = "hash",
        Callback = function(text)
            local num = tonumber(text)
            if num then
                autoSellValue = num
            end
        end
    }))

    -- Display Jumlah Ikan Saat Ini (Berguna untuk mode Count)
    local CurrentCountDisplay = sellall:Paragraph({ Title = "Current Fish Count: 0", Icon = "package" })
    task.spawn(function() 
        while true do 
            local shouldUpdate = autoSellState or autoSellMethod == "Count"
            if shouldUpdate and CurrentCountDisplay and GetPlayerDataReplion() then 
                local count = GetFishCount() 
                CurrentCountDisplay:SetTitle("Current Fish Count: " .. tostring(count)) 
                task.wait(1) 
            else 
                task.wait(5) 
            end
        end 
    end)

    -- Toggle Tunggal
    local togSell = Reg("tsell",sellall:Toggle({
        Title = "Enable Auto Sell",
        Desc = "Menjalankan auto sell sesuai metode di atas.",
        Value = false,
        Callback = function(state)
            autoSellState = state
            if state then
                if not RF_SellAllItems then
                    WindUI:Notify({ Title = "Error", Content = "Remote Sell tidak ditemukan.", Duration = 3, Icon = "x" })
                    return false
                end
                
                local msg = (autoSellMethod == "Delay") and ("Setiap " .. autoSellValue .. " detik.") or ("Saat jumlah >= " .. autoSellValue)
                WindUI:Notify({ Title = "Auto Sell ON (" .. autoSellMethod .. ")", Content = msg, Duration = 3, Icon = "check" })
                RunAutoSellLoop()
            else
                WindUI:Notify({ Title = "Auto Sell OFF", Duration = 3, Icon = "x" })
                if autoSellThread then task.cancel(autoSellThread) autoSellThread = nil end
            end
        end
    }))
    
    local favsec = automatic:Section({ Title = "Auto Favorite / Unfavorite", TextSize = 20, })
    
    -- 1. FUNGSI BARU UNTUK MENGAMBIL SEMUA NAMA ITEM (GLOBAL)
    local function getAutoFavoriteItemOptions()
        local itemNames = {}
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local itemsContainer = ReplicatedStorage:FindFirstChild("Items")

        if not itemsContainer then
            return {"(Kontainer 'Items' di ReplicatedStorage Tidak Ditemukan)"}
        end

        for _, itemObject in ipairs(itemsContainer:GetChildren()) do
            local itemName = itemObject.Name
            
            if type(itemName) == "string" and #itemName >= 3 then
                -- Menggunakan string:sub untuk mengecek prefix '!!!'
                local prefix = itemName:sub(1, 3)
                
                if prefix ~= "!!!" then
                    table.insert(itemNames, itemName)
                end
            end
        end

        table.sort(itemNames)
        
        if #itemNames == 0 then
            return {"(Kontainer 'Items' Kosong atau Semua Item '!!!')"}
        end
        
        return itemNames
    end
    
    local cachedItemNames = {"(Loading...)"}
    local function RefreshItemNameOptions(dropdown)
        local names = getAutoFavoriteItemOptions()
        if #names == 0 then
            names = {"(No items found)"}
        end
        cachedItemNames = names
        pcall(function() dropdown:Refresh(names) end)
    end
    
    -- FUNGSI HELPER: Mendapatkan semua item yang memenuhi kriteria (DIFORWARD KE FAVORITE)
    -- GANTI FUNGSI LAMA 'GetItemsToFavorite' DENGAN YANG INI:

local function GetItemsToFavorite()
    local replion = GetPlayerDataReplion()
    if not replion or not ItemUtility or not TierUtility then return {} end

    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {} end

    local itemsToFavorite = {}
    
    -- Cek apakah ada filter yang aktif? (Kalau semua kosong, jangan favorite apa-apa biar aman)
    local isRarityFilterActive = #selectedRarities > 0
    local isNameFilterActive = #selectedItemNames > 0
    local isMutationFilterActive = #selectedMutations > 0

    if not (isRarityFilterActive or isNameFilterActive or isMutationFilterActive) then
        return {} -- Tidak ada filter dipilih, return kosong.
    end

    for _, item in ipairs(inventoryData.Items) do
        -- SKIP JIKA SUDAH FAVORIT
        if item.IsFavorite or item.Favorited then continue end
        
        local itemUUID = item.UUID
        if typeof(itemUUID) ~= "string" or itemUUID:len() < 10 then continue end
        
        local name, rarity = GetFishNameAndRarity(item)
        local mutationFilterString = GetItemMutationString(item)
        
        -- LOGIKA BARU (MULTI-SUPPORT / OR LOGIC)
        local isMatch = false

        -- 1. Cek Rarity (Hanya jika filter rarity dipilih)
        if isRarityFilterActive and table.find(selectedRarities, rarity) then
            isMatch = true
        end

        -- 2. Cek Nama (Hanya jika filter nama dipilih)
        -- Kita pakai 'if not isMatch' biar gak double check kalau udah match di rarity
        if not isMatch and isNameFilterActive and table.find(selectedItemNames, name) then
            isMatch = true
        end

        -- 3. Cek Mutasi (Hanya jika filter mutasi dipilih)
        if not isMatch and isMutationFilterActive and table.find(selectedMutations, mutationFilterString) then
            isMatch = true
        end

        -- Jika SALAH SATU kondisi di atas terpenuhi, masukkan ke daftar favorite
        if isMatch then
            table.insert(itemsToFavorite, itemUUID)
        end
    end

    return itemsToFavorite
end
    
    -- PERBAIKAN LOGIKA UNFAVORITE: Mendapatkan item yang SUDAH FAVORIT dan MASUK filter (untuk di-unfavorite)
    local function GetItemsToUnfavorite()
        local replion = GetPlayerDataReplion()
        if not replion or not ItemUtility or not TierUtility then return {} end

        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData.Items then return {} end

        local itemsToUnfavorite = {}
        
        for _, item in ipairs(inventoryData.Items) do
            -- 1. HANYA PROSES ITEM YANG SUDAH FAVORIT
            if not (item.IsFavorite or item.Favorited) then
                continue
            end
            local itemUUID = item.UUID
            if typeof(itemUUID) ~= "string" or itemUUID:len() < 10 then
                continue
            end
            
            -- 2. CHECK APAKAH MASUK KE CRITERIA FILTER YANG DIPILIH
            local name, rarity = GetFishNameAndRarity(item)
            local mutationFilterString = GetItemMutationString(item)
            
            local passesRarity = #selectedRarities > 0 and table.find(selectedRarities, rarity)
            local passesName = #selectedItemNames > 0 and table.find(selectedItemNames, name)
            local passesMutation = #selectedMutations > 0 and table.find(selectedMutations, mutationFilterString)
            
            -- LOGIKA BARU: Unfavorite JIKA item SUDAH FAVORIT DAN MEMENUHI SALAH SATU CRITERIA FILTER.
            local isTargetedForUnfavorite = passesRarity or passesName or passesMutation
            
            if isTargetedForUnfavorite then
                table.insert(itemsToUnfavorite, itemUUID)
            end
        end

        return itemsToUnfavorite
    end

    -- FUNGSI UTAMA: Mengirim Remote untuk Favorite/Unfavorite
    local function SetItemFavoriteState(itemUUID, isFavorite)
        if not RE_FavoriteItem then return false end
        pcall(function() RE_FavoriteItem:FireServer(itemUUID) end)
        return true
    end

    -- LOGIC AUTO FAVORITE LOOP
    local function RunAutoFavoriteLoop()
        if autoFavoriteThread then 
            ThreadManager:Cancel("autoFavoriteThread", false)
            autoFavoriteThread = nil
        end
        
        autoFavoriteThread = SafeSpawnThread("autoFavoriteThread", function()
            local waitTime = CONSTANTS.AutoFavoriteWaitTime
            local actionDelay = CONSTANTS.AutoFavoriteActionDelay
            
            while autoFavoriteState do
                local itemsToFavorite = GetItemsToFavorite()
                
                if #itemsToFavorite > 0 then
                    WindUI:Notify({ Title = "Auto Favorite", Content = string.format("Mem-favorite %d item...", #itemsToFavorite), Duration = 1, Icon = "star" })
                    for _, itemUUID in ipairs(itemsToFavorite) do
                        SetItemFavoriteState(itemUUID, true)
                        task.wait(actionDelay)
                    end
                end
                
                task.wait(waitTime)
            end
            ThreadManager:Unregister("autoFavoriteThread")
        end, "Auto Favorite Thread")
    end

    -- LOGIC AUTO UNFAVORITE LOOP
    local function RunAutoUnfavoriteLoop()
        if autoUnfavoriteThread then 
            ThreadManager:Cancel("autoUnfavoriteThread", false)
            autoUnfavoriteThread = nil
        end
        
        autoUnfavoriteThread = SafeSpawnThread("autoUnfavoriteThread", function()
            local waitTime = CONSTANTS.AutoFavoriteWaitTime
            local actionDelay = CONSTANTS.AutoFavoriteActionDelay
            
            while autoUnfavoriteState do
                local itemsToUnfavorite = GetItemsToUnfavorite()
                
                if #itemsToUnfavorite > 0 then
                    WindUI:Notify({ Title = "Auto Unfavorite", Content = string.format("Menghapus favorite dari %d item yang dipilih...", #itemsToUnfavorite), Duration = 1, Icon = "x" })
                    for _, itemUUID in ipairs(itemsToUnfavorite) do
                        SetItemFavoriteState(itemUUID, false)
                        task.wait(actionDelay)
                    end
                end
                
                task.wait(waitTime)
            end
            ThreadManager:Unregister("autoUnfavoriteThread")
        end, "Auto Unfavorite Thread")
    end


    -- UI ELEMENTS FAVORITE / UNFAVORITE --
    
    local RarityDropdown = Reg("drer",favsec:Dropdown({
        Title = "by Rarity",
        Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"},
        Multi = true, AllowNone = true, Value = false,
        Callback = function(values) selectedRarities = values or {} end
    }))

    local favItemNameDropdown = Reg("dtem",favsec:Dropdown({
        Title = "by Item Name",
        Values = cachedItemNames,
        Multi = true, AllowNone = true, Value = false,
        Callback = function(values) selectedItemNames = values or {} end -- Multi select untuk nama
    }))
    
    favsec:Button({
        Title = "Refresh Item List",
        Icon = "refresh-ccw",
        Callback = function()
            RefreshItemNameOptions(favItemNameDropdown)
            pcall(function() favItemNameDropdown:Set(false) end)
            selectedItemNames = {}
        end
    })

    local MutationDropdown = Reg("dmut",favsec:Dropdown({
        Title = "by Mutation",
        Values = {"Shiny", "Gemstone", "Corrupt", "Galaxy", "Holographic", "Ghost", "Lightning", "Fairy Dust", "Gold", "Midnight", "Radioactive", "Stone", "Albino", "Sandy", "Acidic", "Disco", "Frozen","Noob"},
        Multi = true, AllowNone = true, Value = false,
        Callback = function(values) selectedMutations = values or {} end
    }))

    -- Toggle Auto Favorite
    local togglefav = Reg("tvav",favsec:Toggle({
        Title = "Enable Auto Favorite",
        Value = false,
        Callback = function(state)
            autoFavoriteState = state
            if state then
                if autoUnfavoriteState then -- Menonaktifkan Unfavorite jika Favorite ON
                    autoUnfavoriteState = false
                    local unfavToggle = automatic:GetElementByTitle("Enable Auto Unfavorite")
                    if unfavToggle and unfavToggle.Set then unfavToggle:Set(false) end
                    if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread) autoUnfavoriteThread = nil end
                end

                if not GetPlayerDataReplion() or not ItemUtility or not TierUtility then WindUI:Notify({ Title = "Error", Content = "Gagal memuat data ItemUtility/TierUtility/Replion.", Duration = 3, Icon = "x" }) return false end
                
                WindUI:Notify({ Title = "Auto Favorite ON!", Duration = 3, Icon = "check", })
                RunAutoFavoriteLoop()
            else
                WindUI:Notify({ Title = "Auto Favorite OFF!", Duration = 3, Icon = "x", })
                if autoFavoriteThread then 
                    ThreadManager:Cancel("autoFavoriteThread", false)
                    autoFavoriteThread = nil
                end
            end
        end
    }))
    
    -- Toggle Auto Unfavorite (LOGIKA YANG DIPERBAIKI)
    local toggleunfav = Reg("tunfa",favsec:Toggle({
        Title = "Enable Auto Unfavorite",
        Value = false,
        Callback = function(state)
            autoUnfavoriteState = state
            if state then
                if autoFavoriteState then -- Menonaktifkan Favorite jika Unfavorite ON
                    autoFavoriteState = false
                    local favToggle = automatic:GetElementByTitle("Enable Auto Favorite")
                    if favToggle and favToggle.Set then favToggle:Set(false) end
                    if autoFavoriteThread then 
                    ThreadManager:Cancel("autoFavoriteThread", false)
                    autoFavoriteThread = nil
                end
                end
                
                if #selectedRarities == 0 and #selectedItemNames == 0 and #selectedMutations == 0 then
                    WindUI:Notify({ Title = "Peringatan!", Content = "Semua filter kosong. Non-aktifkan toggle ini.", Duration = 5, Icon = "alert-triangle" })
                    return false -- Batalkan aksi jika tidak ada filter
                end

                WindUI:Notify({ Title = "Auto Unfavorite ON!", Content = "Menghapus favorit item yang dipilih.", Duration = 3, Icon = "check", })
                RunAutoUnfavoriteLoop()
            else
                WindUI:Notify({ Title = "Auto Unfavorite OFF!", Duration = 3, Icon = "x", })
                if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread) autoUnfavoriteThread = nil end
            end
        end
    }))
    
    automatic:Divider()

    local trade = automatic:Section({ Title = "Auto Trade", TextSize = 20})

    -- Variabel Lokal Auto Trade (Diperbaiki ke Single Target)
    local autoTradeState = false
    local autoTradeThread = nil
    local tradeHoldFavorite = false
    local selectedTradeTargetId = nil
    local selectedTradeItemName = nil
    local selectedTradeRarity = nil
    local tradeDelay = 1.0
    local tradeAmount = 0
    local tradeStopAtCoins = 0
    local isTradeByCoinActive = false

    -- Player Target Dropdown (Diperkuat)
    local PlayerList = {}
    local function GetPlayerOptions()
        local options = {}
        PlayerList = {} -- Reset mapping ID
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(options, player.Name)
                PlayerList[player.Name] = player.UserId
            end
        end
        return options
    end

    local PlayerDropdown
    PlayerDropdown = trade:Dropdown({
        Title = "Pilih Pemain Target",
        Values = GetPlayerOptions(),
        Value = false,
        Multi = false,
        AllowNone = false,
        Callback = function(name) -- Callback menerima SATU nama (atau nil jika 'None')
            -- Handle boolean values (when Set(false) is called)
            if type(name) ~= "string" then
                selectedTradeTargetId = nil
                return
            end
            
            local player = game.Players:FindFirstChild(name)
            
            if player and player.UserId then
                selectedTradeTargetId = player.UserId
                WindUI:Notify({ Title = "Target Dipilih", Content = "Target set: " .. player.Name, Duration = 2, Icon = "user" })
            else
                selectedTradeTargetId = nil
            end
        end
    })

    local listplay = trade:Button({
        Title = "Refresh Player List",
        Icon = "refresh-ccw",
        Callback = function()
            
            local newOptions = GetPlayerOptions()
            
            -- 1. Perbarui nilai di dropdown dengan daftar baru
            pcall(function() PlayerDropdown:Refresh(newOptions) end) -- Gunakan pcall sebagai safety
            
            -- 2. Tunda reset tampilan agar UI sempat memproses SetValues
            task.wait(0.05)
            
            -- 3. Reset tampilan dropdown ke 'None' atau nilai default pertama jika tidak ada
            pcall(function() PlayerDropdown:Set(false) end)
            
            -- 4. Reset ID target (wajib)
            selectedTradeTargetId = nil
            
            -- 5. Berikan notifikasi yang jelas
            if #newOptions > 0 then
                WindUI:Notify({ Title = "List Diperbarui", Content = string.format("%d pemain ditemukan.", #newOptions), Duration = 2, Icon = "check" })
            else
                WindUI:Notify({ Title = "List Diperbarui", Content = "Tidak ada pemain lain di server.", Duration = 2, Icon = "check" })
            end
        end
    })
    
    automatic:Divider()
    
    local tradeItemNameDropdown
    tradeItemNameDropdown = trade:Dropdown({
        Title = "Filter Item Name",
        Values = cachedItemNames,
        Value = false,
        Multi = false,
        AllowNone = true,
        Callback = function(name)
            selectedTradeItemName = name or nil -- Set ke nil jika "None"
        end
    })
    
    trade:Button({
        Title = "Refresh Item List",
        Icon = "refresh-ccw",
        Callback = function()
            RefreshItemNameOptions(tradeItemNameDropdown)
            pcall(function() tradeItemNameDropdown:Set(false) end)
            selectedTradeItemName = nil
        end
    })

    -- 2. Filter Rarity Dropdown (SINGLE SELECT)
    local raretrade = trade:Dropdown({
        Title = "Filter Item Rarity",
        Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Trophy", "Collectible", "DEV", "Default"},
        Value = false,
        Multi = false,
        AllowNone = true,
        Callback = function(rarity)
            selectedTradeRarity = rarity or nil -- Set ke nil jika "None"
        end
    })

    local ToggleCoinStop = trade:Toggle({
        Title = "Stop at Coin Amount",
        Desc = "Berhenti trade jika koin mencapai target.",
        Value = false,
        Callback = function(state) isTradeByCoinActive = state end
    })

    local inputcoint = trade:Input({
        Title = "Target Coin Amount",
        Placeholder = "1000000",
        Value = "0",
        Icon = "dollar-sign",
        Callback = function(val)
            tradeStopAtCoins = tonumber(val) or 0
        end
    })
    
    
    -- 3. Limit Trade Input (Amount)
    local InputAmount = trade:Input({
        Title = "Trade Amount (0 = Unlimited)",
        Value = tostring(tradeAmount),
        Placeholder = "0 (Unlimited)",
        Icon = "hash",
        Callback = function(input)
            local newAmount = tonumber(input)
            if newAmount == nil or newAmount < 0 then
                tradeAmount = 0
            else
                tradeAmount = math.floor(newAmount)
            end
        end
    })

    -- 4. Trade Delay Slider
    local DelaySlider = trade:Slider({
        Title = "Trade Delay (Seconds)",
        Step = 0.1,
        Value = { Min = 0.5, Max = 5.0, Default = tradeDelay },
        Callback = function(value)
            local newDelay = tonumber(value)
            if newDelay and newDelay >= 0.5 then
                tradeDelay = newDelay
            else
                tradeDelay = 1.0
            end
        end
    })


    local function GetItemsToTrade()
        local replion = GetPlayerDataReplion()
        if not replion then return {} end

        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData.Items then return {} end

        local itemsToTrade = {}
        
        for _, item in ipairs(inventoryData.Items) do
            -- [[ LOGIKA HOLD FAVORITE ]]
            local isFavorited = item.IsFavorite or item.Favorited
            if tradeHoldFavorite and isFavorited then
                continue 
            end
            
            if typeof(item.UUID) ~= "string" or item.UUID:len() < 10 then continue end
            
            local name, rarity = GetFishNameAndRarity(item)
            local itemRarity = (rarity and rarity:upper() ~= "COMMON") and rarity or "Default"
            
            -- Filter Logic
            local passesRarity = not selectedTradeRarity or (selectedTradeRarity and itemRarity:upper() == selectedTradeRarity:upper())
            local passesName = not selectedTradeItemName or (name == selectedTradeItemName)
            
            if passesRarity and passesName then
                -- [UPDATE] Masukkan Id dan Metadata juga untuk hitung harga
                table.insert(itemsToTrade, { 
                    UUID = item.UUID, 
                    Name = name, 
                    Rarity = rarity, 
                    Identifier = item.Identifier,
                    Id = item.Id,
                    Metadata = item.Metadata or {}
                })
            end
        end
        return itemsToTrade
    end

    -- Helper: Cek apakah item dengan UUID tertentu masih ada di inventory
    local function IsItemStillInInventory(targetUUID)
        local replion = GetPlayerDataReplion()
        if not replion then return true end -- Asumsikan masih ada biar ga error
        
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData.Items then return true end

        for _, item in ipairs(inventoryData.Items) do
            if item.UUID == targetUUID then
                return true -- Item masih ada!
            end
        end
        return false -- Item sudah hilang (Berhasil Trade)
    end

    -- LOGIC LOOP UTAMA: Run Auto Trade (MENGGUNAKAN SINGLE TARGET ID)
    local function RunAutoTradeLoop()
        if autoTradeThread then task.cancel(autoTradeThread) end
        
        autoTradeThread = task.spawn(function()
            local tradeCount = 0
            local accumulatedValue = 0 -- [BARU] Penghitung total nilai coin yang SUDAH di-trade sesi ini
            local targetId = selectedTradeTargetId
            
            if not targetId or typeof(targetId) ~= "number" then
                WindUI:Notify({ Title = "Trade Gagal", Content = "Pilih Target valid.", Duration = 5, Icon = "x" })
                local toggle = automatic:GetElementByTitle("Enable Auto Trade")
                if toggle and toggle.Set then toggle:Set(false) end
                return
            end

            local RF_InitiateTrade_Local = GetRemote(RPath, "RF/InitiateTrade", 5)
            if not RF_InitiateTrade_Local then return end

            WindUI:Notify({ Title = "Auto Trade ON", Content = "Tracking Value dimulai (0/"..tradeStopAtCoins..")", Duration = 2, Icon = "zap" })

            while autoTradeState do
                -- 1. [LOGIKA BARU] Cek Limit Coin Berdasarkan AKUMULASI TRADE
                if isTradeByCoinActive and tradeStopAtCoins > 0 then
                    if accumulatedValue >= tradeStopAtCoins then
                        WindUI:Notify({ 
                            Title = "Target Value Tercapai!", 
                            Content = string.format("Total Trade: %s coins.", accumulatedValue), 
                            Duration = 5, 
                            Icon = "dollar-sign" 
                        })
                        local toggle = automatic:GetElementByTitle("Enable Auto Trade")
                        if toggle and toggle.Set then toggle:Set(false) end
                        break
                    end
                end

                -- 2. Cek Limit Jumlah Item
                if tradeAmount > 0 and tradeCount >= tradeAmount then
                    WindUI:Notify({ Title = "Limit Item Tercapai", Content = "Batas jumlah item terpenuhi.", Duration = 5, Icon = "stop-circle" })
                    local toggle = automatic:GetElementByTitle("Enable Auto Trade")
                    if toggle and toggle.Set then toggle:Set(false) end
                    break
                end

                -- 3. Ambil Item Target
                local itemsToTrade = GetItemsToTrade()
                
                if #itemsToTrade > 0 then
                    local itemToTrade = itemsToTrade[1]
                    local targetUUID = itemToTrade.UUID
                    
                    -- Hitung Estimasi Harga Item INI
                    local itemBasePrice = 0
                    if ItemUtility then
                        local iData = ItemUtility:GetItemData(itemToTrade.Id)
                        if iData then itemBasePrice = iData.SellPrice or 0 end
                    end
                    local multiplier = itemToTrade.Metadata.SellMultiplier or 1
                    local itemValue = math.floor(itemBasePrice * multiplier)

                    -- Kirim Trade
                    local successCall = pcall(function()
                        RF_InitiateTrade_Local:InvokeServer(targetId, targetUUID)
                    end)

                    if successCall then
                        -- Verifikasi item hilang dari BP
                        local startTime = os.clock()
                        local isTraded = false
                        repeat
                            task.wait(0.5)
                            if not IsItemStillInInventory(targetUUID) then isTraded = true end
                        until isTraded or (os.clock() - startTime > 5)
                        
                        if isTraded then
                            tradeCount = tradeCount + 1
                            
                            -- [BARU] Tambahkan value item ini ke akumulasi
                            accumulatedValue = accumulatedValue + itemValue
                            
                            WindUI:Notify({
                                Title = "Trade Sukses!",
                                Content = string.format("Item: %s\nValue: %d | Total: %d/%d", itemToTrade.Name, itemValue, accumulatedValue, (isTradeByCoinActive and tradeStopAtCoins or 0)),
                                Duration = 2,
                                Icon = "check"
                            })
                            task.wait(tradeDelay)
                        else
                            WindUI:Notify({ Title = "Trade Gagal/Lag", Content = "Item tidak terkirim.", Duration = 2, Icon = "alert-triangle" })
                            task.wait(1.5)
                        end
                    else
                        task.wait(1)
                    end
                else
                    task.wait(2)
                end
            end
            WindUI:Notify({ Title = "Auto Trade Berhenti", Duration = 3, Icon = "x" })
        end)
    end
    
    local togglehold = trade:Toggle({
        Title = "Hold Favorite Items",
        Desc = "Jika ON, item yang di-Favorite tidak akan ikut di-trade.",
        Value = false,
        Callback = function(state)
            tradeHoldFavorite = state
            if state then
                WindUI:Notify({ Title = "Safe Mode", Content = "Item Favorite aman dari Auto Trade.", Duration = 2, Icon = "lock" })
            else
                WindUI:Notify({ Title = "Warning", Content = "Item Favorite bisa ikut ter-trade!", Duration = 2, Icon = "alert-triangle" })
            end
        end
    })

    -- UI Toggle Auto Trade
    local autotrd = trade:Toggle({
        Title = "Enable Auto Trade",
        Icon = "arrow-right-left",
        Value = false,
        Callback = function(state)
            autoTradeState = state
            
            if state then
                -- 1. Validasi Target ID
                if not selectedTradeTargetId or typeof(selectedTradeTargetId) ~= "number" then
                    WindUI:Notify({ Title = "Error", Content = "Pilih pemain target yang valid terlebih dahulu!", Duration = 3, Icon = "alert-triangle" })
                    return false
                end

                -- 2. [FITUR BARU] TELEPORT KE TARGET
                local targetPlayer = game.Players:GetPlayerByUserId(selectedTradeTargetId)
                
                if targetPlayer then
                    local targetChar = targetPlayer.Character
                    local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                    
                    local myChar = LocalPlayer.Character
                    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

                    if targetHRP and myHRP then
                        WindUI:Notify({ Title = "Teleporting...", Content = "Menuju ke posisi " .. targetPlayer.Name, Duration = 2, Icon = "map-pin" })
                        
                        -- Teleport 5 stud di atas target
                        myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 5, 0)
                        
                        -- Freeze sebentar biar loading map (Opsional, 0.5 detik)
                        task.wait(0.5)
                    else
                        WindUI:Notify({ Title = "Teleport Gagal", Content = "Karakter target tidak ditemukan (Mungkin mati/belum load).", Duration = 3, Icon = "alert-triangle" })
                    end
                else
                    WindUI:Notify({ Title = "Teleport Gagal", Content = "Pemain target sudah keluar server.", Duration = 3, Icon = "x" })
                    return false
                end

                -- 3. Jalankan Loop Trade
                RunAutoTradeLoop()
            else
                if autoTradeThread then task.cancel(autoTradeThread) autoTradeThread = nil end
            end
        end
    })


    -- UI Toggle Auto Accept Trade
    local accept = trade:Toggle({
        Title = "Enable Auto Accept Trade",
        Icon = "arrow-right-left",
        Value = false,
        Callback = function(state)
            _G.HookID_AutoAcceptTradeEnabled = state
            
            if state then
                WindUI:Notify({
                    Title = "Auto Accept Trade ON! ￢ﾜﾅ",
                    Content = "Menerima semua permintaan trade secara otomatis.",
                    Duration = 3,
                    Icon = "check"
                })
            else
                WindUI:Notify({
                    Title = "Auto Accept Trade OFF! ￢ﾝﾌ",
                    Content = "Menerima trade secara manual.",
                    Duration = 3,
                    Icon = "x"
                })
            end
        end
    })


    local enchant = automatic:Section({ Title = "Auto Enchant Rod", TextSize = 20,})
    
    -- [UPDATE] DATA HARDCODE RODS UNTUK ENCHANT
    local ENCHANT_ROD_LIST = {
        {Name = "Luck Rod", ID = 79}, {Name = "Carbon Rod", ID = 76}, {Name = "Grass Rod", ID = 85}, 
        {Name = "Demascus Rod", ID = 77}, {Name = "Ice Rod", ID = 78}, {Name = "Lucky Rod", ID = 4}, 
        {Name = "Midnight Rod", ID = 80}, {Name = "Steampunk Rod", ID = 6}, {Name = "Chrome Rod", ID = 7}, 
        {Name = "Flourescent Rod", ID = 255}, {Name = "Astral Rod", ID = 5}, {Name = "Ares Rod", ID = 126}, 
        {Name = "Angler Rod", ID = 168}, {Name = "Ghostfin Rod", ID = 169}, {Name = "Element Rod", ID = 257},
        {Name = "Hazmat Rod", ID = 256}, {Name = "Bamboo Rod", ID = 258}, {Name = "Diamond Rod", ID = 559}
    }

    local function GetHardcodedRodNames()
        local names = {}
        for _, v in ipairs(ENCHANT_ROD_LIST) do
            table.insert(names, v.Name)
        end
        return names
    end

    -- Helper: Cari UUID di inventory berdasarkan ID Rod yang dipilih
    local function GetUUIDByRodID(targetID)
        local replion = GetPlayerDataReplion()
        if not replion then return nil end
        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData["Fishing Rods"] then return nil end

        for _, rod in ipairs(inventoryData["Fishing Rods"]) do
            if tonumber(rod.Id) == targetID then
                return rod.UUID -- Mengembalikan UUID Rod pertama yang cocok dengan ID
            end
        end
        return nil
    end

    local RodDropdown = enchant:Dropdown({
        Title = "Select Rod",
        Desc = "Select type of Rod that you want to enchant.",
        Values = GetHardcodedRodNames(),
        Multi = false,
        AllowNone = true,
        Callback = function(name)
            selectedRodUUID = nil
            -- Cari ID berdasarkan Nama
            for _, v in ipairs(ENCHANT_ROD_LIST) do
                if v.Name == name then
                    -- Cek apakah player punya rod tersebut
                    local foundUUID = GetUUIDByRodID(v.ID)
                    if foundUUID then
                        selectedRodUUID = foundUUID
                        WindUI:Notify({ Title = "Rod Found", Content = "UUID saved for " .. name, Duration = 2, Icon = "check" })
                    else
                        WindUI:Notify({ Title = "Rod Not Found", Content = "You don't have " .. name .. " in inventory.", Duration = 3, Icon = "x" })
                    end
                    break
                end
            end
        end
    })

    -- Tombol Refresh (Cek ulang ketersediaan Rod yang dipilih)
    local rodlist = enchant:Button({
        Title = "Re-Check Selected Rod",
        Icon = "refresh-ccw",
        Callback = function()
            local currentName = RodDropdown.Value
            if currentName then
                -- Trigger callback ulang untuk scan UUID baru
                for _, v in ipairs(ENCHANT_ROD_LIST) do
                    if v.Name == currentName then
                        local foundUUID = GetUUIDByRodID(v.ID)
                        if foundUUID then
                            selectedRodUUID = foundUUID
                            WindUI:Notify({ Title = "Re-Check Success", Content = "UUID Updated.", Duration = 2, Icon = "check" })
                        else
                            selectedRodUUID = nil
                            WindUI:Notify({ Title = "Lost", Content = "Rod not found in inventory.", Duration = 2, Icon = "x" })
                        end
                        break
                    end
                end
            else
                WindUI:Notify({ Title = "Info", Content = "Select Rod in dropdown first.", Duration = 2 })
            end
        end 
    })

    -- Dropdown untuk memilih Enchant Target
    local dropenchant = enchant:Dropdown({
        Title = "Enchant To Apply (stop when reached)",
        Desc = "Select enchant that you want. Auto-roll will stop if one of these enchant is reached.",
        Values = ENCHANT_NAMES,
        Multi = true,
        AllowNone = false,
        Callback = function(names)
            selectedEnchantNames = names or {}
        end
    })

    -- Pilih jenis batu enchant yang dipakai
    local EnchantStoneDropdown = enchant:Dropdown({
        Title = "Select Enchant Stone",
        Desc = "Pilih batu enchant yang akan digunakan.",
        Values = {"Enchant Stone", "Evolved Enchant Stone"},
        Multi = false,
        AllowNone = false,
        Value = "Enchant Stone",
        Callback = function(option)
            if option == "Evolved Enchant Stone" then
                selectedEnchantStoneId = EVOLVED_ENCHANT_STONE_ID or 558
            else
                selectedEnchantStoneId = ENCHANT_STONE_ID or 10
            end
        end
    })

    -- Toggle Auto Enchant
    local autoenc = enchant:Toggle({
        Title = "Enable Auto Enchant",
        Value = false,
        Callback = function(state)
            autoEnchantState = state
            if state then
                if not selectedRodUUID then
                    WindUI:Notify({ Title = "Error", Content = "Select target Rod first.", Duration = 3, Icon = "alert-triangle" })
                    return false
                end
                if #selectedEnchantNames == 0 then
                    WindUI:Notify({ Title = "Error", Content = "Select at least one Enchant target.", Duration = 3, Icon = "alert-triangle" })
                    return false
                end
                
                -- Stone akan dicari di dalam loop RunAutoEnchantLoop
                RunAutoEnchantLoop(selectedRodUUID)
            else
                if autoEnchantThread then task.cancel(autoEnchantThread) autoEnchantThread = nil end
                WindUI:Notify({ Title = "Auto Enchant Disabled!", Duration = 3, Icon = "x",})
            end
        end
    })

-- =================================================================
    -- ￰ﾟﾔﾮ AUTO SECOND ENCHANT & STONE CREATION
    -- =================================================================
    automatic:Divider()
    local enchant2 = automatic:Section({ Title = "Auto Second Enchant & Stone Creation", TextSize = 20})

    -- --- VARIABLES ---
    local makeStoneState = false
    local makeStoneThread = nil
    local secondEnchantState = false
    local secondEnchantThread = nil
    
    local selectedSecretFishUUIDs = {} -- List UUID ikan secret yang dipilih
    local targetStoneAmount = 1 -- Default jumlah batu yang mau dibuat
    
    local TRANSCENDED_STONE_ID = 246
    local SECOND_ALTAR_POS = FishingAreas["Second Enchant Altar"].Pos
    local SECOND_ALTAR_LOOK = FishingAreas["Second Enchant Altar"].Look

    -- Remote Definitions (Lokal untuk section ini)
    local RF_CreateTranscendedStone = GetRemote(RPath, "RF/CreateTranscendedStone")
    local RE_ActivateSecondEnchantingAltar = GetRemote(RPath, "RE/ActivateSecondEnchantingAltar")
    local RE_EquipItem = GetRemote(RPath, "RE/EquipItem")
    local RE_EquipToolFromHotbar = GetRemote(RPath, "RE/EquipToolFromHotbar")

    -- --- HELPER: GET SECRET FISH (FIXED DETECTION) ---
    local function GetSecretFishOptions()
        local options = {}
        local uuidMap = {} -- Mapping Nama -> UUID untuk diproses nanti
        
        local replion = GetPlayerDataReplion()
        if not replion then return {}, {} end

        local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
        if not success or not inventoryData or not inventoryData.Items then return {}, {} end

        for _, item in ipairs(inventoryData.Items) do
            -- PERBAIKAN 1: Deteksi Ikan berdasarkan 'Weight' (Sama seperti Scan Backpack)
            -- Karena semua ikan hasil tangkapan pasti punya Metadata Weight
            local hasWeight = item.Metadata and item.Metadata.Weight
            
            -- Fallback: Cek tipe jika weight tidak terbaca
            local isFishType = item.Type == "Fish" or (item.Identifier and tostring(item.Identifier):lower():find("fish"))
            
            if not hasWeight and not isFishType then continue end

            -- PERBAIKAN 2: Ambil Rarity dan paksa Uppercase agar "Secret" == "SECRET"
            local _, rarity = GetFishNameAndRarity(item)
            
            if not rarity or rarity:upper() ~= "SECRET" then continue end

            -- Ambil Nama yang lebih akurat (Dari ItemUtility jika ada)
            local name = item.Identifier or "Unknown"
            if ItemUtility then
                local itemData = ItemUtility:GetItemData(item.Id)
                if itemData and itemData.Data and itemData.Data.Name then
                    name = itemData.Data.Name
                end
            end

            if item.Metadata and item.Metadata.Weight then
                name = string.format("%s (%.1fkg)", name, item.Metadata.Weight)
            end
            
            -- Tambahkan penanda jika Favorite
            if item.IsFavorite or item.Favorited then
                name = name .. " [￢ﾭﾐ]"
            end

            table.insert(options, name)
            uuidMap[name] = item.UUID
        end
        
        table.sort(options) -- Urutkan abjad biar rapi
        return options, uuidMap
    end

    local secretFishOptions = {"(Click Refresh)"}
    local secretFishUUIDMap = {}

    -- --- HELPER: CEK ENCHANT ID 2 (KHUSUS SECOND ENCHANT) ---
    local function CheckIfSecondEnchantReached(rodUUID)
        local replion = GetPlayerDataReplion()
        local Rods = replion:GetExpect("Inventory")["Fishing Rods"] or {}
        
        local targetRod = nil
        for _, rod in ipairs(Rods) do
            if rod.UUID == rodUUID then
                targetRod = rod
                break
            end
        end

        if not targetRod then return true end -- Stop jika rod hilang
        
        local metadata = targetRod.Metadata or {}
        
        -- PENTING: Cek EnchantId2 (Slot kedua)
        local currentEnchant2 = metadata.EnchantId2
        
        if not currentEnchant2 then return false end -- Belum ada enchant ke-2

        -- Cek apakah enchant ke-2 sesuai target
        for _, targetName in ipairs(selectedEnchantNames) do
            local targetID = ENCHANT_MAPPING[targetName]
            if targetID and currentEnchant2 == targetID then
                return true -- Berhenti: Enchant target tercapai di slot 2
            end
        end

        return false
    end

    -- --- HELPER: CARI TRANSCENDED STONE (ID 246) ---
    local function GetTranscendedStoneUUID()
        local replion = GetPlayerDataReplion()
        if not replion then return nil end
        local inventoryData = replion:GetExpect("Inventory")
        
        if inventoryData and inventoryData.Items then
            for _, item in ipairs(inventoryData.Items) do
                if tonumber(item.Id) == TRANSCENDED_STONE_ID and item.UUID then
                    return item.UUID
                end
            end
        end
        return nil
    end

    -- --- LOGIC 1: MAKE TRANSCENDED STONE ---
    local function RunMakeStoneLoop()
        if makeStoneThread then task.cancel(makeStoneThread) end

        makeStoneThread = task.spawn(function()
            local createdCount = 0
            
            -- 1. Teleport ke Altar dulu biar aman
            TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK)
            task.wait(1)

            while makeStoneState and createdCount < targetStoneAmount do
                -- Ambil list baru (jika ada perubahan inventory)
                local _, currentMap = GetSecretFishOptions()
                local fishToSacrifice = nil
                
                -- Cari ikan pertama yang cocok dengan seleksi user
                for name, uuid in pairs(currentMap) do
                    -- Cek apakah nama ini ada di daftar yang dipilih user (selectedSecretFishUUIDs menyimpan Nama di dropdown logic ini)
                    if table.find(selectedSecretFishUUIDs, name) then
                        fishToSacrifice = uuid
                        break
                    end
                end

                if not fishToSacrifice then
                    WindUI:Notify({ Title = "Finished / Empty", Content = "No target fish left.", Duration = 5, Icon = "check" })
                    break
                end

                -- Proses Pembuatan
                WindUI:Notify({ Title = "Sacrificing...", Content = "Processing fish...", Duration = 1, Icon = "refresh-cw" })

                -- 1. Unequip Semua
                UnequipAllEquippedItems()
                task.wait(0.3)

                -- 2. Equip Ikan
                pcall(function() 
                    RE_EquipItem:FireServer(fishToSacrifice, "Fish") 
                end)
                task.wait(0.5)

                -- 3. Equip ke Hotbar (Slot 2 sesuai request)
                pcall(function() 
                    RE_EquipToolFromHotbar:FireServer(2) 
                end)
                task.wait(0.8) -- Tunggu animasi equip

                -- 4. Create Stone
                local success = pcall(function() 
                    RF_CreateTranscendedStone:InvokeServer() 
                end)

                if success then
                    createdCount = createdCount + 1
                    WindUI:Notify({ Title = "Stone Created!", Content = string.format("Total: %d / %d", createdCount, targetStoneAmount), Duration = 2, Icon = "gem" })
                else
                    WindUI:Notify({ Title = "Failed", Content = "Failed to create stone (Maybe not secret?).", Duration = 2, Icon = "x" })
                end

                task.wait(1.5) -- Cooldown antar pembuatan
            end

            makeStoneState = false
            local toggle = automatic:GetElementByTitle("Start Make Stones")
            if toggle and toggle.Set then toggle:Set(false) end
            
            -- Unequip tool terakhir
            pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
        end)
    end

    -- --- LOGIC 2: SECOND ENCHANT LOOP ---
    local function RunSecondEnchantLoop(rodUUID)
        if secondEnchantThread then task.cancel(secondEnchantThread) end

        secondEnchantThread = task.spawn(function()
            -- 1. Unequip Awal
            UnequipAllEquippedItems()
            task.wait(0.5)

            -- 2. Teleport ke Second Altar
            TeleportToLookAt(SECOND_ALTAR_POS, SECOND_ALTAR_LOOK)
            task.wait(1.5)

            WindUI:Notify({ Title = "Second Enchant Started", Content = "Rolling Slot 2...", Duration = 2, Icon = "sparkles" })

            while secondEnchantState do
                -- 3. Cek Enchant Slot 2
                if CheckIfSecondEnchantReached(rodUUID) then
                    WindUI:Notify({ Title = "GG!", Content = "Second Enchant reached!", Duration = 5, Icon = "check" })
                    break
                end

                -- 4. Cari Transcended Stone (ID 246)
                local stoneUUID = GetTranscendedStoneUUID()
                if not stoneUUID then
                    WindUI:Notify({ Title = "Stone Empty!", Content = "Need Transcended Stone", Duration = 5, Icon = "stop-circle" })
                    break
                end

                -- === ALUR ENCHANT ===
                
                -- 5. Equip Rod
                pcall(function() RE_EquipItem:FireServer(rodUUID, "Fishing Rods") end)
                task.wait(0.2)

                -- 6. Equip Transcended Stone
                pcall(function() RE_EquipItem:FireServer(stoneUUID, "Enchant Stones") end)
                task.wait(0.2)

                -- 7. Equip Stone ke Hotbar (Slot 2)
                pcall(function() RE_EquipToolFromHotbar:FireServer(2) end)
                task.wait(0.3)

                -- 8. Activate Second Altar
                pcall(function() RE_ActivateSecondEnchantingAltar:FireServer() end)

                -- 9. Tunggu (Trade Delay)
                task.wait(tradeDelay)

                -- 10. Unequip
                pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
                task.wait(0.5)
            end

            secondEnchantState = false
            local toggle = automatic:GetElementByTitle("Start Second Enchant")
            if toggle and toggle.Set then toggle:Set(false) end
        end)
    end


    -- --- UI COMPONENTS ---

    -- A. BAGIAN MAKE STONE
    local SecretFishDropdown = enchant2:Dropdown({
        Title = "Select Secret Fish (Sacrifice)",
        Desc = "Select Secret Fish to make Transcended Stone.",
        Values = secretFishOptions,
        Multi = true,
        AllowNone = true,
        Callback = function(values)
            -- Di sini kita simpan Namanya saja, nanti di loop kita cocokan Nama -> UUID map terbaru
            -- karena UUID bisa berubah/item bisa hilang setelah sacrifice
            selectedSecretFishUUIDs = values or {} 
        end
    })

    local butfish = enchant2:Button({
        Title = "Refresh Secret Fish List",
        Icon = "refresh-ccw",
        Callback = function()
            local newOptions, newMap = GetSecretFishOptions()
            secretFishUUIDMap = newMap -- Update map global
            pcall(function() SecretFishDropdown:Refresh(newOptions) end)
            pcall(function() SecretFishDropdown:Set(false) end)
            selectedSecretFishUUIDs = {}
            WindUI:Notify({ Title = "Refreshed", Content = #newOptions .. " secret fish found.", Duration = 2, Icon = "check" })
        end
    })

    local amountmake = enchant2:Input({
        Title = "Amount to Make",
        Desc = "How many stones to make?",
        Value = "1",
        Placeholder = "1",
        Icon = "hash",
        Callback = function(input)
            targetStoneAmount = tonumber(input) or 1
        end
    })

    local togglestone = enchant2:Toggle({
        Title = "Start Make Stones",
        Desc = "Automatically change selected fish to Transcended Stone.",
        Value = false,
        Callback = function(state)
            makeStoneState = state
            if state then
                if #secretFishOptions <= 1 then
                    local newOptions, newMap = GetSecretFishOptions()
                    secretFishOptions = newOptions
                    secretFishUUIDMap = newMap
                    pcall(function() SecretFishDropdown:Refresh(newOptions) end)
                end
                if #selectedSecretFishUUIDs == 0 then
                    WindUI:Notify({ Title = "Error", Content = "Select at least 1 secret fish.", Duration = 3, Icon = "alert-triangle" })
                    return false
                end
                RunMakeStoneLoop()
            else
                if makeStoneThread then task.cancel(makeStoneThread) end
                WindUI:Notify({ Title = "Stopped", Duration = 2, Icon = "x" })
            end
        end
    })

    automatic:Divider()
    
    -- [UPDATE] UI SECOND ENCHANT (Hardcoded List)
    
    local SecondRodDropdown = enchant2:Dropdown({
        Title = "Select Rod for 2nd Enchant",
        Desc = "Select target Rod. Make sure Rod is in inventory.",
        Values = GetHardcodedRodNames(), -- Menggunakan list nama statis
        Multi = false,
        AllowNone = true,
        Callback = function(name)
            selectedRodUUID = nil
            -- Loop cari ID berdasarkan nama di list hardcode
            for _, v in ipairs(ENCHANT_ROD_LIST) do
                if v.Name == name then
                    local foundUUID = GetUUIDByRodID(v.ID)
                    if foundUUID then
                        selectedRodUUID = foundUUID
                        WindUI:Notify({ Title = "Rod Selected", Content = "Target: " .. name, Duration = 2, Icon = "check" })
                    else
                        WindUI:Notify({ Title = "Failed", Content = name .. " not found in inventory.", Duration = 3, Icon = "x" })
                    end
                    break
                end
            end
        end
    })

    local rodlist2 = enchant2:Button({
        Title = "Re-Check Selected Rod",
        Icon = "refresh-ccw",
        Callback = function()
             local currentName = SecondRodDropdown.Value
             if currentName then
                 -- Trigger ulang pencarian UUID
                 for _, v in ipairs(ENCHANT_ROD_LIST) do
                    if v.Name == currentName then
                        local foundUUID = GetUUIDByRodID(v.ID)
                        if foundUUID then
                            selectedRodUUID = foundUUID
                            WindUI:Notify({ Title = "Sync", Content = "UUID Verified.", Duration = 1, Icon = "check" })
                        else
                            WindUI:Notify({ Title = "Missing", Content = "Rod hilang/tidak ada.", Duration = 2, Icon = "x" })
                        end
                        break
                    end
                 end
             else
                WindUI:Notify({ Title = "Info", Content = "Select rod first.", Duration = 2 })
             end
        end
    })

    local targetenchant2 = enchant2:Dropdown({
        Title = "Target 2nd Enchant",
        Desc = "Select enchant that you want in slot 2.",
        Values = ENCHANT_NAMES,
        Multi = true,
        AllowNone = false,
        Callback = function(names)
            selectedEnchantNames = names or {}
        end
    })

    local start2ndenchant = enchant2:Toggle({
        Title = "Start Second Enchant",
        Desc = "Auto roll slot 2 using Transcended Stone.",
        Value = false,
        Callback = function(state)
            secondEnchantState = state
            if state then
                if not selectedRodUUID then
                    WindUI:Notify({ Title = "Error", Content = "Select Rod first.", Duration = 3, Icon = "alert-triangle" })
                    return false
                end
                if #selectedEnchantNames == 0 then
                    WindUI:Notify({ Title = "Error", Content = "Select target enchant.", Duration = 3, Icon = "alert-triangle" })
                    return false
                end
                RunSecondEnchantLoop(selectedRodUUID)
            else
                if secondEnchantThread then task.cancel(secondEnchantThread) end
                WindUI:Notify({ Title = "Stopped", Duration = 2, Icon = "x" })
            end
        end
    })
    
    -- =================================================================
    -- AUTO BUY WEATHER
    -- =================================================================
    automatic:Divider()
    
    local WeatherList = { "Storm", "Cloudy", "Snow", "Wind", "Radiant", "Shark Hunt" }
    local AutoWeatherState = false
    local AutoWeatherThread = nil
    local SelectedWeatherTypes = { WeatherList[1] }
    
    local RF_PurchaseWeatherEvent = GetRemote(RPath, "RF/PurchaseWeatherEvent", 5)
    
    local function RunAutoBuyWeatherLoop(weatherTypes)
        -- AGGRESSIVE CHECK/FALLBACK UNTUK REMOTE
        local PurchaseRemote = RF_PurchaseWeatherEvent
        if not PurchaseRemote then
            PurchaseRemote = GetRemote(RPath, "RF/PurchaseWeatherEvent", 1)
            
            if not PurchaseRemote then
                WindUI:Notify({ Title = "Weather Buy Error", Content = "Remote RF/PurchaseWeatherEvent tidak ditemukan setelah coba agresif!", Duration = 5, Icon = "x" })
                AutoWeatherState = false
                return
            end
        end

        if AutoWeatherThread then task.cancel(AutoWeatherThread) end

        print("[DEBUG WEATHER] Starting MULTI-BUY loop for: " .. table.concat(weatherTypes, ", "))
        
        AutoWeatherThread = task.spawn(function()
            local successfulBuyTime = 10 -- Catatan: Nilai ini kemungkinan harus 900 detik (15 menit) untuk cooldown game yang sebenarnya.
            local attempts = 0
            
            while AutoWeatherState and #weatherTypes > 0 do
                local totalSuccessfulBuysInCycle = 0
                local weatherBought = {}

                -- === FASE 1: INSTANTLY TRY ALL SELECTED WEATHERS (Satu Cycle Penuh) ===
                for i, weatherToBuy in ipairs(weatherTypes) do
                    
                    attempts = attempts + 1
                    
                    -- Notifikasi mencoba membeli (delay sangat singkat: 0.05 detik)
                    task.wait(0.05)
                    
                    local success_buy, err_msg = pcall(function()
                        return PurchaseRemote:InvokeServer(weatherToBuy)
                    end)

                    if success_buy then
                        -- Pembelian sukses, catat dan segera coba item berikutnya di daftar
                        totalSuccessfulBuysInCycle = totalSuccessfulBuysInCycle + 1
                        table.insert(weatherBought, weatherToBuy)
                        -- Tambahkan notifikasi sukses (opsional, untuk feedback cepat)
                    end
                end
                    
                -- === FASE 2: CHECK RESULT AND WAIT ===
                if totalSuccessfulBuysInCycle > 0 then
                    -- Setidaknya satu cuaca berhasil dibeli. Tunggu cooldown 15 menit.
                    local boughtList = table.concat(weatherBought, ", ")
                    
                    attempts = 0 -- Reset attempts
                    task.wait(successfulBuyTime) -- TUNGGU COOLDOWN LAMA DI SINI
                else
                    task.wait(5)
                end
            end
            AutoWeatherThread = nil
            local toggle = automatic:GetElementByTitle("Enable Auto Buy Weather")
            if toggle and toggle.Set then toggle:Set(false) end
        end)
    end
    
    local weathershop = automatic:Section({ Title = "Auto Buy Weather", TextSize = 20, })
    
    local WeatherDropdown = Reg("weahterd", weathershop:Dropdown({
        Title = "Select Weather Type",
        Values = WeatherList,
        Value = SelectedWeatherTypes,
        Multi = true,
        AllowNone = false,
        Callback = function(selected)
            SelectedWeatherTypes = selected or {}
            if #SelectedWeatherTypes == 0 then
                SelectedWeatherTypes = { WeatherList[1] }
            end
            if AutoWeatherState then
                RunAutoBuyWeatherLoop(SelectedWeatherTypes)
            end
        end
    }))
    
    local ToggleAutoBuy = Reg("shopweath", weathershop:Toggle({
        Title = "Enable Auto Buy Weather",
        Value = false,
        Callback = function(state)
            AutoWeatherState = state
            if state then
                if #SelectedWeatherTypes == 0 then
                    WindUI:Notify({ Title = "Error", Content = "Select at least one Weather type first.", Duration = 3, Icon = "x" })
                    AutoWeatherState = false
                    return false
                end
                RunAutoBuyWeatherLoop(SelectedWeatherTypes)
            else
                if AutoWeatherThread then task.cancel(AutoWeatherThread) end
                WindUI:Notify({ Title = "Auto Weather", Content = "Auto Buy disabled.", Duration = 3, Icon = "x" })
            end
        end
    }))
    
end

