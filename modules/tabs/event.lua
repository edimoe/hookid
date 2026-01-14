do
	local Event = Window:Tab({
		Icon = "calendar",
		Title = "",
		Locked = false,
	})

	-- Ancient Lochness Event Variables
	local lastPositionBeforeEvent = nil
	local autoJoinEventActive = false
	local LOCHNESS_POS = Vector3.new(6063.347, -585.925, 4713.696)
	local LOCHNESS_LOOK = Vector3.new(-0.376, -0.000, -0.927)

	local EventSyncThread = nil
	
	-- Christmas Cave Event Variables
	local lastPositionBeforeChristmasCave = nil
	local autoJoinChristmasCaveActive = false
	local CHRISTMAS_CAVE_POS = Vector3.new(605.353, -580.581, 8885.047)
	local CHRISTMAS_CAVE_LOOK = Vector3.new(-1.000, -0.000, -0.012)
	
	-- *** AUTO UNLOCK RUIN DOOR ***
	local AUTO_UNLOCK_STATE = false
	local AUTO_UNLOCK_THREAD = nil
	local AUTO_UNLOCK_ATTEMPT_THREAD = nil
	local RUIN_COMPLETE_DELAY = 1.5
	local RUIN_DOOR_PATH = workspace["RUIN INTERACTIONS"] and workspace["RUIN INTERACTIONS"].Door
	local ITEM_FISH_NAMES = {"Freshwater Piranha", "Goliath Tiger", "Sacred Guardian Squid", "Crocodile"}
	local SACRED_TEMPLE_POS = FishingAreas["Sacred Temple"].Pos
	local SACRED_TEMPLE_LOOK = FishingAreas["Sacred Temple"].Look
	local RUIN_DOOR_REMOTE = GetRemote(RPath, "RE/PlacePressureItem")
	local RUIN_DOOR_STATUS_PARAGRAPH  -- Will be assigned later
	local RUIN_AUTO_UNLOCK_TOGGLE
	local RF_UpdateAutoFishingState = GetRemote(RPath, "RF/UpdateAutoFishingState")
	local RE_EquipToolFromHotbar_Ruin = GetRemote(RPath, "RE/EquipToolFromHotbar")
	local RF_ChargeFishingRod_Ruin = GetRemote(RPath, "RF/ChargeFishingRod")
	local RF_RequestFishingMinigameStarted_Ruin = GetRemote(RPath, "RF/RequestFishingMinigameStarted")
	local RE_FishingCompleted_Ruin = GetRemote(RPath, "RE/FishingCompleted")
	local RF_CancelFishingInputs_Ruin = GetRemote(RPath, "RF/CancelFishingInputs")
	
	-- Ruin Door Helper Functions
	local function GetRuinDoorStatus()
		local ruinDoor = RUIN_DOOR_PATH
		local status = "LOCKED 🚫"
		
		if ruinDoor and ruinDoor:FindFirstChild("RuinDoor") then
			local LDoor = ruinDoor.RuinDoor:FindFirstChild("LDoor")
			
			if LDoor then
				local currentX = nil
				
				if LDoor:IsA("BasePart") then
					currentX = LDoor.Position.X
				elseif LDoor:IsA("Model") then
					local success, pivot = pcall(function() return LDoor:GetPivot() end)
					if success and pivot then
						currentX = pivot.Position.X
					end
				end
				
				if currentX ~= nil then
					if currentX > 6075 then
						status = "UNLOCKED ✅"
					end
				end
			end
		end
		
		if RUIN_DOOR_STATUS_PARAGRAPH then
			RUIN_DOOR_STATUS_PARAGRAPH:SetTitle("Ruin Door Status: " .. status)
		end
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
		if not (RE_EquipToolFromHotbar_Ruin and RF_ChargeFishingRod_Ruin and RF_RequestFishingMinigameStarted_Ruin and RE_FishingCompleted_Ruin and RF_CancelFishingInputs_Ruin) then
			return false
		end
		
		pcall(function() RE_EquipToolFromHotbar_Ruin:FireServer(1) end)
		
		local timestamp = os.time() + os.clock()
		pcall(function() RF_ChargeFishingRod_Ruin:InvokeServer(timestamp) end)
		pcall(function() RF_RequestFishingMinigameStarted_Ruin:InvokeServer(-139.630452165, 0.99647927980797) end)
		
		task.wait(RUIN_COMPLETE_DELAY)

		pcall(function() RE_FishingCompleted_Ruin:FireServer() end)
		task.wait(0.3)
		pcall(function() RF_CancelFishingInputs_Ruin:FireServer() end)
		
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

			while AUTO_UNLOCK_STATE and GetRuinDoorStatus() == "LOCKED 🚫" do
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
				if RUIN_DOOR_STATUS_PARAGRAPH then
					RUIN_DOOR_STATUS_PARAGRAPH:SetTitle("Ruin Door Status: " .. doorStatus)
				end

				if doorStatus == "LOCKED 🚫" then
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
						
						if RUIN_DOOR_STATUS_PARAGRAPH then
							RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("Searching for item: " .. missingItem .. ". Fishing...")
						end
						runInstantFish()
						task.wait(RUIN_COMPLETE_DELAY + 0.5)
						
					else
						if RUIN_DOOR_STATUS_PARAGRAPH then
							RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("All items found! Aggressive Unlock Loop running...")
						end
						isFarming = false
						
						task.wait(1)
					end
				else
					if RUIN_DOOR_STATUS_PARAGRAPH then
						RUIN_DOOR_STATUS_PARAGRAPH:SetDesc("Door unlocked! Process complete.")
					end
					
					if lastPositionBeforeEvent_Ruin then
						WindUI:Notify({ Title = "Ruin Door: Complete", Content = "Returning to original position...", Duration = 3, Icon = "check" })
						task.wait(2)
						TeleportToLookAt(lastPositionBeforeEvent_Ruin.Pos, lastPositionBeforeEvent_Ruin.Look)
						lastPositionBeforeEvent_Ruin = nil
					end
					
					break
				end
				
				task.wait(0.5)
			end
		end)
	end
    local loknes = Event:Section({
        Title = "Ancient Lochness Event",
        TextSize = 20,
    })
	local CountdownParagraph = loknes:Paragraph({
		Title = "Event Countdown: Waiting...",
		Content = "Status: Trying to sync event...",
		Icon = "clock"
	})
	local StatsParagraph = loknes:Paragraph({
		Title = "Event Stats: N/A",
		Content = "Timer: N/A\nCaught: N/A\nChance: N/A",
		Icon = "trending-up"
	})
	
	local LochnessToggle
	
	local function UpdateEventStats()
		local gui = GetEventGUI()
		
		if not gui then
			CountdownParagraph:SetTitle("Event Countdown: GUI Not Found ￢ﾝﾌ")
			CountdownParagraph:SetDesc("Make sure 'Event Tracker' is loaded in workspace.")
			StatsParagraph:SetTitle("Event Stats: N/A")
			StatsParagraph:SetDesc("Timer: N/A\nCaught: N/A\nChance: N/A")
			return false
		end
		
		local countdownText = gui.Countdown and (gui.Countdown.ContentText or gui.Countdown.Text) or "N/A"
		local timerText = gui.Timer and (gui.Timer.ContentText or gui.Timer.Text) or "N/A"
		local quantityText = gui.Quantity and (gui.Quantity.ContentText or gui.Quantity.Text) or "N/A"
		local oddsText = gui.Odds and (gui.Odds.ContentText or gui.Odds.Text) or "N/A"

		CountdownParagraph:SetTitle("Ancient Lochness Start In:")
		CountdownParagraph:SetDesc(countdownText)

		StatsParagraph:SetTitle("Ancient Lochness Stats")
		StatsParagraph:SetDesc(string.format("- Timer: %s\n- Caught: %s\n- Chance: %s",
			timerText, quantityText, oddsText))

		local isEventActive = timerText:find("M") and timerText:find("S") and not timerText:match("^0M 0S")
		
		return isEventActive
	end

	local function RunEventSyncLoop()
		if EventSyncThread then task.cancel(EventSyncThread) end

		EventSyncThread = task.spawn(function()
			local isTeleportedToEvent = false
			
			while true do
				local isEventActive = UpdateEventStats()
				
				if autoJoinEventActive then
					if isEventActive and not isTeleportedToEvent then
						if lastPositionBeforeEvent == nil then
							local hrp = GetHRP()
							if hrp then
								lastPositionBeforeEvent = {Pos = hrp.Position, Look = hrp.CFrame.LookVector}
								WindUI:Notify({ Title = "Position Saved", Content = "Position before Event saved.", Duration = 2, Icon = "save" })
							end
						end
						
						TeleportToLookAt(LOCHNESS_POS, LOCHNESS_LOOK)
						isTeleportedToEvent = true
						WindUI:Notify({ Title = "Auto Join ON", Content = "Teleport to Ancient Lochness.", Duration = 4, Icon = "zap" })

					elseif isTeleportedToEvent and not isEventActive and lastPositionBeforeEvent ~= nil then
						-- UPDATE: Tunggu 15 detik sebelum balik
						WindUI:Notify({ Title = "Event Completed", Content = "Waiting 15 seconds before returning...", Duration = 5, Icon = "clock" })
						task.wait(15) 
						
						TeleportToLookAt(lastPositionBeforeEvent.Pos, lastPositionBeforeEvent.Look)
						lastPositionBeforeEvent = nil
						isTeleportedToEvent = false
						WindUI:Notify({ Title = "Teleport Back", Content = "Returning to original position.", Duration = 3, Icon = "repeat" })
					end
				end

				task.wait(0.5)
			end
		end)
	end
	
	RunEventSyncLoop()
	
	local LochnessToggle = Reg("tloknes",loknes:Toggle({
		Title = "Auto Join Ancient Lochness Event",
		Desc = "Automatically teleport to event when active, and return when event ends.",
		Value = false,
		Callback = function(state)
			autoJoinEventActive = state
			if state then
				WindUI:Notify({ Title = "Auto Join ON", Content = "Starting to monitor Ancient Lochness event.", Duration = 3, Icon = "check" })
			else
				WindUI:Notify({ Title = "Auto Join OFF", Content = "Monitoring stopped.", Duration = 3, Icon = "x" })
			end
		end
	}))

	
	RUIN_DOOR_STATUS_PARAGRAPH = loknes:Paragraph({
		Title = "Ruin Door Status: N/A",
		Content = "Status Locked/Unlocked. Press Toggle to start monitoring."
	})

	local lochnessdelay = loknes:Input({
		Title = "Ruin Door Instant Delay",
		Desc = "Delay (in seconds) for Normal Instant Fish when farming Ruin Door items. Default: 1.5s.",
		Value = tostring(RUIN_COMPLETE_DELAY),
		Placeholder = "1.5",
		Callback = function(input)
			local newDelay = tonumber(input)
			if newDelay and newDelay >= 0.5 then
				RUIN_COMPLETE_DELAY = newDelay
			else
				WindUI:Notify({ Title = "Input Invalid", Content = "Minimum delay 0.5 seconds.", Duration = 2, Icon = "alert-triangle" })
			end
		end
	})

	local RUIN_AUTO_UNLOCK_TOGGLE = loknes:Toggle({
		Title = "Auto Unlock Ruin Door",
		Desc = "Automatically farm 4 missing items using Normal Instant Fish, then unlock the door.",
		Value = false,
		Callback = function(state)
		AUTO_UNLOCK_STATE = state
		if state then
			if GetRuinDoorStatus() == "UNLOCKED ￢ﾜﾅ" then
				WindUI:Notify({ Title = "Ruin Door", Content = "Door already opened. Auto Unlock not running.", Duration = 4, Icon = "info" })
					return false
			end	
			WindUI:Notify({ Title = "Auto Unlock ON", Content = "Starting to monitor Ruin Door and Inventory.", Duration = 3, Icon = "check" })
			RunAutoUnlockLoop()
			else
					if AUTO_UNLOCK_THREAD then task.cancel(AUTO_UNLOCK_THREAD) AUTO_UNLOCK_THREAD = nil end
					if AUTO_UNLOCK_ATTEMPT_THREAD then task.cancel(AUTO_UNLOCK_ATTEMPT_THREAD) AUTO_UNLOCK_ATTEMPT_THREAD = nil end
			WindUI:Notify({ Title = "Auto Unlock OFF", Content = "Ruin Door process stopped.", Duration = 3, Icon = "x" })
		end
end
	})

end

