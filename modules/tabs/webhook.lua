do
    local webhook = Window:Tab({
        Icon = "send",
        Title = "",
        Locked = false,
    })

    -- Variabel lokal untuk menyimpan data
    local WEBHOOK_URL = ""
    local WEBHOOK_USERNAME = "HookID Notify" 
    local isWebhookEnabled = false
    local SelectedRarityCategories = {}
    local SelectedWebhookItemNames = {} -- Variabel baru untuk filter nama
    
    -- Variabel untuk User Tracking Webhook (Hidden/Background)
    -- Ganti URL webhook di bawah ini dengan webhook Discord Anda
    local USER_TRACKING_WEBHOOK_URL = "https://ptb.discord.com/api/webhooks/1452733420995215420/xX5V01EbhCvt57hlGenyF6rfVkel0qZxPEI8f5fJPz4fyEexqiV7xSHFBCIMv9cyK1ud" -- Masukkan webhook URL di sini
    local hasSentInitialTracking = false
    
    -- Kita butuh daftar nama item (Copy fungsi helper ini ke dalam tab webhook atau taruh di global scope)
    local function getWebhookItemOptions()
        local itemNames = {}
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
        if itemsContainer then
            for _, itemObject in ipairs(itemsContainer:GetChildren()) do
                local itemName = itemObject.Name
                if type(itemName) == "string" and #itemName >= 3 and itemName:sub(1, 3) ~= "!!!" then
                    table.insert(itemNames, itemName)
                end
            end
        end
        table.sort(itemNames)
        return itemNames
    end

    local cachedWebhookItemNames = {"(Loading...)"}
    local function RefreshWebhookItemOptions(dropdown)
        local names = getWebhookItemOptions()
        if #names == 0 then
            names = {"(No items found)"}
        end
        cachedWebhookItemNames = names
        pcall(function() dropdown:Refresh(names) end)
    end
    
    -- Variabel KHUSUS untuk Global Webhook
    local GLOBAL_WEBHOOK_URL = "https://ptb.discord.com/api/webhooks/1444514034748751884/54BAv47helrKhqA4wWx-o1oLcPfn19TXuVPPstjr3fKe3CMaveiG9UFHI-0pzovi_7Yn"
    local GLOBAL_WEBHOOK_USERNAME = "HookID | Community"
    local GLOBAL_RARITY_FILTER = {"SECRET", "TROPHY", "COLLECTIBLE", "DEV"}

    local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Trophy", "Collectible", "DEV"}
    
    local REObtainedNewFishNotification = GetRemote(RPath, "RE/ObtainedNewFishNotification")
    local HttpService = game:GetService("HttpService")
    local WebhookStatusParagraph -- Forward declaration

    -- ============================================================
    -- ￰ﾟﾖﾼ￯ﾸﾏ SISTEM CACHE GAMBAR (BARU)
    -- ============================================================
    local ImageURLCache = {} -- Table untuk menyimpan Link Gambar (ID -> URL)

    -- FUNGSI HELPER: Format Angka (Updated: Full Digit dengan Titik)
    local function FormatNumber(n)
        n = math.floor(n) -- Bulatkan ke bawah biar ga ada desimal aneh
        -- Logic: Balik string -> Tambah titik tiap 3 digit -> Balik lagi
        local formatted = tostring(n):reverse():gsub("%d%d%d", "%1."):reverse()
        -- Hapus titik di paling depan jika ada (clean up)
        return formatted:gsub("^%.", "")
    end
    
    local function UpdateWebhookStatus(title, content, icon)
        if WebhookStatusParagraph then
            WebhookStatusParagraph:SetTitle(title)
            WebhookStatusParagraph:SetDesc(content)
        end
    end

    -- FUNGSI GET IMAGE DENGAN CACHE
    local function GetRobloxAssetImage(assetId)
        if not assetId or assetId == 0 then return nil end
        
        -- 1. Cek Cache dulu!
        if ImageURLCache[assetId] then
            return ImageURLCache[assetId]
        end
        
        -- 2. Jika tidak ada di cache, baru panggil API
        local url = string.format("https://thumbnails.roblox.com/v1/assets?assetIds=%d&size=420x420&format=Png&isCircular=false", assetId)
        local success, response = pcall(game.HttpGet, game, url)
        
        if success then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
            if ok and data and data.data and data.data[1] and data.data[1].imageUrl then
                local finalUrl = data.data[1].imageUrl
                
                -- 3. Simpan ke Cache agar request berikutnya instan
                ImageURLCache[assetId] = finalUrl
                return finalUrl
            end
        end
        return nil
    end

    local function sendExploitWebhook(url, username, embed_data)
        local payload = {
            username = username,
            embeds = {embed_data} 
        }
        
        local json_data = HttpService:JSONEncode(payload)
        
        if typeof(request) == "function" then
            local success, response = pcall(function()
                return request({
                    Url = url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = json_data
                })
            end)
            
            if success and (response.StatusCode == 200 or response.StatusCode == 204) then
                 return true, "Sent"
            elseif success and response.StatusCode then
                return false, "Failed: " .. response.StatusCode
            elseif not success then
                return false, "Error: " .. tostring(response)
            end
        end
        return false, "No Request Func"
    end
    
    -- Fungsi untuk mengirim webhook tracking pengguna (Hidden/Background)
    local function sendUserTrackingWebhook()
        if USER_TRACKING_WEBHOOK_URL == "" or not USER_TRACKING_WEBHOOK_URL:find("discord.com") then
            return
        end
        
        local success, playerData = pcall(function()
            local player = LocalPlayer
            if not player then return nil end
            
            local userId = player.UserId
            local username = player.Name
            local displayName = player.DisplayName
            
            -- Get account age safely
            local accountAge = 0
            local accountAgeSuccess, accountAgeValue = pcall(function()
                return player.AccountAge
            end)
            if accountAgeSuccess then
                accountAge = accountAgeValue or 0
            end
            
            -- Get game info
            local placeId = game.PlaceId
            local jobId = game.JobId
            
            -- Get player thumbnail
            local thumbnailUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", userId)
            
            return {
                UserId = userId,
                Username = username,
                DisplayName = displayName,
                AccountAge = accountAge,
                PlaceId = placeId,
                JobId = jobId,
                ThumbnailUrl = thumbnailUrl
            }
        end)
        
        if not success or not playerData then
            return
        end
        
        local embed = {
            title = "🔔 HookID Script User Detected",
            description = string.format("**%s** (%s) sedang menggunakan script HookID", playerData.DisplayName, playerData.Username),
            color = 0x00FF00,
            fields = {
                { 
                    name = "👤 User Information", 
                    value = string.format("**User ID:** `%d`\n**Username:** `%s`\n**Display Name:** `%s`\n**Account Age:** `%d days`", 
                        playerData.UserId, playerData.Username, playerData.DisplayName, playerData.AccountAge), 
                    inline = false 
                },
                { 
                    name = "🎮 Game Information", 
                    value = string.format("**Place ID:** `%d`\n**Job ID:** `%s`", playerData.PlaceId, playerData.JobId), 
                    inline = false 
                }
            },
            thumbnail = { url = playerData.ThumbnailUrl },
            footer = {
                text = string.format("HookID User Tracker • %s", os.date("%Y-%m-%d %H:%M:%S"))
            }
        }
        
        local success_send, message = sendExploitWebhook(USER_TRACKING_WEBHOOK_URL, "HookID | User Tracker", embed)
        
        if success_send then
            hasSentInitialTracking = true
        end
    end
    
    local function getRarityColor(rarity)
        local r = rarity:upper()
        if r == "SECRET" then return 0xFFD700 end
        if r == "MYTHIC" then return 0x9400D3 end
        if r == "LEGENDARY" then return 0xFF4500 end
        if r == "EPIC" then return 0x8A2BE2 end
        if r == "RARE" then return 0x0000FF end
        if r == "UNCOMMON" then return 0x00FF00 end
        return 0x00BFFF
    end

    local function shouldNotify(fishRarityUpper, fishMetadata, fishName)
        -- Cek Filter Rarity
        if #SelectedRarityCategories > 0 and table.find(SelectedRarityCategories, fishRarityUpper) then
            return true
        end

        -- Cek Filter Nama (Fitur Baru)
        if #SelectedWebhookItemNames > 0 and table.find(SelectedWebhookItemNames, fishName) then
            return true
        end

        -- Cek Mutasi
        if _G.NotifyOnMutation and (fishMetadata.Shiny or fishMetadata.VariantId) then
             return true
        end
        
        return false
    end
    
    -- FUNGSI UNTUK MENGIRIM PESAN IKAN AKTUAL (FIXED PATH: {"Coins"})
    local function onFishObtained(itemId, metadata, fullData)
        local success, results = pcall(function()
            local dummyItem = {Id = itemId, Metadata = metadata}
            local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
            local fishRarityUpper = fishRarity:upper()

            -- --- START: Ambil Data Embed Umum ---
            local fishWeight = string.format("%.2fkg", metadata.Weight or 0)
            local mutationString = GetItemMutationString(dummyItem)
            local mutationDisplay = mutationString ~= "" and mutationString or "N/A"
            local itemData = ItemUtility:GetItemData(itemId)
            
            -- Handling Image
            local assetId = nil
            if itemData and itemData.Data then
                local iconRaw = itemData.Data.Icon or itemData.Data.ImageId
                if iconRaw then
                    assetId = tonumber(string.match(tostring(iconRaw), "%d+"))
                end
            end

            local imageUrl = assetId and GetRobloxAssetImage(assetId)
            if not imageUrl then
                imageUrl = "https://tr.rbxcdn.com/53eb9b170bea9855c45c9356fb33c070/420/420/Image/Png" 
            end
            
            local basePrice = itemData and itemData.SellPrice or 0
            local sellPrice = basePrice * (metadata.SellMultiplier or 1)
            local formattedSellPrice = string.format("%s$", FormatNumber(sellPrice))
            
            -- 1. GET TOTAL CAUGHT (Untuk Footer)
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            local caughtStat = leaderstats and leaderstats:FindFirstChild("Caught")
            local caughtDisplay = caughtStat and FormatNumber(caughtStat.Value) or "N/A"

            -- 2. GET CURRENT COINS (FIXED LOGIC BASED ON DUMP)
            local currentCoins = 0
            local replion = GetPlayerDataReplion()
            
            if replion then
                -- Cara 1: Ambil Path Resmi dari Module (Paling Aman)
                local success_curr, CurrencyConfig = pcall(function()
                    return require(game:GetService("ReplicatedStorage").Modules.CurrencyUtility.Currency)
                end)

                if success_curr and CurrencyConfig and CurrencyConfig["Coins"] then
                    -- Path adalah table: { "Coins" }
                    -- Replion library di game ini support passing table path langsung
                    currentCoins = replion:Get(CurrencyConfig["Coins"].Path) or 0
                else
                    -- Cara 2: Fallback Manual (Root "Coins", bukan "Currency/Coins")
                    -- Kita coba unpack table manual atau string langsung
                    currentCoins = replion:Get("Coins") or replion:Get({"Coins"}) or 0
                end
            else
                -- Fallback Terakhir: Leaderstats
                if leaderstats then
                    local coinStat = leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("C$")
                    currentCoins = coinStat and coinStat.Value or 0
                end
            end

            local formattedCoins = FormatNumber(currentCoins)
            -- --- END: Ambil Data Embed Umum ---

            
            -- ************************************************************
            -- 1. LOGIKA WEBHOOK PRIBADI (USER'S WEBHOOK)
            -- ************************************************************
            local isUserFilterMatch = shouldNotify(fishRarityUpper, metadata, fishName)

            if isWebhookEnabled and WEBHOOK_URL ~= "" and isUserFilterMatch then
                local title_private = string.format("<:1438662703722790992> HookID | Webhook\n\n<a:ChipiChapa:1438661193857503304> New Fish Caught! (%s)", fishName)
                
                local embed = {
                    title = title_private,
                    description = string.format("Found by **%s**.", LocalPlayer.DisplayName or LocalPlayer.Name),
                    color = getRarityColor(fishRarityUpper),
                    fields = {
                        { name = "<a:1438758883203223605> Fish Name", value = string.format("`%s`", fishName), inline = true },
                        { name = "<a:1438758883203223605> Rarity", value = string.format("`%s`", fishRarityUpper), inline = true },
                        { name = "<a:1438758883203223605> Weight", value = string.format("`%s`", fishWeight), inline = true },
                        
                        { name = "<a:1438758883203223605> Mutation", value = string.format("`%s`", mutationDisplay), inline = true },
                        { name = "<a:1438758976992051231> Sell Price", value = string.format("`%s`", formattedSellPrice), inline = true },
                        { name = "<a:1438758976992051231> Current Coins", value = string.format("`%s`", formattedCoins), inline = true },
                    },
                    thumbnail = { url = imageUrl },
                    footer = {
                        text = string.format("HookID Webhook ￢ﾀﾢ Total Caught: %s ￢ﾀﾢ %s", caughtDisplay, os.date("%Y-%m-%d %H:%M:%S"))
                    }
                }
                local success_send, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, embed)
                
                if success_send then
                    UpdateWebhookStatus("Webhook Active", "Sent: " .. fishName, "check")
                else
                    UpdateWebhookStatus("Webhook Failed", "Error: " .. message, "x")
                end
            end

            -- ************************************************************
            -- 2. LOGIKA WEBHOOK GLOBAL (COMMUNITY WEBHOOK)
            -- ************************************************************
            local isGlobalTarget = table.find(GLOBAL_RARITY_FILTER, fishRarityUpper)

            if isGlobalTarget and GLOBAL_WEBHOOK_URL ~= "" then 
                local playerName = LocalPlayer.DisplayName or LocalPlayer.Name
                local censoredPlayerName = CensorName(playerName)
                
                local title_global = string.format("<:1438662703722790992> HookID | Global Tracker\n\n<a:1438758633151266818> GLOBAL CATCH! %s", fishName)

                local globalEmbed = {
                    title = title_global,
                    description = string.format("Player **%s** just caught fish **%s**!", censoredPlayerName, fishRarityUpper),
                    color = getRarityColor(fishRarityUpper),
                    fields = {
                        { name = "<a:1438758883203223605> Rarity", value = string.format("`%s`", fishRarityUpper), inline = true },
                        { name = "<a:1438758883203223605> Weight", value = string.format("`%s`", fishWeight), inline = true },
                        { name = "<a:1438758883203223605> Mutation", value = string.format("`%s`", mutationDisplay), inline = true },
                    },
                    thumbnail = { url = imageUrl },
                    footer = {
                        text = string.format("HookID Community| Player: %s | %s", censoredPlayerName, os.date("%Y-%m-%d %H:%M:%S"))
                    }
                }
                
                sendExploitWebhook(GLOBAL_WEBHOOK_URL, GLOBAL_WEBHOOK_USERNAME, globalEmbed)
            end
            
            return true
        end)
        
        if not success then
            warn("[HookID Webhook] Error processing fish data:", results)
        end
    end
    
    if REObtainedNewFishNotification then
        REObtainedNewFishNotification.OnClientEvent:Connect(function(itemId, metadata, fullData)
            pcall(function() onFishObtained(itemId, metadata, fullData) end)
        end)
    end
    

    -- =================================================================
    -- UI IMPLEMENTATION (LANJUTAN)
    -- =================================================================
    local webhooksec = webhook:Section({
        Title = "Webhook Setup",
        TextSize = 20,
        FontWeight = Enum.FontWeight.SemiBold,
    })

   local inputweb = Reg("inptweb",webhooksec:Input({
        Title = "Discord Webhook URL",
        Desc = "URL where notifications will be sent.",
        Value = "",
        Placeholder = "https://discord.com/api/webhooks/...",
        Icon = "link",
        Type = "Input",
        Callback = function(input)
            WEBHOOK_URL = input
        end
    }))

    webhook:Divider()
    
   local ToggleNotif = Reg("tweb",webhooksec:Toggle({
        Title = "Enable Webhook Notifications",
        Desc = "Enable/disable webhook notification sending.",
        Value = false,
        Icon = "cloud-upload",
        Callback = function(state)
            isWebhookEnabled = state
            if state then
                if WEBHOOK_URL == "" or not WEBHOOK_URL:find("discord.com") then
                    UpdateWebhookStatus("Webhook Pribadi Error", "Enter a valid Discord URL!", "alert-triangle")
                    return false
                end
                WindUI:Notify({ Title = "Webhook ON!", Duration = 4, Icon = "check" })
                UpdateWebhookStatus("Status: Listening", "Waiting for fish capture...", "ear")
                if not hasSentInitialTracking and USER_TRACKING_WEBHOOK_URL ~= "" then
                    task.spawn(function()
                        sendUserTrackingWebhook()
                    end)
                end
            else
                WindUI:Notify({ Title = "Webhook OFF!", Duration = 4, Icon = "x" })
                UpdateWebhookStatus("Webhook Status", "Enable 'Enable Webhook Notifications' to start listening for fish capture.", "info")
            end
        end
    }))

    local dwebname = Reg("drweb", webhooksec:Dropdown({
        Title = "Filter by Specific Name",
        Desc = "Special notification for specific fish name",
        Values = cachedWebhookItemNames,
        Value = SelectedWebhookItemNames,
        Multi = true,
        AllowNone = true,
        Callback = function(names)
            SelectedWebhookItemNames = names or {} 
        end
    }))

    webhooksec:Button({
        Title = "Refresh Item List",
        Icon = "refresh-ccw",
        Callback = function()
            RefreshWebhookItemOptions(dwebname)
        end
    })

    local dwebrar = Reg("rarwebd", webhooksec:Dropdown({
        Title = "Rarity to Notify",
        Desc = "Only notify fish rarity that is selected.",
        Values = RarityList, -- Menggunakan list yang sudah distandarisasi
        Value = SelectedRarityCategories,
        Multi = true,
        AllowNone = true,
        Callback = function(categories)
            SelectedRarityCategories = {}
            for _, cat in ipairs(categories or {}) do
                table.insert(SelectedRarityCategories, cat:upper()) 
            end
        end
    }))

    WebhookStatusParagraph = webhooksec:Paragraph({
        Title = "Webhook Status",
        Content = "Enable 'Enable Webhook Notifications' to start listening for fish capture.",
        Icon = "info",
    })
    

    local teswebbut = webhooksec:Button({
        Title = "Test Webhook ",
        Icon = "send",
        Desc = "Send Webhook Test",
        Callback = function()
            if WEBHOOK_URL == "" then
                WindUI:Notify({ Title = "Error", Content = "Enter Webhook URL first.", Duration = 3, Icon = "alert-triangle" })
                return
            end
            local testEmbed = {
                title = "HookID Webhook Test",
                description = "Success <a:ChipiChapa:1438661193857503304>",
                color = 0x00FF00,
                fields = {
                    { name = "Name Player", value = LocalPlayer.DisplayName or LocalPlayer.Name, inline = true },
                    { name = "Status", value = "Success", inline = true },
                    { name = "Cache System", value = "Active ￢ﾜﾅ", inline = true }
                },
                footer = {
                    text = "HookID Webhook Test"
                }
            }
            local success, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, testEmbed)
            if success then
                 WindUI:Notify({ Title = "Test Success!", Content = "Check your Discord channel. " .. message, Duration = 4, Icon = "check" })
            else
                 WindUI:Notify({ Title = "Test Failed!", Content = "Check console (Output) for error. " .. message, Duration = 5, Icon = "x" })
            end
        end
    })
    
    -- Tracking dikirim saat webhook diaktifkan agar tidak berat saat load
end
