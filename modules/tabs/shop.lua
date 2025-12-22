do
    local shop = Window:Tab({
        Icon = "store",
        Title = "",
        Locked = false,
    })

    -- === DEFINISI FUNGSI NOTIFIKASI LOKAL UNTUK MENGAKSES WindUI:Notify ===
    -- Ditinggalkan agar lebih bersih, menggunakan WindUI:Notify() secara langsung

    -- Variabel Tracking Tombol Dinamis
    local MerchantButtons = {}
    
    -- VARIABEL LOKAL DAN FUNGSI HELPER
    local MerchantReplion = nil
    local UpdateCleanupFunction = nil
    local MainDisplayElement = nil
    local UpdateThread = nil
    
    -- Variabel Auto Buy Merchant Statis & Dinamis
    local selectedStaticItemName = nil
    local autoBuySelectedState = false
    local autoBuyStockState = false
    local autoBuyThread = nil

    -- FUNGSI HELPER: Format Angka
    local function FormatNumber(n)
        if n >= 1000000000 then return string.format("%.1fB", n / 1000000000)
        elseif n >= 1000000 then return string.format("%.1fM", n / 1000000)
        elseif n >= 1000 then return string.format("%.1fK", n / 1000)
        else return tostring(n) end
    end

    -- Data Item Shop & Merchant Item STATIS (CLEANED)
    local ShopItems = {
        ["Rods"] = {
            {Name = "Luck Rod", ID = 70, Price = 325}, {Name = "Carbon Rod", ID = 76, Price = 750},
            {Name = "Grass Rod", ID = 85, Price = 1500}, {Name = "Demascus Rod", ID = 77, Price = 3000},
            {Name = "Ice Rod", ID = 78, Price = 5000}, {Name = "Lucky Rod", ID = 4, Price = 15000},
            {Name = "Midnight Rod", ID = 80, Price = 50000}, {Name = "Steampunk Rod", ID = 6, Price = 215000},
            {Name = "Chrome Rod", ID = 7, Price = 437000}, {Name = "Flourescent Rod", ID = 255, Price = 715000},
            {Name = "Astral Rod", ID = 5, Price = 1000000}, {Name = "Ares Rod", ID = 126, Price = 3000000},
            {Name = "Angler Rod", ID = 168, Price = 8000000},{Name = "Bamboo Rod", ID = 258, Price = 12000000},
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

    local MerchantStaticItems = {
        {Name = "Fluorescent Rod", ID = 1, Identifier = "Fluorescent Rod", Price = 685000},
        {Name = "Hazmat Rod", ID = 2, Identifier = "Hazmat Rod", Price = 1380000},
        {Name = "Singularity Bait", ID = 3, Identifier = "Singularity Bait", Price = 8200000},
        {Name = "Royal Bait", ID = 4, Identifier = "Royal Bait", Price = 425000},
        {Name = "Luck Totem", ID = 5, Identifier = "Luck Totem", Price = 650000},
        {Name = "Shiny Totem", ID = 7, Identifier = "Shiny Totem", Price = 400000},
        {Name = "Mutation Totem", ID = 8, Identifier = "Mutation Totem", Price = 800000}
    }
    

    -- Remote Functions & Data (diambil dari Global Scope)
    local RF_PurchaseBait = GetRemote(RPath, "RF/PurchaseBait", 5)
    local RF_PurchaseFishingRod = GetRemote(RPath, "RF/PurchaseFishingRod", 5)
    local RF_PurchaseBoat = GetRemote(RPath, "RF/PurchaseBoat", 5)
    local RF_PurchaseMarketItem = GetRemote(RPath, "RF/PurchaseMarketItem", 5)
    local ShopRemotes = {
        ["Rods"] = RF_PurchaseFishingRod, ["Bobbers"] = RF_PurchaseBait, ["Boats"] = RF_PurchaseBoat,
    }

    -- FUNGSI UNTUK DROPDOWN STATIS (CLEANED)
    local function GetStaticMerchantOptions()
        local options = {}
        for _, item in ipairs(MerchantStaticItems) do
            local formattedPrice = FormatNumber(item.Price)
            -- HANYA MENAMPILKAN HARGA TANPA JENIS MATA UANG
            table.insert(options, string.format("%s (%s)", item.Name, formattedPrice))
        end
        return options
    end

    -- (Fungsi Helper lainnya)
    local function GetStaticMerchantItemID(dropdownValue)
        for _, item in ipairs(MerchantStaticItems) do
            if dropdownValue:match("^" .. item.Name:gsub("%%", "%%%%") .. " ") then
                return item.ID, item.Name
            end
        end
        return nil, nil
    end

    local function getDropdownOptions(itemType)
        local options = {}
        for _, item in ipairs(ShopItems[itemType]) do
            local formattedPrice = FormatNumber(item.Price)
            table.insert(options, string.format("%s (%s)", item.Name, formattedPrice))
        end
        return options
    end
    local function getItemID(itemType, dropdownValue)
        local itemName = dropdownValue:match("^([^%s]+%s[^%s]+)")
        if not itemName then itemName = dropdownValue:match("^[^%s]+") end
        for _, item in ipairs(ShopItems[itemType]) do
            if item.Name == itemName then return item.ID end
        end
        return nil
    end
    local function handlePurchase(itemType, selectedValue)
        local itemID = getItemID(itemType, selectedValue)
        local remote = ShopRemotes[itemType]
        if not remote or not itemID then
            WindUI:Notify({ Title = "Purchase Error",Duration = 4, Icon = "x", })
            return
        end
        pcall(function() remote:InvokeServer(itemID) end)
        WindUI:Notify({ Title = "Purchase Attempted!", Duration = 3, Icon = "check", })
    end
    
    local function GetReplions()
        if MerchantReplion then return true end
        local ReplionModule = RepStorage:WaitForChild("Packages"):WaitForChild("Replion", 10)
        if not ReplionModule then return false end
        local ReplionClient = require(ReplionModule).Client
        MerchantReplion = ReplionClient:WaitReplion("Merchant", 5)
        return MerchantReplion
    end

    local function getNextRefreshTimeString()
        local serverTime = workspace:GetServerTimeNow()
        local secondsInDay = 86400
        local nextRefreshTime = (math.floor(serverTime / secondsInDay) + 1) * secondsInDay
        local timeRemaining = math.max(nextRefreshTime - serverTime, 0)
        local h = math.floor(timeRemaining / 3600)
        local m = math.floor((timeRemaining % 3600) / 60)
        local s = math.floor(timeRemaining % 60)
        local timeString = string.format("Next Refresh: %dH, %dM, %dS", h, m, s)
        return timeString
    end
    
    -- FUNGSI UNTUK MENDAPATKAN DETAIL ITEM LENGKAP
    local function GetMerchantStockDetails(merchantData)
        local itemDetails = {}
        local MarketItemData = RepStorage:WaitForChild("Shared"):WaitForChild("MarketItemData", 0.1) and require(RepStorage.Shared.MarketItemData)
        
        if merchantData and merchantData.Items and type(merchantData.Items) == "table" and MarketItemData and ItemUtility then
            for _, itemID in ipairs(merchantData.Items) do
                local marketData = nil
                for _, data in ipairs(MarketItemData) do
                    if data.Id == itemID then marketData = data; break end
                end

                if marketData and not marketData.SkinCrate and marketData.Price and marketData.Currency then
                    local itemDetail = nil
                    pcall(function() itemDetail = ItemUtility:GetItemDataFromItemType(marketData.Type, marketData.Identifier) end)
                    
                    local name = (itemDetail and itemDetail.Data and itemDetail.Data.Name) or marketData.Identifier or "Unknown Item"
                    
                    table.insert(itemDetails, {
                        Name = name,
                        ID = itemID,
                        Price = marketData.Price,
                        Currency = marketData.Currency,
                    })
                end
            end
        end
        return itemDetails
    end

    -- FUNGSI LOGIC PEMBELIAN ITEM MERCHANT
    local function BuyMerchantItem(itemID, itemName)
        if not RF_PurchaseMarketItem then
            WindUI:Notify({ Title = "Purchase Failed", Content = "Remote Purchase Market Item not found.", Duration = 4, Icon = "x", })
            return false
        end
        
        local success, result = pcall(function()
            return RF_PurchaseMarketItem:InvokeServer(itemID)
        end)

        if success then
            WindUI:Notify({ Title = "Purchase Attempted!", Content = "Trying to buy: " .. itemName, Duration = 1.5, Icon = "check", })
            return true
        else
            WindUI:Notify({ Title = "Purchase Failed", Content = "Failed: " .. (result or "Unknown Error"), Duration = 2, Icon = "x", })
            return false
        end
    end
    
    -- FUNGSI UNTUK MENGHAPUS TOMBOL LAMA
    local function ClearOldMerchantButtons()
        for _, btn in ipairs(MerchantButtons) do
            if btn and type(btn) == "table" and btn.Destroy then
                pcall(function()
                    btn:Destroy()
                end)
            end
        end
        MerchantButtons = {}
    end

    -- FUNGSI UNTUK MEMBUAT STRING STOCK LIST
    local function CreateStockListString(itemDetails)
        local list = {"--- CURRENT STOCK ---"}
        if #itemDetails == 0 then
            table.insert(list, "Unique Item stock is empty currently.")
            return table.concat(list, "\n")
        end

        for _, item in ipairs(itemDetails) do
            local formattedPrice = FormatNumber(item.Price)
            local currency = item.Currency or "Coins"
            table.insert(list, string.format(" ￢ﾀﾢ %s: %s %s", item.Name, formattedPrice, currency))
        end
        
        return table.concat(list, "\n")
    end

    -- FUNGSI UNTUK MENGGAMBAR ULANG TOMBOL DINAMIS
    local function RedrawMerchantButtons(itemDetails)
        ClearOldMerchantButtons()
        
        if #itemDetails > 0 then
            for _, item in ipairs(itemDetails) do
                local formattedPrice = FormatNumber(item.Price)
                local currency = item.Currency or "Coins"
                
                local newButton = shop:Button({
                    Title = string.format("BUY: %s", item.Name),
                    Desc = string.format("Price: %s %s", formattedPrice, currency),
                    Icon = "shopping-cart",
                    Callback = function()
                        BuyMerchantItem(item.ID, item.Name)
                    end
                })
                table.insert(MerchantButtons, newButton)
            end
        else
            local noStockIndicator = shop:Paragraph({
                Title = "No Buyable Items",
                Desc = "No buyable items available.",
                Icon = "info",
            })
            table.insert(MerchantButtons, noStockIndicator)
        end
    end

    -- ￰ﾟﾒﾡ FUNGSI AUTO BUY DINAMIS (Current Stock)
    local function RunAutoBuyStockLoop()
        if autoBuyThread then task.cancel(autoBuyThread) end
        
        autoBuyThread = task.spawn(function()
            while autoBuyStockState do
                if MerchantReplion then
                    local currentDetails = GetMerchantStockDetails(MerchantReplion.Data)
                    for _, item in ipairs(currentDetails) do
                        BuyMerchantItem(item.ID, item.Name)
                        task.wait(0.5)
                    end
                end
                task.wait(3)
            end
        end)
    end

    -- ￰ﾟﾒﾡ FUNGSI AUTO BUY STATIS (Selected Item)
    local function RunAutoBuySelectedLoop(itemID, itemName)
        if autoBuyThread then task.cancel(autoBuyThread) end

        autoBuyThread = task.spawn(function()
            while autoBuySelectedState do
                BuyMerchantItem(itemID, itemName)
                task.wait(1)
            end
        end)
    end


    local function RunMerchantSyncLoop(mainDisplay)
        if UpdateThread then task.cancel(UpdateThread) end

        local initialDetails = GetMerchantStockDetails(MerchantReplion.Data)
        RedrawMerchantButtons(initialDetails)
        
        local stockUpdateConnection = MerchantReplion:OnChange("Items", function(newItems)
            local currentDetails = GetMerchantStockDetails(MerchantReplion.Data)
            RedrawMerchantButtons(currentDetails)
            
            local timeString = getNextRefreshTimeString()
            local stockListString = CreateStockListString(currentDetails)
            mainDisplay:SetTitle(timeString .. "\n" .. stockListString)
        end)
        
        local isRunning = true
        
        UpdateThread = task.spawn(function()
            while isRunning do
                local timeString = getNextRefreshTimeString()
                local currentDetails = GetMerchantStockDetails(MerchantReplion.Data)
                local stockListString = CreateStockListString(currentDetails)
                
                mainDisplay:SetTitle(timeString .. "\n" .. stockListString)
                
                task.wait(1)
            end
            if stockUpdateConnection then stockUpdateConnection:Disconnect() end
            ClearOldMerchantButtons()
        end)
        
        return function()
            isRunning = false
            if UpdateThread then task.cancel(UpdateThread) UpdateThread = nil end
            if stockUpdateConnection then stockUpdateConnection:Disconnect() end
            ClearOldMerchantButtons()
        end
    end
    
    local function ToggleMerchantSync(state, mainDisplay)
        if state then
            task.spawn(function()
                if not GetReplions() then
                    WindUI:Notify({ Title = "Sync Failed", Content = "Failed to load Replion Merchant.", Duration = 4, Icon = "x", })
                    mainDisplay:SetTitle("Sync Failed: Merchant Replion missing/timeout.")
                    mainDisplay:SetDesc("Toggle OFF and try again.")
                    return
                end

                WindUI:Notify({ Title = "Sync ON!", Content = "Starting live update stock and buy buttons.", Duration = 2, Icon = "check", })
                mainDisplay:SetDesc("Refresh time calculated accurately from server.")
                UpdateCleanupFunction = RunMerchantSyncLoop(mainDisplay)
            end)
            
            return true
        else
            WindUI:Notify({ Title = "Sync OFF!", Duration = 3, Icon = "x", })
            
            if UpdateCleanupFunction then
                UpdateCleanupFunction()
                UpdateCleanupFunction = nil
            end
            
            mainDisplay:SetTitle("Merchant Live Data OFF.")
            mainDisplay:SetDesc("Toggle ON to see live status.")
            ClearOldMerchantButtons()
            
            return false
        end
    end

    -- ** START WIDGETS **
    
    local ptele = shop:Section({ Title = "Shop Teleports", TextSize = 20, })
    shop:Divider()
    local buttele = ptele:Button({ Title = "Skin Crate Shop", Icon = "mouse-pointer-click", Callback = function() TeleportToLookAt(Vector3.new(79.038, 17.284, 2869.537), Vector3.new(-0.893, -0.000, 0.450)) end })
    local bututil = ptele:Button({ Title = "Utility Shop", Icon = "mouse-pointer-click", Callback = function() TeleportToLookAt(Vector3.new(-41.260, 20.460, 2877.561), Vector3.new(-0.893, -0.000, 0.450)) end })

    local merchant = shop:Section({
        Title = "Traveling Merchant",
        TextSize = 20,
    })
    shop:Divider()

    -- 1. Display Waktu & Stok (Paragraph)
    MainDisplayElement = merchant:Paragraph({
        Title = "Merchant Live Data OFF.",
        Desc = "Toggle ON to see live status.",
        Icon = "clock"
    })

    -- ** DI SINI TOMBOL BUY DINAMIS BERDASARKAN LIVE STOCK MUNCUL **

    local tlive = merchant:Toggle({
        Title = "Live Stock & Buy Buttons",
        Icon = "rotate-ccw",
        Value = true,
        Callback = function(state)
            return ToggleMerchantSync(state, MainDisplayElement)
        end,
    })


    local tcurst = merchant:Toggle({
        Title = "Auto Buy Current Items",
        Value = false,
        Callback = function(state)
            autoBuyStockState = state
            if state then
                RunAutoBuyStockLoop()
                if autoBuySelectedState then
                    autoBuySelectedState = false
                    shop:GetElementByTitle("Auto Buy Selected Items"):Set(false)
                end
            else
                if autoBuyThread then task.cancel(autoBuyThread) autoBuyThread = nil end
            end
        end
    })
    


    local telemerc = merchant:Button({ Title = "Teleport To Merchant Shop", Icon = "mouse-pointer-click", Callback = function() TeleportToLookAt(Vector3.new(-127.747, 2.718, 2759.031), Vector3.new(-0.920, 0.000, -0.392)) end })
    
    
end

