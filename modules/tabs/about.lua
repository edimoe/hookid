do
    local about = Window:Tab({
        Icon = "info",
        Title = "",
        Locked = false,
    })

    about:Section({
        Title = "Join Discord Server HookID",
        TextSize = 20,
    })

    about:Paragraph({
        Title = "HookID Community",
        Desc = "Join Our Community Discord Server to get the latest updates, support, and connect with other users!",
        Image = "rbxassetid://89525545448838",
        ImageSize = 24,
        Buttons = {
            {
                Title = "Copy Link",
                Icon = "link",
                Callback = function()
                    setclipboard("https://dsc.gg/hookid")
                    WindUI:Notify({
                        Title = "Link Disalin!",
                        Content = "Link Discord HookID berhasil disalin.",
                        Duration = 3,
                        Icon = "copy",
                    })
                end,
            }
        }
    })

    about:Divider()
    
    about:Section({
        Title = "What's New?",
        TextSize = 24,
        FontWeight = Enum.FontWeight.SemiBold,
    })

    about:Space()

    about:Paragraph({
        Title = "Version 1.0.0",
        Desc = "- 04 Dec 2025 Release Premium Version",
    })
end

-- =================================================================
-- FLOATING ICON (FIXED: NO GLITCH & SMOOTH DRAG)
-- =================================================================
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Variabel Koneksi Global (PENTING BIAR GA TUMPUK)
local uisConnection = nil

-- Variabel Logika Dragging
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function CreateFloatingIcon()
    local existingGui = PlayerGui:FindFirstChild("CustomFloatingIcon_Nexus")
    if existingGui then existingGui:Destroy() end

    local FloatingIconGui = Instance.new("ScreenGui")
    FloatingIconGui.Name = "CustomFloatingIcon_Nexus"
    FloatingIconGui.DisplayOrder = 999
    FloatingIconGui.ResetOnSpawn = false 

    local FloatingFrame = Instance.new("Frame")
    FloatingFrame.Name = "FloatingFrame"
    FloatingFrame.Position = UDim2.new(0, 55, 0.5, 0) 
    FloatingFrame.Size = UDim2.fromOffset(52, 52) 
    FloatingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FloatingFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
    FloatingFrame.BackgroundTransparency = 0.05
    FloatingFrame.BorderSizePixel = 0
    FloatingFrame.Parent = FloatingIconGui

    -- Ocean Teal Gradient
    local FrameGradient = Instance.new("UIGradient")
    FrameGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 160, 140)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 90))
    })
    FrameGradient.Rotation = 135
    FrameGradient.Parent = FloatingFrame

    -- Neon Glow Stroke
    local FrameStroke = Instance.new("UIStroke")
    FrameStroke.Color = Color3.fromRGB(0, 230, 190)
    FrameStroke.Thickness = 2.5
    FrameStroke.Transparency = 0.2
    FrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FrameStroke.Parent = FloatingFrame

    -- Rounded Corner
    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 16) 
    FrameCorner.Parent = FloatingFrame

    -- Floating Icon (Image)
    local IconLabel = Instance.new("ImageLabel")
    IconLabel.Name = "Icon"
    IconLabel.Image = "rbxassetid://89525545448838"
    IconLabel.BackgroundTransparency = 1
    IconLabel.Size = UDim2.new(1, 0, 1, 0)
    IconLabel.Position = UDim2.new(0, 0, 0, 0)
    IconLabel.Parent = FloatingFrame
    
    FloatingIconGui.Parent = PlayerGui
    return FloatingIconGui, FloatingFrame
end

local function SetupFloatingIcon(FloatingIconGui, FloatingFrame)
    -- [FIX] Putuskan koneksi lama jika ada (Mencegah glitch tumpuk)
    if uisConnection then 
        uisConnection:Disconnect() 
        uisConnection = nil
    end

    local function update(input)
        local delta = input.Position - dragStart
        FloatingFrame.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end

    -- Event: Mulai Sentuh/Klik
    FloatingFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = FloatingFrame.Position
            
            local didMove = false

            -- Tracking release
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    connection:Disconnect()
                    
                    -- Logika: Jika tidak geser (atau geser dikit banget), berarti KLIK
                    if not didMove then
                        if Window and Window.Toggle then
                            Window:Toggle()
                        end
                    end
                end
            end)
            
            -- Tracking movement khusus input ini untuk status 'didMove'
            local moveConnection
            moveConnection = input.Changed:Connect(function()
                 if dragging and (input.Position - dragStart).Magnitude > 5 then
                     didMove = true
                     moveConnection:Disconnect()
                 end
            end)
        end
    end)

    -- Event: Pergerakan Input (Menyiapkan dragInput)
    FloatingFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    -- [FIX] Event Global Disimpan ke Variabel uisConnection
    uisConnection = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)

    -- Handler: Sembunyikan Icon saat UI Terbuka
    if Window then
        Window:OnOpen(function()
            FloatingIconGui.Enabled = false
        end)
        Window:OnClose(function()
            FloatingIconGui.Enabled = true
        end)
    end
end

local function InitializeIcon()
    -- Pastikan karakter sudah load
    if not game.Players.LocalPlayer.Character then
        game.Players.LocalPlayer.CharacterAdded:Wait()
    end
    
    local gui, frame = CreateFloatingIcon()
    if gui and frame then
        SetupFloatingIcon(gui, frame)
    end
end

-- Auto Reload Icon saat Respawn
game.Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1) 
    InitializeIcon()
end)

WindUI:Notify({ 
    Title = "HOOKID Fish Hub Loaded", 
    Content = "Press [F] to toggle menu", 
    Duration = 5, 
    Icon = "anchor" 
})
-- [[ AUTO LOAD & SAVE LOOP ]]
task.spawn(function()
    task.wait(2) -- Tunggu UI load sempurna
    
end)
InitializeIcon()
