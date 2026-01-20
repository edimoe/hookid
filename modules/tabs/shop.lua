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
    
    -- Variabel Auto Buy Merchant Dinamis
    local autoBuyStockState = false
    local autoBuyThread = nil

    -- FUNGSI HELPER: Format Angka
    local function FormatNumber(n)
        if n >= 1000000000 then return string.format("%.1fB", n / 1000000000)
        elseif n >= 1000000 then return string.format("%.1fM", n / 1000000)
        elseif n >= 1000 then return string.format("%.1fK", n / 1000)
        else return tostring(n) end
    end

    -- Remote Functions & Data (diambil dari Global Scope)
    local RF_PurchaseMarketItem = GetRemote(RPath, "RF/PurchaseMarketItem", 5)
    
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
            else
                if autoBuyThread then task.cancel(autoBuyThread) autoBuyThread = nil end
            end
        end
    })
    


    local telemerc = merchant:Button({ Title = "Teleport To Merchant Shop", Icon = "mouse-pointer-click", Callback = function() TeleportToLookAt(Vector3.new(-127.747, 2.718, 2759.031), Vector3.new(-0.920, 0.000, -0.392)) end })
    
    
end

