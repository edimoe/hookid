do
    local SettingsTab = Window:Tab({
        Icon = "settings",
        Title = "",
        Locked = false,
    })

    local ConfigSection = SettingsTab:Section({
        Title = "Config Manager",
        TextSize = 20,
    })

    -- Variabel Lokal
    local ConfigManager = Window.ConfigManager
    local SelectedConfigName = "HookID" -- Default
    local BaseFolder = "WindUI/" .. (Window.Folder or "HookID") .. "/config/"

    -- Helper: Update Dropdown
    local function RefreshConfigList(dropdown)
        local list = ConfigManager:AllConfigs()
        if #list == 0 then list = {"None"} end
        pcall(function() dropdown:Refresh(list) end)
    end

    local ConfigNameInput = ConfigSection:Input({
        Title = "Config Name",
        Desc = "New config name/that will be saved.",
        Value = "HookID",
        Placeholder = "e.g. LegitFarming",
        Icon = "file-pen",
        Callback = function(text)
            SelectedConfigName = text
        end
    })

    local ConfigDropdown = ConfigSection:Dropdown({
        Title = "Available Configs",
        Desc = "Select available config file.",
        Values = ConfigManager:AllConfigs() or {"None"},
        Value = "HookID",
        AllowNone = true,
        Callback = function(val)
            if val and val ~= "None" then
                SelectedConfigName = val
                ConfigNameInput:Set(val)
            end
        end
    })

    ConfigSection:Button({
        Title = "Refresh List",
        Icon = "refresh-ccw",
        Callback = function() RefreshConfigList(ConfigDropdown) end
    })

    ConfigSection:Divider()

    -- [FIXED] SAVE BUTTON
    ConfigSection:Button({
        Title = "Save Config",
        Desc = "Save current settings.",
        Icon = "save",
        Color = Color3.fromRGB(0, 255, 127),
        Callback = function()
            if SelectedConfigName == "" then return end
            
            -- 1. Save ke config utama dulu ("HookID.json")
            HookIDConfig:Save()
            task.wait(0.1)

            -- 2. Jika nama beda, salin isi "HookID.json" ke "NamaBaru.json"
            if SelectedConfigName ~= "HookID" then
                local success, err = pcall(function()
                    local mainContent = readfile(BaseFolder .. "HookID.json")
                    writefile(BaseFolder .. SelectedConfigName .. ".json", mainContent)
                end)
                
                if not success then
                    WindUI:Notify({ Title = "Error Write", Content = "Failed to copy file.", Duration = 3, Icon = "x" })
                    return
                end
            end

            WindUI:Notify({ Title = "Saved!", Content = "Config: " .. SelectedConfigName, Duration = 2, Icon = "check" })
            RefreshConfigList(ConfigDropdown)
        end
    })

    -- [FIXED SMART LOAD] LOAD BUTTON
    ConfigSection:Button({
        Title = "Load Config",
        Icon = "download",
        Callback = function()
            if SelectedConfigName == "" then return end
            
            -- Panggil fungsi Smart Load buatan kita
            SmartLoadConfig(SelectedConfigName)
        end
    })

    -- DELETE BUTTON
    ConfigSection:Button({
        Title = "Delete Config",
        Icon = "trash-2",
        Color = Color3.fromRGB(255, 80, 80),
        Callback = function()
            if SelectedConfigName == "" or SelectedConfigName == "hookid" then 
                WindUI:Notify({ Title = "Failed", Content = "Cannot delete default/empty config.", Duration = 3 })
                return 
            end
            
            local path = BaseFolder .. SelectedConfigName .. ".json"
            
            if isfile(path) then
                delfile(path)
                WindUI:Notify({ Title = "Deleted", Content = SelectedConfigName .. " deleted.", Duration = 2, Icon = "trash" })
                RefreshConfigList(ConfigDropdown)
                ConfigNameInput:Set("hookid")
                SelectedConfigName = "hookid"
            else
                WindUI:Notify({ Title = "Error", Content = "File not found.", Duration = 3, Icon = "x" })
            end
        end
    })
    
    SettingsTab:Keybind({
        Title = "Keybind",
        Desc = "Keybind to open/close UI",
        Value = "F",
        Callback = function(v)
            Window:SetToggleKey(Enum.KeyCode[v])
        end
    })
    
end
