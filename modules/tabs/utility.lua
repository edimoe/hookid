do
local utility = Window:Tab({
    Icon = "box",
    Title = "",
    Locked = false,
})

utility:Divider()

local misc = utility:Section({ Title = "Misc. Area", TextSize = 20})

local RF_UpdateFishingRadar = GetRemote(RPath, "RF/UpdateFishingRadar")

local tfishradar = misc:Toggle({
    Title = "Enable Fishing Radar",
    Desc = "ON/OFF Fishing Radar",
    Value = false,
    Icon = "compass",
    Callback = function(state)
        if not RF_UpdateFishingRadar then
            WindUI:Notify({ Title = "Error", Content = "Remote 'RF/UpdateFishingRadar' not found.", Duration = 3, Icon = "x" })
            return false
        end

        pcall(function()
            RF_UpdateFishingRadar:InvokeServer(state)
        end)

        if state then
            WindUI:Notify({ Title = "Fishing Radar ON", Content = "Fishing Radar activated.", Duration = 3, Icon = "check" })
        else
            WindUI:Notify({ Title = "Fishing Radar OFF", Content = "Fishing Radar deactivated.", Duration = 3, Icon = "x" })
        end
    end
})

-- ￰ﾟﾒﾧ FUNGSI BARU: EQUIP OXYGEN TANK
local RF_EquipOxygenTank = GetRemote(RPath, "RF/EquipOxygenTank")
local RF_UnequipOxygenTank = GetRemote(RPath, "RF/UnequipOxygenTank")

local ttank = Reg("infox", misc:Toggle({
    Title = "Equip Oxygen Tank",
    Desc = "infinite oxygen",
    Value = false,
    Icon = "life-buoy",
    Callback = function(state)
        if state then
            if not RF_EquipOxygenTank then
                WindUI:Notify({ Title = "Error", Duration = 3, Icon = "x" })
                return false
            end
            
            pcall(function()
                RF_EquipOxygenTank:InvokeServer(105) -- ID 105 untuk Oxygen Tank
            end)
            WindUI:Notify({ Title = "Oxygen Tank Equipped", Content = "Oxygen Tank equipped.", Duration = 3, Icon = "check" })
        else
            if not RF_UnequipOxygenTank then
                WindUI:Notify({ Title = "Error", Duration = 3, Icon = "x" })
                return true -- Tetap kembalikan true agar toggle tidak stuck
            end
            
            pcall(function()
                RF_UnequipOxygenTank:InvokeServer()
            end)
            WindUI:Notify({ Title = "Oxygen Tank Unequipped", Content = "Oxygen Tank unequipped.", Duration = 3, Icon = "x" })
        end
    end
}))

local REObtainedNewFishNotification = GetRemote(RPath, "RE/ObtainedNewFishNotification")
local RunService = game:GetService("RunService")

local notif = Reg("togglenot",misc:Toggle({
    Title = "Remove Fish Notification Pop-up",
    Value = false,
    Icon = "slash",
    Callback = function(state)
        local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
        local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
        
        if not SmallNotification then
            SmallNotification = PlayerGui:WaitForChild("Small Notification", 5)
            if not SmallNotification then
                WindUI:Notify({ Title = "Error", Duration = 3, Icon = "x" })
                return false
            end
        end

        if state then
            -- ON: Menggunakan RenderStepped untuk pemblokiran per-frame
            DisableNotificationConnection = SafeConnect(
                RunService.RenderStepped,
                function()
                    -- Memastikan GUI selalu mati pada setiap frame render
                    SmallNotification.Enabled = false
                end,
                "DisableNotificationConnection",
                "Disable Fish Notification Pop-up",
                "utility"
            )
            
            WindUI:Notify({ Title = "Pop-up Blocked",Content = "Popup blocked.", Duration = 3, Icon = "check" })
        else
            -- OFF: Putuskan koneksi RenderStepped
            SafeDisconnect("DisableNotificationConnection")
            DisableNotificationConnection = nil

            -- Kembalikan GUI ke status normal (aktif)
            SmallNotification.Enabled = true
            
            WindUI:Notify({ Title = "Pop-up Enabled", Content = "Notification back to normal.", Duration = 3, Icon = "x" })
        end
    end
}))


local isNoAnimationActive = false
local originalAnimator = nil
local originalAnimateScript = nil

local function DisableAnimations()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not humanoid then return end

    -- 1. Blokir script 'Animate' bawaan (yang memuat default anim)
    local animateScript = character:FindFirstChild("Animate")
    if animateScript and animateScript:IsA("LocalScript") and animateScript.Enabled then
        originalAnimateScript = animateScript.Enabled
        animateScript.Enabled = false
    end

    -- 2. Hapus Animator (menghalangi semua animasi dimainkan/dimuat)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        -- Simpan referensi objek Animator aslinya
        originalAnimator = animator 
        animator:Destroy()
    end
end

local function EnableAnimations()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    
    -- 1. Restore script 'Animate'
    local animateScript = character:FindFirstChild("Animate")
    if animateScript and originalAnimateScript ~= nil then
        animateScript.Enabled = originalAnimateScript
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- 2. Restore/Tambahkan Animator
    local existingAnimator = humanoid:FindFirstChildOfClass("Animator")
    if not existingAnimator then
        -- Jika Animator tidak ada, dan kita memiliki objek aslinya, restore
        if originalAnimator and not originalAnimator.Parent then
            originalAnimator.Parent = humanoid
        else
            -- Jika objek asli hilang, buat yang baru
            Instance.new("Animator").Parent = humanoid
        end
    end
    originalAnimator = nil -- Bersihkan referensi lama
end

local function OnCharacterAdded(newCharacter)
    if isNoAnimationActive then
        task.wait(0.2) -- Tunggu sebentar agar LoadCharacter selesai
        DisableAnimations()
    end
end

-- Hubungkan ke CharacterAdded agar tetap berfungsi saat respawn
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

local anim = Reg("Toggleanim",misc:Toggle({
    Title = "No Animation",
    Value = false,
    Icon = "skull",
    Callback = function(state)
        isNoAnimationActive = state
        if state then
            DisableAnimations()
            WindUI:Notify({ Title = "No Animation ON!", Duration = 3, Icon = "zap" })
        else
            EnableAnimations()
            WindUI:Notify({ Title = "No Animation OFF!", Duration = 3, Icon = "x" })
        end
    end
}))

-- Tambahkan di bagian atas blok 'utility'
local VFXControllerModule = nil
local originalVFXHandle = nil
local originalVFXRenderAtPoint = nil
local originalVFXRenderInstance = nil

-- Variabel global untuk status VFX
local isVFXDisabled = false


local tskin = Reg("toggleskin",misc:Toggle({
    Title = "Remove Skin Effect",
    Value = false,
    Icon = "slash",
    Callback = function(state)
        isVFXDisabled = state

        if state then
            if not VFXControllerModule then
                local ok, mod = pcall(function()
                    return require(game:GetService("ReplicatedStorage"):WaitForChild("Controllers").VFXController)
                end)
                if not ok or not mod then
                    WindUI:Notify({ Title = "Gagal Hook", Content = "Module VFXController not found.", Duration = 3, Icon = "x" })
                    return false
                end
                VFXControllerModule = mod
                originalVFXHandle = VFXControllerModule.Handle
                originalVFXRenderAtPoint = VFXControllerModule.RenderAtPoint
                originalVFXRenderInstance = VFXControllerModule.RenderInstance
            end
            -- 1. Blokir fungsi Handle (dipanggil oleh Handle Remote dan PlayVFX Signal)
            VFXControllerModule.Handle = function(...) 
                -- Memastikan tidak ada kode efek yang berjalan 
            end

            -- 2. Blokir fungsi RenderAtPoint dan RenderInstance (untuk jaga-jaga)
            VFXControllerModule.RenderAtPoint = function(...) end
            VFXControllerModule.RenderInstance = function(...) end
            
            -- 3. Hapus semua efek yang sedang aktif (opsional, untuk membersihkan layar)
            local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder")
            if cosmeticFolder then
                pcall(function() cosmeticFolder:ClearAllChildren() end)
            end

            WindUI:Notify({ Title = "No Skin Effect ON", Duration = 3, Icon = "eye-off" })
        else
            -- 1. Kembalikan fungsi Handle asli
            if VFXControllerModule and originalVFXHandle then
                VFXControllerModule.Handle = originalVFXHandle
                if originalVFXRenderAtPoint then
                    VFXControllerModule.RenderAtPoint = originalVFXRenderAtPoint
                end
                if originalVFXRenderInstance then
                    VFXControllerModule.RenderInstance = originalVFXRenderInstance
                end
            end
        end
    end
}))

local CutsceneController = nil
local OldPlayCutscene = nil
local isNoCutsceneActive = false

    local tcutscen = Reg("tnocut",misc:Toggle({
        Title = "No Cutscene",
        Value = false,
        Icon = "film", -- Icon film strip
        Callback = function(state)
            isNoCutsceneActive = state
            if state and not CutsceneController then
                local ok, mod = pcall(function()
                    return require(game:GetService("ReplicatedStorage"):WaitForChild("Controllers"):WaitForChild("CutsceneController"))
                end)
                if not ok or not mod then
                    WindUI:Notify({ Title = "Gagal Hook", Content = "Module CutsceneController not found.", Duration = 3, Icon = "x" })
                    return false
                end
                CutsceneController = mod
                if CutsceneController and CutsceneController.Play then
                    OldPlayCutscene = CutsceneController.Play
                    -- Overwrite fungsi Play
                    CutsceneController.Play = function(self, ...)
                        if isNoCutsceneActive then
                            return
                        end
                        return OldPlayCutscene(self, ...)
                    end
                end
            end

            if state then
                WindUI:Notify({ Title = "No Cutscene ON", Content = "Capture animation disabled.", Duration = 3, Icon = "video-off" })
            else
                WindUI:Notify({ Title = "No Cutscene OFF", Content = "Animation back to normal.", Duration = 3, Icon = "video" })
            end
        end
    }))

    local defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance or 128
    local zoomLoopConnection = nil

    local tzoom = Reg("infzoom",misc:Toggle({
        Title = "Infinite Zoom Out",
        Value = false,
        Icon = "maximize",
        Callback = function(state)
            if state then
                -- 1. Simpan nilai asli dulu buat jaga-jaga
                defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance
                
                -- 2. Paksa nilai zoom jadi besar
                LocalPlayer.CameraMaxZoomDistance = 100000
                
                -- 3. Pasang loop (RenderStepped) untuk memaksa nilai tetap besar
                -- Ini berguna kalau game mencoba mengembalikan zoom ke normal
                SafeDisconnect(zoomLoopConnectionId)
                zoomLoopConnection = SafeConnect(
                    game:GetService("RunService").RenderStepped,
                    function()
                        LocalPlayer.CameraMaxZoomDistance = 100000
                    end,
                    zoomLoopConnectionId,
                    "Infinite Zoom Loop",
                    "misc"
                )
                
                WindUI:Notify({ Title = "Zoom Unlocked", Content = "Now can zoom out as much as possible.", Duration = 3, Icon = "maximize" })
            else
                -- 1. Matikan loop pemaksa
                SafeDisconnect(zoomLoopConnectionId)
                zoomLoopConnection = nil
                
                -- 2. Kembalikan ke nilai asli
                LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom
                
                WindUI:Notify({ Title = "Zoom Normal", Content = "Limit zoom returned.", Duration = 3, Icon = "minimize" })
            end
        end
    }))

    local t3d = Reg("t3drend",misc:Toggle({
        Title = "Disable 3D Rendering",
        Value = false,
        Callback = function(state)
            local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
            local Camera = workspace.CurrentCamera
            local LocalPlayer = game.Players.LocalPlayer
            
            if state then
                -- 1. Buat GUI Hitam di PlayerGui (Bukan CoreGui)
                if not _G.BlackScreenGUI then
                    _G.BlackScreenGUI = Instance.new("ScreenGui")
                    _G.BlackScreenGUI.Name = "HookID_BlackBackground"
                    _G.BlackScreenGUI.IgnoreGuiInset = true
                    -- [-999] = Taruh di paling belakang (di bawah UI Game), tapi nutupin world 3D
                    _G.BlackScreenGUI.DisplayOrder = -999 
                    _G.BlackScreenGUI.Parent = PlayerGui
                    
                    local Frame = Instance.new("Frame")
                    Frame.Size = UDim2.new(1, 0, 1, 0)
                    Frame.BackgroundColor3 = Color3.new(0, 0, 0) -- Hitam Pekat
                    Frame.BorderSizePixel = 0
                    Frame.Parent = _G.BlackScreenGUI
                    
                    local Label = Instance.new("TextLabel")
                    Label.Size = UDim2.new(1, 0, 0.1, 0)
                    Label.Position = UDim2.new(0, 0, 0.1, 0) -- Taruh agak atas biar ga ganggu inventory
                    Label.BackgroundTransparency = 1
                    Label.Text = "Saver Mode Enabled"
                    Label.TextColor3 = Color3.fromRGB(60, 60, 60) -- Abu gelap sekali biar ga ganggu
                    Label.TextSize = 16
                    Label.Font = Enum.Font.GothamBold
                    Label.Parent = Frame
                end
                
                _G.BlackScreenGUI.Enabled = true

                -- 2. SIMPAN POSISI KAMERA ASLI
                _G.OldCamType = Camera.CameraType

                -- 3. PINDAHKAN KAMERA KE VOID
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CFrame.new(0, 100000, 0) 
                
                WindUI:Notify({
                    Title = "Saver Mode ON",
                    Duration = 3,
                    Icon = "battery-charging",
                })
            else
                -- 1. KEMBALIKAN TIPE KAMERA
                if _G.OldCamType then
                    Camera.CameraType = _G.OldCamType
                else
                    Camera.CameraType = Enum.CameraType.Custom
                end
                
                -- 2. KEMBALIKAN FOKUS KE KARAKTER
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    Camera.CameraSubject = LocalPlayer.Character.Humanoid
                end

                -- 3. MATIKAN LAYAR HITAM
                if _G.BlackScreenGUI then
                    _G.BlackScreenGUI.Enabled = false
                end
                
                WindUI:Notify({
                    Title = "Saver Mode OFF",
                    Content = "Visual back to normal.",
                    Duration = 3,
                    Icon = "eye",
                })
            end
        end
    }))

    -- 2. FPS Ultra Boost (fungsi helper)
    -- Tambahkan/Ganti di dekat helper global Anda
local isBoostActive = false
local originalLightingValues = {}

local function ToggleFPSBoost(enabled)
    isBoostActive = enabled
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    if enabled then
        -- Simpan nilai asli sekali saja
        if not next(originalLightingValues) then
            originalLightingValues.GlobalShadows = Lighting.GlobalShadows
            originalLightingValues.FogEnd = Lighting.FogEnd
            originalLightingValues.Brightness = Lighting.Brightness
            originalLightingValues.ClockTime = Lighting.ClockTime
            originalLightingValues.Ambient = Lighting.Ambient
            originalLightingValues.OutdoorAmbient = Lighting.OutdoorAmbient
        end
        
        -- 1. VISUAL & EFEK (Hanya mematikan)
        pcall(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Explosion") then
                    v.Enabled = false
                elseif v:IsA("Beam") or v:IsA("Light") then
                    v.Enabled = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 1 
                end
            end
        end)
        
        -- 2. LIGHTING & ENVIRONMENT (Pengaturan Minimalis)
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = false end
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0 -- Lebih gelap/kontras untuk efisiensi
            Lighting.ClockTime = 14 -- Siang tanpa bayangan
            Lighting.Ambient = Color3.new(0, 0, 0)
            Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        end)
        
        -- 3. TERRAIN & WATER
        if Terrain then
            pcall(function()
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
                Terrain.Decoration = false
            end)
        end
        
        -- 4. QUALITY & EXPLOIT TRICKS
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)

        if type(setfpscap) == "function" then pcall(function() setfpscap(100) end) end 
        if type(collectgarbage) == "function" then collectgarbage("collect") end

        WindUI:Notify({ Title = "FPS Boost", Content = "Maximum FPS mode enabled (Minimal Graphics).", Duration = 3, Icon = "zap" })
    else
        -- RESET
        pcall(function()
            if originalLightingValues.GlobalShadows ~= nil then
                Lighting.GlobalShadows = originalLightingValues.GlobalShadows
                Lighting.FogEnd = originalLightingValues.FogEnd
                Lighting.Brightness = originalLightingValues.Brightness
                Lighting.ClockTime = originalLightingValues.ClockTime
                Lighting.Ambient = originalLightingValues.Ambient
                Lighting.OutdoorAmbient = originalLightingValues.OutdoorAmbient
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = true end
            end
        end)
        
        if type(setfpscap) == "function" then pcall(function() setfpscap(60) end) end
        
        WindUI:Notify({ Title = "FPS Boost", Content = "Graphics reset to default/automatic. Rejoin recommended.", Duration = 3, Icon = "rotate-ccw" })
    end
end

    local tfps = Reg("togfps",misc:Toggle({
        Title = "FPS Ultra Boost",
        Value = false,
        Callback = function(state)
            ToggleFPSBoost(state)
        end
    }))

utility:Divider()

-- =================================================================
    -- ￰ﾟﾌﾐ SERVER MANAGEMENT (REJOIN & HOP)
    -- =================================================================
    local serverm = utility:Section({ Title = "Server Management", TextSize = 20})

    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")

    -- 1. REJOIN SERVER
    local brejoin = serverm:Button({
        Title = "Rejoin Server",
        Desc = "Rejoin server (Refresh game).",
        Icon = "rotate-cw",
        Callback = function()
            WindUI:Notify({ Title = "Rejoining...", Content = "Waiting...", Duration = 3, Icon = "loader" })
            
            -- Queue script agar dieksekusi lagi pas rejoin (Optional, tergantung executor support)
            if syn and syn.queue_on_teleport then
                syn.queue_on_teleport('loadstring(game:HttpGet("URL_SCRIPT_KAMU_DISINI"))()')
            elseif queue_on_teleport then
                queue_on_teleport('loadstring(game:HttpGet("URL_SCRIPT_KAMU_DISINI"))()')
            end

            if #Players:GetPlayers() <= 1 then
                -- Kalau sendiri, Teleport biasa (akan buat server baru/masuk ulang)
                Players.LocalPlayer:Kick("\n[HookID] Rejoining...")
                task.wait()
                TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
            else
                -- Kalau rame, masuk ke Instance yang sama
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
            end
        end
    })

    -- 2. SERVER HOP (RANDOM)
    local bhop = serverm:Button({
        Title = "Server Hop (Random)",
        Desc = "Teleport to random server.",
        Icon = "arrow-right-circle",
        Callback = function()
            WindUI:Notify({ Title = "Hopping...", Content = "Searching for new server...", Duration = 3, Icon = "search" })
            
            task.spawn(function()
                local PlaceId = game.PlaceId
                local JobId = game.JobId
                
                local sfUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
                local req = game:HttpGet(string.format(sfUrl, PlaceId))
                local body = HttpService:JSONDecode(req)
        
                if body and body.data then
                    local servers = {}
                    for _, v in ipairs(body.data) do
                        -- Filter: Bukan server saat ini, dan belum penuh
                        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= JobId then
                            table.insert(servers, v.id)
                        end
                    end
        
                    if #servers > 0 then
                        local randomServerId = servers[math.random(1, #servers)]
                        WindUI:Notify({ Title = "Server Found", Content = "Teleporting...", Duration = 3, Icon = "plane" })
                        TeleportService:TeleportToPlaceInstance(PlaceId, randomServerId, Players.LocalPlayer)
                    else
                        WindUI:Notify({ Title = "Gagal Hop", Content = "No suitable server found.", Duration = 3, Icon = "x" })
                    end
                else
                    WindUI:Notify({ Title = "API Error", Content = "Failed to get server list.", Duration = 3, Icon = "alert-triangle" })
                end
            end)
        end
    })

    -- 3. SERVER HOP (LOW SERVER / SEPI)
    local hoplow = serverm:Button({
        Title = "Server Hop (Low Player)",
        Desc = "Searching for server with low players (suitable for farming).",
        Icon = "user-minus",
        Callback = function()
            WindUI:Notify({ Title = "Searching Low Server...", Content = "Searching for server with low players...", Duration = 3, Icon = "search" })
            
            task.spawn(function()
                local PlaceId = game.PlaceId
                local JobId = game.JobId
                
                -- Sort Ascending (Dari yang paling sedikit pemainnya)
                local sfUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"
                local req = game:HttpGet(string.format(sfUrl, PlaceId))
                local body = HttpService:JSONDecode(req)
        
                if body and body.data then
                    for _, v in ipairs(body.data) do
                        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= JobId and v.playing >= 1 then
                            -- Ketemu server, langsung gas
                            WindUI:Notify({ Title = "Low Server Found!", Content = "Players: " .. tostring(v.playing), Duration = 3, Icon = "check" })
                            TeleportService:TeleportToPlaceInstance(PlaceId, v.id, Players.LocalPlayer)
                            return -- Stop loop
                        end
                    end
                    WindUI:Notify({ Title = "Gagal", Content = "No suitable server found.", Duration = 3, Icon = "x" })
                else
                    WindUI:Notify({ Title = "API Error", Content = "Failed to get server list.", Duration = 3, Icon = "alert-triangle" })
                end
            end)
        end
    })

    -- 1. COPY JOB ID SAAT INI
    local copyjobid = serverm:Button({
        Title = "Copy Current Job ID",
        Desc = "Copy current server ID to clipboard.",
        Icon = "copy",
        Callback = function()
            local jobId = game.JobId
            setclipboard(jobId)
            WindUI:Notify({ 
                Title = "Copied!", 
                Content = "Job ID copied to clipboard.", 
                Duration = 3, 
                Icon = "check" 
            })
        end
    })

    -- Variabel penyimpanan input
    local targetJoinID = ""

    -- 2. INPUT FIELD JOB ID
    local injobid = serverm:Input({
        Title = "Target Job ID",
        Desc = "Paste target server Job ID here.",
        Value = "",
        Placeholder = "Paste Job ID here...",
        Icon = "keyboard",
        Callback = function(text)
            targetJoinID = text
        end
    })

    -- 3. TOMBOL JOIN
    local joinid = serverm:Button({
        Title = "Join Server by ID",
        Desc = "Teleport to server by Job ID.",
        Icon = "log-in",
        Callback = function()
            if targetJoinID == "" then
                WindUI:Notify({ Title = "Error", Content = "Enter Job ID first in the input field!", Duration = 3, Icon = "alert-triangle" })
                return
            end

            -- Cek apakah ID-nya sama dengan server sekarang (biar gak buang waktu)
            if targetJoinID == game.JobId then
                WindUI:Notify({ Title = "Info", Content = "You are already on this server!", Duration = 3, Icon = "info" })
                return
            end

            WindUI:Notify({ Title = "Joining...", Content = "Trying to join server by ID...", Duration = 3, Icon = "plane" })
            
            -- Eksekusi Teleport
            local success, err = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, targetJoinID, game.Players.LocalPlayer)
            end)

            if not success then
                WindUI:Notify({ Title = "Gagal", Content = "Invalid Server ID / Server Full / Expired.", Duration = 5, Icon = "x" })
            end
        end
    })

-- =================================================================
    -- ￰ﾟﾎﾥ CINEMATIC / CONTENT TOOLS (V11 - CLEAN MODE FIX)
    -- =================================================================
    utility:Divider()
    local cinematic = utility:Section({ Title = "Cinematic / Content Tools", TextSize = 20})

    -- Services
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local StarterGui = game:GetService("StarterGui")
    local Workspace = game:GetService("Workspace")
    
    -- Modules
    local LocalPlayer = Players.LocalPlayer
    
    -- Settings & State
    local freeCamSpeed = 1.5
    local freeCamFov = 70
    local isFreeCamActive = false
    
    local camera = Workspace.CurrentCamera
    local camPos = camera.CFrame.Position
    local camRot = Vector2.new(0,0)
    
    -- Manual Mouse Vars
    local lastMousePos = Vector2.new(0,0)
    local renderConn = nil
    local touchConn = nil
    local touchDelta = Vector2.new(0, 0)
    
    -- Restore
    local oldWalkSpeed = 16
    local oldJumpPower = 50

    -- 1. SLIDER CAMERA SPEED
    local cameras = cinematic:Slider({
        Title = "Camera Speed",
        Step = 0.1,
        Value = { Min = 0.1, Max = 10.0, Default = 1.5 },
        Callback = function(val) 
            freeCamSpeed = tonumber(val) 
        end
    })

    -- 2. SLIDER FOV
    local fovcam = cinematic:Slider({
        Title = "Field of View (FOV)",
        Desc = "Zoom In/Out Lens.",
        Step = 1,
        Value = { Min = 10, Max = 120, Default = 70 },
        Callback = function(val) 
            freeCamFov = tonumber(val)
            if isFreeCamActive then 
                camera.FieldOfView = freeCamFov 
            end
        end
    })

    -- 3. TOGGLE CLEAN MODE (FIXED LOGIC)
    local hideuiall = cinematic:Toggle({
        Title = "Hide All UI (Clean Mode)",
        Value = false,
        Icon = "eye-off",
        Callback = function(state)
            local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
            
            if state then
                -- [LOGIKA FIX]: Simpan state asli sebelum dimatikan
                for _, gui in ipairs(PlayerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Name ~= "WindUI" and gui.Name ~= "CustomFloatingIcon_HookID" then
                        -- Simpan status 'Enabled' saat ini ke Attribute
                        gui:SetAttribute("OriginalState", gui.Enabled)
                        gui.Enabled = false
                    end
                end
                -- Matikan CoreGui (Chat, Leaderboard)
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
                
                WindUI:Notify({ Title = "Clean Mode ON", Content = "UI hidden.", Duration = 2, Icon = "camera" })
            else
                -- [LOGIKA FIX]: Restore sesuai state asli
                for _, gui in ipairs(PlayerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        local originalState = gui:GetAttribute("OriginalState")
                        if originalState ~= nil then
                            gui.Enabled = originalState
                            gui:SetAttribute("OriginalState", nil) -- Bersihkan attribute
                        end
                    end
                end
                -- Nyalakan CoreGui
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
                
                WindUI:Notify({ Title = "Clean Mode OFF", Content = "UI back to normal.", Duration = 2, Icon = "eye" })
            end
        end
    })

    -- 4. FREE CAM (MANUAL TRACKING - YANG UDAH WORK)
    local enablecam = cinematic:Toggle({
        Title = "Enable Free Cam",
        Value = false,
        Icon = "video",
        Callback = function(state)
            isFreeCamActive = state
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if state then
                -- INIT
                camera.CameraType = Enum.CameraType.Scriptable
                camPos = camera.CFrame.Position
                local rx, ry, _ = camera.CFrame:ToEulerAnglesYXZ()
                camRot = Vector2.new(rx, ry)
                
                -- INITIAL MOUSE POS
                lastMousePos = UserInputService:GetMouseLocation()

                -- FREEZE CHARACTER
                if hum then
                    oldWalkSpeed = hum.WalkSpeed
                    oldJumpPower = hum.JumpPower
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    hum.PlatformStand = true
                end
                if hrp then hrp.Anchored = true end

                -- TOUCH LISTENER (MOBILE)
                if touchConn then touchConn:Disconnect() end
                touchConn = UserInputService.TouchMoved:Connect(function(input, processed)
                    if not processed then touchDelta = input.Delta end
                end)

                -- [UPDATE] FREECAM RENDER LOOP (MOBILE SUPPORT)
                local ControlModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))

                if renderConn then renderConn:Disconnect() end
                renderConn = RunService.RenderStepped:Connect(function()
                    if not isFreeCamActive then return end

                    -- A. ROTASI KAMERA (Touch/Mouse)
                    local currentMousePos = UserInputService:GetMouseLocation()
                    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local deltaX = currentMousePos.X - lastMousePos.X
                        local deltaY = currentMousePos.Y - lastMousePos.Y
                        local sens = 0.003
                        
                        camRot = camRot - Vector2.new(deltaY * sens, deltaX * sens)
                        camRot = Vector2.new(math.clamp(camRot.X, -1.55, 1.55), camRot.Y)
                    end
                    
                    -- Mobile Touch Drag
                    if UserInputService.TouchEnabled then
                        camRot = camRot - Vector2.new(touchDelta.Y * 0.005 * 2.0, touchDelta.X * 0.005 * 2.0)
                        camRot = Vector2.new(math.clamp(camRot.X, -1.55, 1.55), camRot.Y)
                        touchDelta = Vector2.new(0, 0)
                    end
                    
                    lastMousePos = currentMousePos

                    -- B. PERGERAKAN (KEYBOARD + ANALOG MOBILE)
                    local rotCFrame = CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, 0)
                    local moveVector = Vector3.zero

                    -- 1. Ambil Input dari Control Module (Support WASD & Mobile Analog sekaligus)
                    local rawMoveVector = ControlModule:GetMoveVector()
                    
                    -- 2. Input Keyboard Manual (untuk vertical E/Q)
                    local verticalInput = 0
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then verticalInput = 1 end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then verticalInput = -1 end

                    -- 3. Kalkulasi Arah (World Space)
                    -- rawMoveVector.X adalah Kanan/Kiri (Relative Camera)
                    -- rawMoveVector.Z adalah Maju/Mundur (Relative Camera)
                    
                    -- Konversi ke arah kamera saat ini
                    if rawMoveVector.Magnitude > 0 then
                        moveVector = (rotCFrame.RightVector * rawMoveVector.X) + (rotCFrame.LookVector * rawMoveVector.Z * -1)
                    end
                    
                    -- Tambah gerakan Vertikal
                    moveVector = moveVector + Vector3.new(0, verticalInput, 0)

                    -- 4. Kecepatan (Shift untuk ngebut)
                    local speedMultiplier = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4 or 1)
                    local finalSpeed = freeCamSpeed * speedMultiplier
                    
                    -- 5. Terapkan Posisi
                    if moveVector.Magnitude > 0 then
                        camPos = camPos + (moveVector * finalSpeed)
                    end

                    -- C. UPDATE KAMERA
                    camera.CFrame = CFrame.new(camPos) * rotCFrame
                    camera.FieldOfView = freeCamFov 
                end)
                
                WindUI:Notify({ Title = "Free Cam Ready", Content = "Free Cam activated.", Duration = 3, Icon = "check" })

            else
                -- MATIKAN
                if renderConn then renderConn:Disconnect() renderConn = nil end
                if touchConn then touchConn:Disconnect() touchConn = nil end
                
                camera.CameraType = Enum.CameraType.Custom
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                camera.FieldOfView = 70 

                if hum then
                    hum.WalkSpeed = oldWalkSpeed
                    hum.JumpPower = oldJumpPower
                    hum.PlatformStand = false
                end
                if hrp then hrp.Anchored = false end
                
                WindUI:Notify({ Title = "Free Cam OFF", Content = "Free Cam deactivated.", Duration = 3, Icon = "x" })
            end
        end
    })
    
    -- =================================================================
    -- CHARACTER FEATURES (MOVED FROM CHARACTER TAB)
    -- =================================================================
    utility:Divider()
    
    -- MOVEMENT
    local movement = utility:Section({
        Title = "Speed & Jump",
        TextSize = 18,
    })

    -- 1. SLIDER WALKSPEED
    local SliderSpeed = Reg("Walkspeed",movement:Slider({
        Title = "WalkSpeed",
        Step = 1,
        Value = {
            Min = 16,
            Max = 200,
            Default = currentSpeed,
        },
        Callback = function(value)
            local speedValue = tonumber(value)
            if speedValue and speedValue >= 0 then
                local Humanoid = GetHumanoid()
                if Humanoid then
                    Humanoid.WalkSpeed = speedValue
                end
            end
        end,
    }))

    -- 2. SLIDER JUMPOWER
    local SliderJump = Reg("slidjump",movement:Slider({
        Title = "JumpPower",
        Step = 1,
        Value = {
            Min = 50,
            Max = 200,
            Default = currentJump,
        },
        Callback = function(value)
            local jumpValue = tonumber(value)
            if jumpValue and jumpValue >= 50 then
                local Humanoid = GetHumanoid()
                if Humanoid then
                    Humanoid.JumpPower = jumpValue
                end
            end
        end,
    }))
    
    -- 3. RESET BUTTON
    local reset = movement:Button({
        Title = "Reset Movement",
        Icon = "rotate-ccw",
        Locked = false,
        Callback = function()
            local Humanoid = GetHumanoid()
            if Humanoid then
                Humanoid.WalkSpeed = DEFAULT_SPEED
                Humanoid.JumpPower = DEFAULT_JUMP
                SliderSpeed:Set(DEFAULT_SPEED)
                SliderJump:Set(DEFAULT_JUMP)
                WindUI:Notify({
                    Title = "Movement Reset",
                    Content = "WalkSpeed & JumpPower Reset to default",
                    Duration = 3,
                    Icon = "check",
                })
            end
        end
    })

    -- 4. TOGGLE FREEZE PLAYER
    local freezeplr = Reg("frezee",movement:Toggle({
        Title = "Freeze Player",
        Desc = "Freezing character at current position (Anti-Push).",
        Value = false,
        Callback = function(state)
            local character = LocalPlayer.Character
            if not character then return end
            
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Set Anchored sesuai status toggle
                hrp.Anchored = state
                
                if state then
                    -- Hentikan momentum agar berhenti instan (tidak meluncur)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    
                    WindUI:Notify({ 
                        Title = "Player Frozen", 
                        Content = "Position locked (Anchored).", 
                        Duration = 2, 
                        Icon = "lock" 
                    })
                else
                    WindUI:Notify({ 
                        Title = "Player Unfrozen", 
                        Content = "Movement back to normal.", 
                        Duration = 2, 
                        Icon = "unlock" 
                    })
                end
            else
                WindUI:Notify({ Title = "Error", Content = "HumanoidRootPart not found.", Duration = 3, Icon = "alert-triangle" })
            end
        end
    }))

    local ability = utility:Section({
        Title = "Special Powers",
        TextSize = 18,
    })

    -- 1. TOGGLE INFINITE JUMP
    local infjump = Reg("infj", ability:Toggle({
        Title = "Infinite Jump",
        Value = false,
        Callback = function(state)
            if state then
                WindUI:Notify({ Title = "Infinite Jump ON!", Duration = 3, Icon = "check", })
                InfinityJumpConnection = SafeConnect(
                    UserInputService.JumpRequest,
                    function()
                        local Humanoid = GetHumanoid()
                        if Humanoid and Humanoid.Health > 0 then
                            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end,
                    InfinityJumpConnectionId,
                    "Infinite Jump",
                    "ability"
                )
            else
                WindUI:Notify({ Title = "Infinite Jump OFF!", Duration = 3, Icon = "check", })
                SafeDisconnect(InfinityJumpConnectionId)
                InfinityJumpConnection = nil
            end
        end
    }))

    -- 2. TOGGLE NO CLIP
    local noclipConnection = nil
    local noclipConnectionId = "noclipConnection"
    local isNoClipActive = false
    local noclip = Reg("nclip",ability:Toggle({
        Title = "No Clip",
        Value = false,
        Callback = function(state)
            isNoClipActive = state
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

            if state then
                WindUI:Notify({ Title = "No Clip ON!", Duration = 3, Icon = "check", })
                noclipConnection = SafeConnect(
                    game:GetService("RunService").Stepped,
                    function()
                        if isNoClipActive and character then
                            for _, part in ipairs(character:GetDescendants()) do
                                if part:IsA("BasePart") and part.CanCollide then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end,
                    noclipConnectionId,
                    "No Clip",
                    "ability"
                )
            else
                WindUI:Notify({ Title = "No Clip OFF!", Duration = 3, Icon = "x", })
                SafeDisconnect(noclipConnectionId)
                noclipConnection = nil

                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    }))

    -- 3. TOGGLE FLY MODE
    local flyConnection = nil
    local flyConnectionId = "flyConnection"
    local isFlying = false
    local flySpeed = 60
    local bodyGyro, bodyVel
    local flytog = Reg("flym",ability:Toggle({
        Title = "Fly Mode",
        Value = false,
        Callback = function(state)
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            local humanoid = character:WaitForChild("Humanoid")

            if state then
                WindUI:Notify({ Title = "Fly Mode ON!", Duration = 3, Icon = "check", })
                isFlying = true

                bodyGyro = Instance.new("BodyGyro")
                bodyGyro.P = 9e4
                bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bodyGyro.CFrame = humanoidRootPart.CFrame
                bodyGyro.Parent = humanoidRootPart

                bodyVel = Instance.new("BodyVelocity")
                bodyVel.Velocity = Vector3.zero
                bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bodyVel.Parent = humanoidRootPart

                local cam = workspace.CurrentCamera
                local moveDir = Vector3.zero
                local jumpPressed = false

                UserInputService.JumpRequest:Connect(function()
                    if isFlying then jumpPressed = true task.delay(0.2, function() jumpPressed = false end) end
                end)

                flyConnection = SafeConnect(
                    game:GetService("RunService").RenderStepped,
                    function()
                        if not isFlying or not humanoidRootPart or not bodyGyro or not bodyVel then return end
                        
                        bodyGyro.CFrame = cam.CFrame
                        moveDir = humanoid.MoveDirection

                        if jumpPressed then
                            moveDir = moveDir + Vector3.new(0, 1, 0)
                        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                            moveDir = moveDir - Vector3.new(0, 1, 0)
                        end

                        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit * flySpeed end

                        bodyVel.Velocity = moveDir
                    end,
                    flyConnectionId,
                    "Fly Mode",
                    "ability"
                )

            else
                WindUI:Notify({ Title = "Fly Mode OFF!", Duration = 3, Icon = "x", })
                isFlying = false

                SafeDisconnect(flyConnectionId)
                flyConnection = nil
                if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
                if bodyVel then bodyVel:Destroy() bodyVel = nil end
            end
        end
    }))

   -- 4. TOGGLE WALK ON WATER (FIXED: RESPAWN SUPPORT)
    local walkOnWaterConnection = nil
    local walkOnWaterConnectionId = "walkOnWaterConnection"
    local isWalkOnWater = false
    local waterPlatform = nil
    
    local walkon = Reg("walkwat",ability:Toggle({
        Title = "Walk on Water",
        Value = false,
        Callback = function(state)
            -- Kita tidak mendefinisikan 'character' di sini agar logic tidak stuck di char lama

            if state then
                WindUI:Notify({ Title = "Walk on Water ON!", Duration = 3, Icon = "check", })
                isWalkOnWater = true
                
                -- Buat Platform jika belum ada
                if not waterPlatform then
                    waterPlatform = Instance.new("Part")
                    waterPlatform.Name = "WaterPlatform"
                    waterPlatform.Anchored = true
                    waterPlatform.CanCollide = true
                    waterPlatform.Transparency = 1 
                    waterPlatform.Size = Vector3.new(15, 1, 15) -- Ukuran diperbesar sedikit
                    waterPlatform.Parent = workspace
                end

                -- Pastikan koneksi lama mati dulu sebelum buat baru
                SafeDisconnect(walkOnWaterConnectionId)

                walkOnWaterConnection = SafeConnect(
                    game:GetService("RunService").RenderStepped,
                    function()
                        -- [FIX] Ambil Karakter TERBARU setiap frame
                    local character = LocalPlayer.Character
                    if not isWalkOnWater or not character then return end
                    
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end

                    -- Pastikan platform masih ada (kadang kehapus oleh game cleanup)
                    if not waterPlatform or not waterPlatform.Parent then
                        waterPlatform = Instance.new("Part")
                        waterPlatform.Name = "WaterPlatform"
                        waterPlatform.Anchored = true
                        waterPlatform.CanCollide = true
                        waterPlatform.Transparency = 1 
                        waterPlatform.Size = Vector3.new(15, 1, 15)
                        waterPlatform.Parent = workspace
                    end

                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {workspace.Terrain} 
                    rayParams.FilterType = Enum.RaycastFilterType.Include -- MODE WHITELIST
                    rayParams.IgnoreWater = false -- Pastikan Air terdeteksi

                    -- Tembak dari ketinggian di atas kepala
                    local rayOrigin = hrp.Position + Vector3.new(0, 5, 0) 
                    local rayDirection = Vector3.new(0, -500, 0)

                    local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)

                    -- 2. LOGIKA DETEKSI
                    if result and result.Material == Enum.Material.Water then
                        -- Jika menabrak AIR (Terrain Water)
                        local waterSurfaceHeight = result.Position.Y
                        
                        -- Taruh platform tepat di permukaan air
                        waterPlatform.Position = Vector3.new(hrp.Position.X, waterSurfaceHeight, hrp.Position.Z)
                        
                        -- Jika kaki player tenggelam sedikit di bawah air, angkat ke atas
                        if hrp.Position.Y < (waterSurfaceHeight + 2) and hrp.Position.Y > (waterSurfaceHeight - 5) then
                             -- Cek input jump biar gak stuck pas mau loncat dari air
                            if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                                hrp.CFrame = CFrame.new(hrp.Position.X, waterSurfaceHeight + 3.2, hrp.Position.Z)
                            end
                        end
                    else
                        -- Sembunyikan platform jika di darat
                        waterPlatform.Position = Vector3.new(hrp.Position.X, -500, hrp.Position.Z)
                    end
                end)

            else
                WindUI:Notify({ Title = "Walk on Water OFF!", Duration = 3, Icon = "x", })
                isWalkOnWater = false
                if walkOnWaterConnection then walkOnWaterConnection:Disconnect() walkOnWaterConnection = nil end
                if waterPlatform then waterPlatform:Destroy() waterPlatform = nil end
            end
        end
    }))

    -- OTHER (Wrapped in do block to reduce local register usage)
    do
        local other = utility:Section({
            Title = "Other",
            TextSize = 20,
        })

        -- Hide Username section (isolated in separate block)
        do
            local customName = ".gg/HookID"
            local customLevel = "Lvl. 999" 
            local isHideActive = false
            local hideConnection = nil
            local hideConnectionId = "hideConnection"

            local custname = Reg("cfakennme",other:Input({
                Title = "Custom Fake Name",
                Desc = "Fake name that will appear on the player's head.",
                Value = customName,
                Placeholder = "Hidden User",
                Icon = "user-x",
                Callback = function(text)
                    customName = text
                end
            }))

            local custlvl = Reg("cfkelvl",other:Input({
                Title = "Custom Fake Level",
                Desc = "Fake level (example: 'Lvl. 100' or 'Max').",
                Value = customLevel,
                Placeholder = "Lvl. 999",
                Icon = "bar-chart-2",
                Callback = function(text)
                    customLevel = text
                end
            }))

            local hideusn = Reg("hideallusr",other:Toggle({
        Title = "Hide All Usernames (Streamer Mode Only)",
        Value = false,
        Callback = function(state)
            isHideActive = state
            
            -- 1. Atur Visibilitas Leaderboard (PlayerList)
            pcall(function()
                game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not state)
            end)

            if state then
                WindUI:Notify({ Title = "Hide Name ON", Content = "Name & Level hidden.", Duration = 3, Icon = "eye-off" })
                
                -- 2. Loop Agresif (RenderStepped)
                SafeDisconnect(hideConnectionId)
                hideConnection = SafeConnect(
                    game:GetService("RunService").RenderStepped,
                    function()
                    for _, plr in ipairs(game.Players:GetPlayers()) do
                        if plr.Character then
                            -- A. Ubah Humanoid Name (Standard)
                            local hum = plr.Character:FindFirstChild("Humanoid")
                            if hum and hum.DisplayName ~= customName then 
                                hum.DisplayName = customName 
                            end

                            -- B. Ubah Custom UI (BillboardGui) - Logic Deteksi Cerdas
                            for _, obj in ipairs(plr.Character:GetDescendants()) do
                                if obj:IsA("BillboardGui") then
                                    for _, lbl in ipairs(obj:GetDescendants()) do
                                        if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
                                            if lbl.Visible then
                                                local txt = lbl.Text
                                                
                                                -- LOGIKA DETEKSI:
                                                -- 1. Jika teks mengandung Nama Asli Player -> Ubah jadi Custom Name
                                                if txt:find(plr.Name) or txt:find(plr.DisplayName) then
                                                    if txt ~= customName then
                                                        lbl.Text = customName
                                                    end
                                                
                                                -- 2. Jika teks terlihat seperti Level (angka atau 'Lvl.') -> Ubah jadi Custom Level
                                                -- Regex sederhana: mengecek apakah ada angka atau kata 'Lvl'
                                                elseif txt:match("%d+") or txt:lower():find("lvl") or txt:lower():find("level") then
                                                    -- Hindari mengubah teks UI lain yang bukan level (misal HP bar angka)
                                                    -- Biasanya level teksnya pendek (< 10 karakter)
                                                    if #txt < 15 and txt ~= customLevel then 
                                                        lbl.Text = customLevel
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            else
                WindUI:Notify({ Title = "Hide Name OFF", Content = "Display restored.", Duration = 3, Icon = "eye" })
                
                if hideConnection then 
                    hideConnection:Disconnect() 
                    hideConnection = nil 
                end
                
                -- Restore Nama Humanoid
                for _, plr in ipairs(game.Players:GetPlayers()) do
                    if plr.Character then
                        local hum = plr.Character:FindFirstChild("Humanoid")
                        if hum then hum.DisplayName = plr.DisplayName end
                    end
                end
            end
        end
        }))
        end -- Close Hide Username block

    -- 2. TOGGLE PLAYER ESP (Completely isolated block to avoid local register limit)
    do
        -- Get reference to other section from parent scope (capture it)
        local otherSection = other
        
        -- ESP variables (all in isolated scope)
        local runService = game:GetService("RunService")
        local players = game:GetService("Players")
        local LocalPlayer = game.Players.LocalPlayer
        local STUD_TO_M = 0.28
        local espEnabled = false
        local espConnections = {}

            local function removeESP(targetPlayer)
                if not targetPlayer then return end
                local data = espConnections[targetPlayer]
                if data then
                    if data.distanceConn then pcall(function() data.distanceConn:Disconnect() end) end
                    if data.charAddedConn then pcall(function() data.charAddedConn:Disconnect() end) end
                    if data.billboard and data.billboard.Parent then pcall(function() data.billboard:Destroy() end) end
                    espConnections[targetPlayer] = nil
                else
                    if targetPlayer.Character then
                        for _, v in ipairs(targetPlayer.Character:GetChildren()) do
                            if v.Name == "HookIDESP" and v:IsA("BillboardGui") then pcall(function() v:Destroy() end) end
                        end
                    end
                end
            end

            local function createESP(targetPlayer)
            if not targetPlayer or not targetPlayer.Character or targetPlayer == LocalPlayer then return end

            removeESP(targetPlayer)
            local char = targetPlayer.Character
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if not hrp then return end

            local BillboardGui = Instance.new("BillboardGui")
            BillboardGui.Name = "HookIDESP"
            BillboardGui.Adornee = hrp
            BillboardGui.Size = UDim2.new(0, 140, 0, 40)
            BillboardGui.AlwaysOnTop = true
            BillboardGui.StudsOffset = Vector3.new(0, 2.6, 0)
            BillboardGui.Parent = char

            local Frame = Instance.new("Frame")
            Frame.Size = UDim2.new(1, 0, 1, 0)
            Frame.BackgroundTransparency = 1
            Frame.BorderSizePixel = 0
            Frame.Parent = BillboardGui

            local NameLabel = Instance.new("TextLabel")
            NameLabel.Parent = Frame
            NameLabel.Size = UDim2.new(1, 0, 0.6, 0)
            NameLabel.Position = UDim2.new(0, 0, 0, 0)
            NameLabel.BackgroundTransparency = 1
            NameLabel.Text = tostring(targetPlayer.DisplayName or targetPlayer.Name)
            NameLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
            NameLabel.TextStrokeTransparency = 0.7
            NameLabel.Font = Enum.Font.GothamBold
            NameLabel.TextScaled = true

            local DistanceLabel = Instance.new("TextLabel")
            DistanceLabel.Parent = Frame
            DistanceLabel.Size = UDim2.new(1, 0, 0.4, 0)
            DistanceLabel.Position = UDim2.new(0, 0, 0.6, 0)
            DistanceLabel.BackgroundTransparency = 1
            DistanceLabel.Text = "0.0 m"
            DistanceLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
            NameLabel.TextStrokeTransparency = 0.85
            DistanceLabel.Font = Enum.Font.GothamSemibold
            DistanceLabel.TextScaled = true

            espConnections[targetPlayer] = { billboard = BillboardGui }

            local distanceConn = runService.RenderStepped:Connect(function()
                if not espEnabled or not hrp or not hrp.Parent then removeESP(targetPlayer) return end
                local localChar = LocalPlayer.Character
                local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")
                if localHRP then
                    local distStuds = (localHRP.Position - hrp.Position).Magnitude
                    local distMeters = distStuds * STUD_TO_M
                    DistanceLabel.Text = string.format("%.1f m", distMeters)
                end
            end)
            espConnections[targetPlayer].distanceConn = distanceConn

            local charAddedConn = targetPlayer.CharacterAdded:Connect(function()
                task.wait(0.8)
                if espEnabled then createESP(targetPlayer) end
            end)
            espConnections[targetPlayer].charAddedConn = charAddedConn
            end

            Reg("esp", otherSection:Toggle({
            Title = "Player ESP",
            Value = false,
            Callback = function(state)
                espEnabled = state
                if state then
                    WindUI:Notify({ Title = "ESP Aktif", Duration = 3, Icon = "eye", })
                    for _, plr in ipairs(players:GetPlayers()) do
                        if plr ~= LocalPlayer then createESP(plr) end
                    end
                    espConnections["playerAddedConn"] = players.PlayerAdded:Connect(function(plr)
                        task.wait(1)
                        if espEnabled then createESP(plr) end
                    end)
                    espConnections["playerRemovingConn"] = players.PlayerRemoving:Connect(function(plr)
                        removeESP(plr)
                    end)
                else
                    WindUI:Notify({ Title = "ESP Nonaktif", Content = "Semua marker ESP dihapus.", Duration = 3, Icon = "eye-off", })
                    for plr, _ in pairs(espConnections) do
                        if plr and typeof(plr) == "Instance" then removeESP(plr) end
                    end
                    if espConnections["playerAddedConn"] then espConnections["playerAddedConn"]:Disconnect() end
                    if espConnections["playerRemovingConn"] then espConnections["playerRemovingConn"]:Disconnect() end
                    espConnections = {}
                end
            end
        }))
    end -- Close ESP do block

    -- Wrap in do block to create new scope and avoid local register limit
    do
        local respawnin = other:Button({
            Title = "Reset Character (In Place)",
            Icon = "refresh-cw",
            Callback = function()
                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if not character or not hrp or not humanoid then
                    WindUI:Notify({ Title = "Gagal Reset", Content = "Karakter tidak ditemukan!", Duration = 3, Icon = "x", })
                    return
                end

                local lastPos = hrp.Position

                WindUI:Notify({ Title = "Reset Character...", Content = "Respawning di posisi yang sama...", Duration = 2, Icon = "rotate-cw", })
                humanoid:TakeDamage(999999)

                LocalPlayer.CharacterAdded:Wait()
                task.wait(0.5)
                local newChar = LocalPlayer.Character
                local newHRP = newChar:WaitForChild("HumanoidRootPart", 5)

                if newHRP then
                    newHRP.CFrame = CFrame.new(lastPos + Vector3.new(0, 3, 0))
                    WindUI:Notify({ Title = "Character Reset Sukses!", Content = "Kamu direspawn di posisi yang sama ￢ﾜﾅ", Duration = 3, Icon = "check", })
                else
                    WindUI:Notify({ Title = "Gagal Reset", Content = "HumanoidRootPart baru tidak ditemukan.", Duration = 3, Icon = "x", })
                end
            end
        })
    end
    
    end -- Close "other" section do block
    
end

