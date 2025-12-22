do
	local Event = Window:Tab({
		Icon = "calendar",
		Title = "",
		Locked = false,
	})

	local EventSyncThread = nil
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

	-- =================================================================
	-- CHRISTMAS CAVE EVENT SECTION
	-- =================================================================
	local christmascave = Event:Section({
		Title = "Christmas Cave Event",
		TextSize = 20,
	})
	
	local ChristmasCaveCountdownParagraph = christmascave:Paragraph({
		Title = "Event Countdown: Waiting...",
		Content = "Status: Trying to sync event...",
		Icon = "clock"
	})
	
	local ChristmasCaveStatsParagraph = christmascave:Paragraph({
		Title = "Event Stats: N/A",
		Content = "Timer: N/A",
		Icon = "trending-up"
	})
	
	local ChristmasCaveSyncThread = nil
	local ChristmasCaveUpdateThread = nil -- Thread untuk update UI stat (selalu berjalan)
	
	-- Christmas Cave Event Schedule: Every 2 hours, lasts 30 minutes
	local CHRISTMAS_CAVE_CYCLE_MINUTES = 120 -- 2 hours
	local CHRISTMAS_CAVE_DURATION_MINUTES = 30 -- Event duration
	
	local function UpdateChristmasCaveStats()
		local gui = GetEventGUI()
		
		if not gui then
			ChristmasCaveCountdownParagraph:SetTitle("Event Countdown: GUI Not Found")
			ChristmasCaveCountdownParagraph:SetDesc("Make sure 'Event Tracker' is loaded in workspace.")
			ChristmasCaveStatsParagraph:SetTitle("Event Stats: N/A")
			ChristmasCaveStatsParagraph:SetDesc("Timer: N/A")
			return false
		end
		
		-- Get timer from GUI for reference (to sync with server time accuracy)
		local timerText = gui.Timer and (gui.Timer.ContentText or gui.Timer.Text) or "N/A"
		
		-- Calculate Christmas Cave countdown based on 2-hour cycle (not from GUI countdown which is for other events)
		local currentTime = os.time()
		local timeTable = os.date("*t", currentTime)
		local totalMinutes = (timeTable.hour * 60) + timeTable.min
		local cyclePosition = totalMinutes % CHRISTMAS_CAVE_CYCLE_MINUTES
		
		local eventStatus = "Event Closed"
		local isEventActive = false
		local minutesUntilNext = 0
		
		-- Christmas Cave is active for first 30 minutes of each 2-hour cycle
		if cyclePosition < CHRISTMAS_CAVE_DURATION_MINUTES then
			eventStatus = "Event Started"
			isEventActive = true
			minutesUntilNext = CHRISTMAS_CAVE_DURATION_MINUTES - cyclePosition -- Time until event ends
		else
			eventStatus = "Event Closed"
			isEventActive = false
			minutesUntilNext = CHRISTMAS_CAVE_CYCLE_MINUTES - cyclePosition -- Time until next event starts
		end
		
		-- Calculate seconds for more accurate countdown (using current seconds)
		local currentSeconds = timeTable.sec or 0
		local totalSecondsUntilNext = (minutesUntilNext * 60) - currentSeconds
		if totalSecondsUntilNext < 0 then totalSecondsUntilNext = 0 end
		
		-- Format countdown for Christmas Cave (2-hour cycle)
		local hours = math.floor(totalSecondsUntilNext / 3600)
		local mins = math.floor((totalSecondsUntilNext % 3600) / 60)
		local secs = math.floor(totalSecondsUntilNext % 60)
		
		local countdownText = ""
		if hours > 0 then
			countdownText = string.format("%dH %02dM %02dS", hours, mins, secs)
		elseif mins > 0 then
			countdownText = string.format("%dM %02dS", mins, secs)
		else
			countdownText = string.format("%dS", secs)
		end
		
		-- Update UI with Christmas Cave specific countdown (2-hour cycle)
		-- Ubah title dan format berdasarkan status event untuk lebih jelas
		if isEventActive then
			-- Event sedang aktif - tampilkan waktu tersisa sampai event berakhir
			ChristmasCaveCountdownParagraph:SetTitle("Event Active - Time Until Ends:")
			ChristmasCaveCountdownParagraph:SetDesc(countdownText)
		else
			-- Event belum aktif - tampilkan waktu sampai event dimulai
			ChristmasCaveCountdownParagraph:SetTitle("Event Closed - Start In:")
			ChristmasCaveCountdownParagraph:SetDesc(countdownText)
		end
		
		ChristmasCaveStatsParagraph:SetTitle("Christmas Cave Stats")
		ChristmasCaveStatsParagraph:SetDesc(string.format("Status: %s\nCycle: Every 2 hours (30 min duration)", eventStatus))
		
		return isEventActive
	end
	
	-- Thread untuk update UI stat (selalu berjalan, tidak tergantung auto join)
	local function RunChristmasCaveUpdateLoop()
		if ChristmasCaveUpdateThread then 
			task.cancel(ChristmasCaveUpdateThread)
			ChristmasCaveUpdateThread = nil
		end
		
		ChristmasCaveUpdateThread = task.spawn(function()
			while true do
				UpdateChristmasCaveStats()
				task.wait(1) -- Update setiap 1 detik
			end
		end)
	end
	
	local function RunChristmasCaveSyncLoop()
		if ChristmasCaveSyncThread then 
			task.cancel(ChristmasCaveSyncThread) 
			ChristmasCaveSyncThread = nil
		end
		
		ChristmasCaveSyncThread = task.spawn(function()
			local isTeleportedToEvent = false
			
			while true do
				-- Cek apakah auto join masih aktif, jika tidak break loop
				if not autoJoinChristmasCaveActive then
					break
				end
				
				local isEventActive = UpdateChristmasCaveStats()
				
				if isEventActive and not isTeleportedToEvent then
					if lastPositionBeforeChristmasCave == nil then
						local hrp = GetHRP()
						if hrp then
							lastPositionBeforeChristmasCave = {
								Pos = hrp.Position,
								Look = hrp.CFrame.LookVector
							}
							WindUI:Notify({ 
								Title = "Position Saved", 
								Content = "Position before Event saved.", 
								Duration = 2, 
								Icon = "save" 
							})
						end
					end
					
					TeleportToLookAt(CHRISTMAS_CAVE_POS, CHRISTMAS_CAVE_LOOK)
					isTeleportedToEvent = true
					WindUI:Notify({ 
						Title = "Auto Join ON", 
						Content = "Teleport to Christmas Cave.", 
						Duration = 4, 
						Icon = "zap" 
					})
					
				elseif isTeleportedToEvent and not isEventActive and lastPositionBeforeChristmasCave ~= nil then
					-- Tunggu 15 detik sebelum kembali
					WindUI:Notify({ 
						Title = "Event Completed", 
						Content = "Waiting 15 seconds before returning...", 
						Duration = 5, 
						Icon = "clock" 
					})
					task.wait(15)
					
					-- Cek lagi apakah masih aktif sebelum teleport back
					if autoJoinChristmasCaveActive and lastPositionBeforeChristmasCave then
						TeleportToLookAt(lastPositionBeforeChristmasCave.Pos, lastPositionBeforeChristmasCave.Look)
						lastPositionBeforeChristmasCave = nil
						isTeleportedToEvent = false
						WindUI:Notify({ 
							Title = "Teleport Back", 
							Content = "Returning to original position.", 
							Duration = 3, 
							Icon = "repeat" 
						})
					end
				end
				
				task.wait(0.5)
			end
			
			-- Cleanup thread reference
			ChristmasCaveSyncThread = nil
		end)
	end
	
	-- Start update thread untuk UI stat (selalu berjalan)
	RunChristmasCaveUpdateLoop()
	
	-- Button untuk teleport manual ke Christmas Cave
	local christmascaveTeleportBtn = christmascave:Button({
		Title = "Teleport to Christmas Cave",
		Icon = "map-pin",
		Content = "Teleport manually to Christmas Cave event location.",
		Callback = function()
			local hrp = GetHRP()
			if not hrp then
				WindUI:Notify({ Title = "Error", Content = "Character not found.", Duration = 3, Icon = "x" })
				return
			end
			
			TeleportToLookAt(CHRISTMAS_CAVE_POS, CHRISTMAS_CAVE_LOOK)
			WindUI:Notify({ 
				Title = "Teleport Success", 
				Content = "Teleported to Christmas Cave event location.", 
				Duration = 3, 
				Icon = "map-pin" 
			})
		end
	})
	
	local ChristmasCaveToggle = Reg("tchristmascave", christmascave:Toggle({
		Title = "Auto Join Christmas Cave Event",
		Desc = "Automatically teleport to event when active, and return when event ends.",
		Value = false,
		Callback = function(state)
			autoJoinChristmasCaveActive = state
			if state then
				-- Reset state untuk memastikan clean start
				lastPositionBeforeChristmasCave = nil
				-- Start sync loop
				RunChristmasCaveSyncLoop()
				WindUI:Notify({ 
					Title = "Auto Join ON", 
					Content = "Starting to monitor Christmas Cave event.", 
					Duration = 3, 
					Icon = "check" 
				})
			else
				-- Cancel thread dan reset state
				if ChristmasCaveSyncThread then 
					task.cancel(ChristmasCaveSyncThread)
					ChristmasCaveSyncThread = nil
				end
				lastPositionBeforeChristmasCave = nil
				WindUI:Notify({ 
					Title = "Auto Join OFF", 
					Content = "Monitoring stopped.", 
					Duration = 3, 
					Icon = "x" 
				})
			end
		end
	}))

end

GetRuinDoorStatus()
