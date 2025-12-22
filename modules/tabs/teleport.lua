do
        local teleport = Window:Tab({
            Icon = "compass",
            Title = "",
            Locked = false,
        })

    local selectedTargetPlayer = nil -- Nama pemain yang dipilih
    local selectedTargetArea = nil -- Nama area yang dipilih

    -- Helper: Mengambil daftar pemain yang sedang di server (diambil dari kode Automatic)
    local function GetPlayerListOptions()
        local options = {}
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(options, player.Name)
            end
        end
        return options
    end

    -- Helper: Mendapatkan HRP target
    local function GetTargetHRP(playerName)
        local targetPlayer = game.Players:FindFirstChild(playerName)
        local character = targetPlayer and targetPlayer.Character
        if character then
            return character:FindFirstChild("HumanoidRootPart")
        end
        return nil
    end


    -- =================================================================
    -- A. TELEPORT KE PEMAIN (Button)
    -- =================================================================
    local teleplay = teleport:Section({
        Title = "Teleport to Player",
        TextSize = 20,
    })

    local PlayerDropdown = teleplay:Dropdown({
        Title = "Select Target Player",
        Values = GetPlayerListOptions(),
        AllowNone = true,
        Callback = function(name)
            selectedTargetPlayer = name
        end
    })

    local listplaytel = teleplay:Button({
        Title = "Refresh Player List",
        Icon = "refresh-ccw",
        Callback = function()
            local newOptions = GetPlayerListOptions()
            pcall(function() PlayerDropdown:Refresh(newOptions) end)
            task.wait(0.1)
            pcall(function() PlayerDropdown:Set(false) end)
            selectedTargetPlayer = nil
            WindUI:Notify({ Title = "List Updated", Content = string.format("%d players found.", #newOptions), Duration = 2, Icon = "check" })
        end
    })

    local teletoplay = teleplay:Button({
        Title = "Teleport to Player (One-Time)",
        Content = "Teleport satu kali ke lokasi pemain yang dipilih.",
        Icon = "corner-down-right",
        Callback = function()
            local hrp = GetHRP()
            local targetHRP = GetTargetHRP(selectedTargetPlayer)
            
            if not selectedTargetPlayer then
                WindUI:Notify({ Title = "Error", Content = "Select target player first.", Duration = 3, Icon = "alert-triangle" })
                return
            end

            if hrp and targetHRP then
                -- Teleport 5 unit di atas target
                local targetPos = targetHRP.Position + Vector3.new(0, 5, 0)
                local lookVector = (targetHRP.Position - hrp.Position).Unit 
                
                hrp.CFrame = CFrame.new(targetPos, targetPos + lookVector)
                
                WindUI:Notify({ Title = "Teleport Success", Content = "Teleported to " .. selectedTargetPlayer, Duration = 3, Icon = "user-check" })
            else
                 WindUI:Notify({ Title = "Error", Content = "Failed to find target or your character.", Duration = 3, Icon = "x" })
            end
        end
    })
    
    teleport:Divider()

    -- =================================================================
    -- B. TELEPORT KE AREA (Button)
    -- =================================================================
    
    local telearea = teleport:Section({
        Title = "Teleport to Fishing Area",
        TextSize = 20,
    })

    local AreaDropdown = telearea:Dropdown({
        Title = "Select Target Area",
        Values = AreaNames, -- Menggunakan variabel AreaNames dari Fishing Tab
        AllowNone = true,
        Callback = function(name)
            selectedTargetArea = name
        end
    })

    local butelearea = telearea:Button({
        Title = "Teleport to Area (One-Time)",
        Content = "Teleport once to the selected area.",
        Icon = "corner-down-right",
        Callback = function()
            if not selectedTargetArea or not FishingAreas[selectedTargetArea] then
                WindUI:Notify({ Title = "Error", Content = "Select target area first.", Duration = 3, Icon = "alert-triangle" })
                return
            end
            
            local areaData = FishingAreas[selectedTargetArea]
            
            TeleportToLookAt(areaData.Pos, areaData.Look)
            WindUI:Notify({ Title = "Teleport Success", Content = "Teleported to " .. selectedTargetArea, Duration = 3, Icon = "map" })
        end
    })

    teleport:Divider()

    local televent = teleport:Section({
        Title = "Auto Teleport Event",
        TextSize = 20,
    })

    local dropvent = televent:Dropdown({
        Title = "Select Target Event",
        Content = "Select event that you want to monitor automatically.",
        Values = eventsList,
        AllowNone = true,
        Value = false,
        Callback = function(option)
            autoEventTargetName = option -- Simpan nama event sebagai target
            if autoEventTeleportState then
                 -- Force stop auto-teleport jika target diubah saat sedang aktif
                 autoEventTeleportState = false
                 if autoEventTeleportThread then task.cancel(autoEventTeleportThread) autoEventTeleportThread = nil end
                 Window:GetElementByTitle("Enable Auto Event Teleport"):Set(false)
            end
        end
    })

    local tovent = televent:Button({
        Title = "Teleport to Chosen Event (Once)",
        Icon = "corner-down-right",
        Callback = function()
            if not autoEventTargetName then
                WindUI:Notify({ Title = "Error", Content = "Select event in dropdown first!", Duration = 3, Icon = "alert-triangle" })
                return
            end
            
            WindUI:Notify({ Title = "Searching...", Content = "Searching for event...", Duration = 2, Icon = "search" })
            
            local found = FindAndTeleportToTargetEvent()
            if not found then
                WindUI:Notify({ Title = "Failed", Content = "Event not found / not spawned.", Duration = 3, Icon = "x" })
            end
        end
    })


    local togventel = televent:Toggle({
        Title = "Enable Auto Event Teleport",
        Content = "Secara otomatis mencari dan teleport ke event yang dipilih.",
        Value = false,
        Callback = function(state)
            if not autoEventTargetName then
                 WindUI:Notify({ Title = "Error", Content = "Select Event Target in dropdown first.", Duration = 3, Icon = "alert-triangle" })
                 return false
            end
            
            autoEventTeleportState = state
            if state then
                RunAutoEventTeleportLoop()
            else
                if autoEventTeleportThread then task.cancel(autoEventTeleportThread) autoEventTeleportThread = nil end
                WindUI:Notify({ Title = "Auto Event Teleport Disabled", Duration = 3, Icon = "x" })
            end
        end
    })
    
end
