-----------------------------------------------------
-- INFO
-----------------------------------------------------


script_name("Stats Panel for HZRP")
script_author("Bear")
script_version("1.0.0")

-----------------------------------------------------
-- HEADERS & CONFIG
-----------------------------------------------------


local sampev = require "lib.samp.events"
local inicfg = require "inicfg"
local ig = require "lib.moon-imgui-1-1-5.imgui"
local fontFlags = require("moonloader").font_flag
local vk = require "vkeys"

local config_dir_path = getWorkingDirectory() .. "\\config\\"
if not doesDirectoryExist(config_dir_path) then createDirectory(config_dir_path) end

local config_file_path = config_dir_path .. "Stats Panel for HZRP" .. script.this.version .. ".ini"

config_dir_path = nil

local config

if doesFileExist(config_file_path) then
	config = inicfg.load(nil, config_file_path)
else
	local new_config = io.open(config_file_path, "w")
	new_config:close()
	new_config = nil
	
	config = {
		Display = {
			panel = false, box = false, refreshIndicator = false, refreshCooldown = 10,
			
			nameAndLevel = false, playingHours = false, phoneNumber = false, warnings = false,
			job1 = false, job2 = false,
			totalWealth = false, cash = false, bankBalance = false, insurance = false,
			respectPoints = false, radio = false,
			materials = false, pot = false, crack = false,
			rope = false, cigars = false, sprunk = false, spray = false, seeds = false, blindfolds = false, refTokens = false, donator = false,
			
			tire = false, firstaid = false, bugSweep = false, lockpicks = false
		},
		
		Text = {
			posX = 0.962, posY = 0.4, alignment = 3,
			size = 12, isBold = true, isItalicised = false, isBordered = true, isShadowed = true, isAllCaps = true,
			boxOpacity = tonumber("C8", 16)
		}
	}

	if not inicfg.save(config, config_file_path) then
		sampAddChatMessage("---- {00EECC}Stats Panel for HZRP {FFFFFF}- Config file creation failed - contact the developer for help.", -1)
	end
end


-----------------------------------------------------
-- GLOBAL VARIABLES & FUNCTIONS
-----------------------------------------------------


local isRefreshNeeded, isAnyStatPending, isPlayerMuted, isServerRequirementMet = false, false, false, false
local isPlayerMovingPanel, isMoveRequestedFromMenu,  isBoxEnabledTemp, isPanelConfigured = false, false, false, false
local isRefreshTextNeededOnce, isRefreshTextNeededTwice = (config.Display.panel and true or false), false

local function requestRefreshText()
	if isPanelConfigured then
		isRefreshTextNeededOnce = true
	else
		isRefreshTextNeededTwice = true
	end
end

local maxStatLength = 0 -- set in main

local window_resX, window_resY

local function fetchRes()
	window_resX, window_resY = getScreenResolution()
end

fetchRes()

local hasResChanged = true

local function textSize()
	return window_resY * config.Text.size / 1000
end

local emptyPanelText = {
	str = "--",
	str_length = 0, posX = 0, posY = 0 -- set in main
}

-- Set values in main
local drawBox = {
	posX = 0,
	posY = 0,
	
	sizeX = 0,
	sizeY = 0
}

local function configureEmptyPanel()
	drawBox.sizeX = emptyPanelText.str_length + textSize()
	drawBox.posX = window_resX * config.Text.posX - ((config.Text.alignment - 1) / 2 * drawBox.sizeX)
	
	drawBox.sizeY = textSize() * 2.5
	drawBox.posY = window_resY * config.Text.posY
	
	emptyPanelText.posX = drawBox.posX + (textSize() / 2)
	emptyPanelText.posY = drawBox.posY + (textSize() / 4)
end

local font

local function configureFont()
	font = renderCreateFont("Calibri", textSize(), (config.Text.isBold and fontFlags.BOLD or 0) + (config.Text.isItalicised and fontFlags.ITALICS or 0) + (config.Text.isBordered and fontFlags.BORDER or 0) + (config.Text.isShadowed and fontFlags.SHADOW or 0))
	emptyPanelText.str_length = renderGetFontDrawTextLength(font, emptyPanelText.str, true)
end

configureFont()

local function getHexOpacity(opacity_base10)
	local opacity_hex = ""
	local quotient, remainder = math.floor(opacity_base10 / 16), opacity_base10 % 16
	
	if quotient > 9 then
		if quotient == 10 then opacity_hex = "A" elseif quotient == 11 then opacity_hex = "B" elseif quotient == 12 then opacity_hex = "C" elseif quotient == 13 then opacity_hex = "D" elseif quotient == 14 then opacity_hex = "E" elseif quotient == 15 then opacity_hex = "F" end
	elseif quotient > 0 then
		opacity_hex = tostring(quotient)
	end
	
	if remainder > 9 then
		if remainder == 10 then opacity_hex = opacity_hex .. "A" elseif remainder == 11 then opacity_hex = opacity_hex .. "B" elseif remainder == 12 then opacity_hex = opacity_hex .. "C" elseif remainder == 13 then opacity_hex = opacity_hex .. "D" elseif remainder == 14 then opacity_hex = opacity_hex .. "E" elseif remainder == 15 then opacity_hex = opacity_hex .. "F" end
	else
		opacity_hex = opacity_hex .. tostring(remainder)
	end
	
	return opacity_hex
end

boxColor = nil

local function setDrawboxColor(opacity, color)
	loadstring("boxColor = " .. "0x" .. opacity .. color)()
end

setDrawboxColor(getHexOpacity(config.Text.boxOpacity), "000000")

local isPanelEmpty = true

local areStatLinesInUse, areInventoryLinesInUse = false, false

local statLines = {
	line1 = {}, line2 = {}, line3 = {}, line4 = {}, line5 = {}, line6 = {}, line7 = {}, line8 = {}
}

for _, selectedLine in pairs(statLines) do
	selectedLine = {isLineTextAwaited = false, isLineRequestedManually = false, lineText = ""}
end

local inventoryLines = {
	line1 = {}, line2 = {}, line3 = {}, line4 = {}, line5 = {}, line6 = {}, line7 = {}
}

for _, selectedLine in pairs(inventoryLines) do
	selectedLine = {isLineTextAwaited = false, isLineRequestedManually = false, lineText = ""}
end

local statNames = {
	"nameAndLevel", "playingHours", "phoneNumber", "warnings",
	"job1", "job2",
	"totalWealth", "cash", "bankBalance", "insurance",
	"respectPoints", "radio",
	"materials", "pot", "crack",
	"rope", "cigars", "sprunk", "spray", "seeds", "blindfolds", "refTokens", "donator",
	
	"tire", "firstaid", "bugSweep", "lockpicks"
}

local statInfo = {}

for _, selectedName in pairs(statNames) do
	statInfo[selectedName] = {
		isEnabled = false,
		statText = emptyPanelText.str,
		statLength = 0, -- set in main
		posX = 0, posY = 0
	}
end

local ig_style = ig.GetStyle()

ig_style.WindowTitleAlign = ig.ImVec2(0.5, 0.5)

ig_style.Colors[ig.Col.WindowBg] = ig.ImVec4(0, 0, 0, 0.9)
ig_style.Colors[ig.Col.TitleBg] = ig.ImVec4(0, 0, 0, 0.9)
ig_style.Colors[ig.Col.TitleBgActive] = ig.ImVec4(0, 0, 0, 0.9)
ig_style.Colors[ig.Col.TitleBgCollapsed] = ig.ImVec4(0, 0, 0, 0.2)

ig_style.Colors[ig.Col.SliderGrab] = ig.ImVec4(0, 0, 0, 0.6)
ig_style.Colors[ig.Col.SliderGrabActive] = ig.ImVec4(0, 0, 0, 1)

ig_style.Colors[ig.Col.FrameBg] = ig.ImVec4(0.1, 0.1, 0.1, 1)
ig_style.Colors[ig.Col.FrameBgHovered] = ig.ImVec4(0.2, 0.2, 0.2, 1)
ig_style.Colors[ig.Col.FrameBgActive] = ig.ImVec4(0.3, 0.3, 0.3, 1)


-- menu data
local menu = {
	statDisplayNames = {
		"Name & Level", "Playing Hours", "Phone Number", "Warnings",
		"Job 1", "Job 2",
		"Total Wealth", "Cash", "Bank Balance", "Insurance",
		"Respect Points", "Radio",
		"Materials", "Pot", "Crack",
		"Rope", "Cigars", "Sprunk", "Spray", "Seeds", "Blindfolds", "Ref Tokens", "Donator",
		
		"Tires", "Firstaids", "Bug Sweeps", "Lockpicks"
	},
	
	sl_refreshCooldown = ig.ImInt(config.Display.refreshCooldown),
	sl_textSize = ig.ImInt(config.Text.size),
	sl_boxOpacity = ig.ImInt(config.Text.boxOpacity),
	
	statsColumnCount = 9, perColumnStatCount,
	activeTab = 1,
}

menu.perColumnStatCount = math.ceil(#statNames / menu.statsColumnCount)


-----------------------------------------------------
-- API-SPECIFIC FUNCTIONS
-----------------------------------------------------


function sampev.onServerMessage(msg_color, msg_text)
	if not string.find(sampGetCurrentServerName(), "Horizon Roleplay") then return true end
	
	if msg_text == "___________________________________________________________________________________________________" and msg_color == -5963606 then
		if statLines.line1.isLineRequestedManually then
			statLines.line1.isLineRequestedManually = false
			return true
		elseif statLines.line8.isLineRequestedManually then
			statLines.line8.isLineRequestedManually = false
			return true
		else
			if statLines.line1.isLineTextAwaited then statLines.line1.isLineTextAwaited = false
			elseif statLines.line8.isLineTextAwaited then statLines.line8.isLineTextAwaited = false
			end
			
			return false
		end
	
	elseif msg_text:find("^%a[%a%s%.]+ %- %(Level: ") and msg_color == -86 then
		statLines.line2.lineText = msg_text or ""
		
		if statLines.line2.isLineRequestedManually then
			statLines.line2.isLineRequestedManually = false
			return true
		else
			if statLines.line2.isLineTextAwaited then statLines.line2.isLineTextAwaited = false end
			return false
		end
	
	elseif (msg_text:sub(1, 10) == "(Faction: " or msg_text:sub(1, 9) == "(Family: ") and msg_color == -28246 then
		statLines.line3.lineText = msg_text or ""
		
		if statLines.line3.isLineRequestedManually then
			statLines.line3.isLineRequestedManually = false
			return true
		else
			if statLines.line3.isLineTextAwaited then statLines.line3.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 15) == "(Total wealth: " and msg_color == -86 then
		statLines.line4.lineText = msg_text or ""
		
		if statLines.line4.isLineRequestedManually then
			statLines.line4.isLineRequestedManually = false
			return true
		else
			if statLines.line4.isLineTextAwaited then statLines.line4.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 17) == "(Respect points: " and msg_color == -28246 then
		statLines.line5.lineText = msg_text or ""
		
		if statLines.line5.isLineRequestedManually then
			statLines.line5.isLineRequestedManually = false
			return true
		else
			if statLines.line5.isLineTextAwaited then statLines.line5.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 9) == "(Crimes: " and msg_color == -86 then
		statLines.line6.lineText = msg_text or ""
		
		if statLines.line6.isLineRequestedManually then
			statLines.line6.isLineRequestedManually = false
			return true
		else
			if statLines.line6.isLineTextAwaited then statLines.line6.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 7) == "(Rope: " and msg_color == -28246 then
		statLines.line7.lineText = msg_text or ""
		
		if statLines.line7.isLineRequestedManually then
			statLines.line7.isLineRequestedManually = false
			return true
		else
			if statLines.line7.isLineTextAwaited then statLines.line7.isLineTextAwaited = false end
			return false
		end
		
	elseif msg_text == "________________________________________________" and msg_color == -5963606 then
		if inventoryLines.line1.isLineRequestedManually then
			inventoryLines.line1.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line1.isLineTextAwaited then inventoryLines.line1.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text == "Inventory:" and msg_color == -65366 then
		if inventoryLines.line2.isLineRequestedManually then
			inventoryLines.line2.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line2.isLineTextAwaited then inventoryLines.line2.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 14) == "(Screwdriver: " and msg_color == -1263159297 then
		if inventoryLines.line3.isLineRequestedManually then
			inventoryLines.line3.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line3.isLineTextAwaited then inventoryLines.line3.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 13) == "(Wristwatch: " and msg_color == -1263159297 then
		inventoryLines.line4.lineText = msg_text or ""
		
		if inventoryLines.line4.isLineRequestedManually then
			inventoryLines.line4.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line4.isLineTextAwaited then inventoryLines.line4.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 11) == "(Firstaid: " and msg_color == -1263159297 then
		inventoryLines.line5.lineText = msg_text or ""
		
		if inventoryLines.line5.isLineRequestedManually then
			inventoryLines.line5.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line5.isLineTextAwaited then inventoryLines.line5.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 6) == "(GPS: " and msg_color == -1263159297 then
		inventoryLines.line6.lineText = msg_text or ""
		
		if inventoryLines.line6.isLineRequestedManually then
			inventoryLines.line6.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line6.isLineTextAwaited then inventoryLines.line6.isLineTextAwaited = false end
			return false
		end
	
	elseif msg_text:sub(1, 12) == "(Lockpicks: " and msg_color == -1263159297 then
		inventoryLines.line7.lineText = msg_text or ""
		
		if inventoryLines.line7.isLineRequestedManually then
			inventoryLines.line7.isLineRequestedManually = false
			return true
		else
			if inventoryLines.line7.isLineTextAwaited then inventoryLines.line7.isLineTextAwaited = false end
			return false
		end
		
	elseif isAnyStatPending and msg_text == "You can't do this right now." then
		return false
	
	elseif string.sub(msg_text, 1, 48) == "You have been muted automatically for spamming. " then
		isPlayerMuted = true
	
	end
end

-- menu
function ig.OnDrawFrame()
	local screenWidth, screenHeight = getScreenResolution()
	local setWindowWidth, setWindowHeight = screenHeight * 1.1, screenHeight / 2
	
	if hasResChanged then
		-- Window sizing & positioning
		ig.SetNextWindowPos(ig.ImVec2(screenWidth / 2, screenHeight / 2), ig.Cond.Always, ig.ImVec2(0.5, 0.5))
		ig.SetNextWindowSize(ig.ImVec2(setWindowWidth, setWindowHeight), ig.Cond.Always)
		
		hasResChanged = false
	end
	
	ig.Begin("Stats Panel for HZRP v" .. script.this.version)
	ig.SetWindowFontScale(screenHeight / 900)
	ig_style.WindowPadding = ig.ImVec2(screenHeight / 180, screenHeight / 180)
	ig_style.ItemSpacing = ig.ImVec2(0, 0)
	ig_style.WindowRounding = screenHeight / 100
	ig.PushItemWidth(ig.GetWindowWidth() / 9.275)
	ig_style.Colors[ig.Col.ButtonHovered] = ig.ImVec4(0.2, 0.2, 0.2, 1)
	ig_style.Colors[ig.Col.ButtonActive] = ig.ImVec4(0.3, 0.3, 0.3, 1)
	
	local common_buttonHeight = screenHeight / 35
	
	ig.Columns(2, _, false)
	
	if menu.activeTab == 1 then
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
	else
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
	end
	
	if ig.Button("GENERAL", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
		menu.activeTab = 1
	end
	
	ig.NextColumn()
	
	if menu.activeTab == 2 then
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
	else
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
	end
	
	ig.SetCursorPosX(ig.GetCursorPosX() - (screenHeight / 720))
	
	if ig.Button("APPEARANCE", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
		menu.activeTab = 2
	end
	
	ig.Columns() ig.NewLine()
	
	if menu.activeTab == 1 then
		----------------------------
		-- PANEL & INDICATOR TOGGLES
		----------------------------
		
		if ig.RadioButton("Stats Panel [/showstp]", config.Display.panel) then
			config.Display.panel = not config.Display.panel
			
			if inicfg.save(config, config_file_path) then
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NewLine()
		
		if ig.RadioButton("Refresh Indicator [/stpref]", config.Display.refreshIndicator) then
			config.Display.refreshIndicator = not config.Display.refreshIndicator
			
			if inicfg.save(config, config_file_path) then
				if config.Display.refreshIndicator then isRefreshNeeded = true end
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NewLine() ig.NewLine()
		
		-------------------
		-- REFRESH COOLDOWN
		-------------------
		
		if ig.SliderInt("Refresh Cooldown (5-60 seconds)", menu.sl_refreshCooldown, 5, 60) then
			if not tonumber(menu.sl_refreshCooldown.v) or not (tonumber(menu.sl_refreshCooldown.v) > 4) or not (tonumber(menu.sl_refreshCooldown.v) < 61) then
				menu.sl_refreshCooldown.v = "10"
			end
			
			config.Display.refreshCooldown = tonumber(menu.sl_refreshCooldown.v)
			
			if not inicfg.save(config, config_file_path) then
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NewLine() ig.NewLine()
		
		-----------------
		-- STAT SELECTION
		-----------------
		
		ig.PushItemWidth(screenHeight / 22.5)
		ig_style.ItemSpacing = ig.ImVec2(0, screenHeight / 360)
		
		ig.Text("Stats on Display:")
		
		ig.Columns(menu.statsColumnCount, _, false)
		
		for statNameIndex, selectedName in pairs(statNames) do
			if config.Display[selectedName] then
				ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
			else
				ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
			end
			
			if ig.GetColumnIndex() == menu.statsColumnCount - 1 then ig.SetCursorPosX(ig.GetCursorPosX() - (screenHeight / 360)) end
			
			if ig.Button(menu.statDisplayNames[statNameIndex], ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 360), common_buttonHeight)) then
				requestRefreshText()
				
				config.Display[selectedName] = not config.Display[selectedName]
				
				if inicfg.save(config, config_file_path) then
					isRefreshNeeded = true
				else
					sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
				end
			end
			
			if statNameIndex % menu.perColumnStatCount == 0 then ig.NextColumn() end
		end
		
		ig_style.ItemSpacing = ig.ImVec2(0, 0)
		ig.Columns()
		
		ig.NewLine() ig.NewLine()
		
		----------------------------
		-- SELECT & DESELECT BUTTONS
		----------------------------
		
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		
		ig.Columns(2, _, false)
		
		if ig.Button("SELECT ALL", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			local isAnyStatDisabled = false
			
			for _, selectedName in pairs(statNames) do
				if not config.Display[selectedName] then isAnyStatDisabled = true end
			end
			
			if isAnyStatDisabled then
				requestRefreshText()
				
				for _, selectedName in pairs(statNames) do
					config.Display[selectedName] = true
					
					if inicfg.save(config, config_file_path) then
						isRefreshNeeded = true
					else
						sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
					end
				end
			end
		end
		
		ig.NextColumn()
		
		ig.SetCursorPosX(ig.GetCursorPosX() - (screenHeight / 720))
		
		if ig.Button("DESELECT ALL", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			local isAnyStatEnabled = false
			
			for _, selectedName in pairs(statNames) do
				if config.Display[selectedName] then isAnyStatEnabled = true end
			end
			
			if isAnyStatEnabled then
				requestRefreshText()
				
				for _, selectedName in pairs(statNames) do
					config.Display[selectedName] = false
					
					if inicfg.save(config, config_file_path) then
						isRefreshNeeded = true
					else
						sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
					end
				end
			end
		end
		
		ig.Columns()
		
	else
		------
		-- BOX
		------
		
		if ig.RadioButton("Panel Box [/stpbox]", config.Display.box) then
			config.Display.box = not config.Display.box
			
			if not inicfg.save(config, config_file_path) then
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		if config.Display.box then
			ig_style.ItemSpacing = ig.ImVec2(screenHeight / 180, 0)
			ig.PushItemWidth(ig.GetWindowWidth() / 9.275)
			
			ig.SameLine()
			ig.Text("|")
			
			ig.SameLine()
			
			if ig.SliderInt("Box Opacity (1-255)", menu.sl_boxOpacity, 1, 255) then
				if not tonumber(menu.sl_boxOpacity.v) or not (tonumber(menu.sl_boxOpacity.v) > 0) or not (tonumber(menu.sl_boxOpacity.v) < 256) then
					menu.sl_boxOpacity.v = tostring(tonumber("C8", 16))
				end
				
				config.Text.boxOpacity = tonumber(menu.sl_boxOpacity.v)
				
				if inicfg.save(config, config_file_path) then
					setDrawboxColor(getHexOpacity(config.Text.boxOpacity), "000000")
				else
					sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
				end
			end
		end
		
		ig.NewLine() ig.NewLine()
		
		-------------------------
		-- TEXT SIZE & FORMATTING
		-------------------------
		
		ig.SetCursorPosY(screenHeight / 8.47)
		ig.PushItemWidth(ig.GetWindowWidth() / 9.275)
		
		if ig.SliderInt("Text Size (5-50)", menu.sl_textSize, 5, 50) then
			requestRefreshText()
			
			if not tonumber(menu.sl_textSize.v) or not (tonumber(menu.sl_textSize.v) > 4) or not (tonumber(menu.sl_textSize.v) < 51) then
				menu.sl_textSize.v = "12"
			end
			
			config.Text.size = tonumber(menu.sl_textSize.v)
			
			if inicfg.save(config, config_file_path) then
				configureFont()
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig_style.ItemSpacing = ig.ImVec2(0, 0)
		
		ig.NewLine() ig.NewLine()
		
		ig_style.ItemSpacing = ig.ImVec2(0, screenHeight / 360)
		ig.Text("Text Formatting:")
		
		ig.Columns(5, _, false)
	
		if config.Text.isAllCaps then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("ALL-CAPS", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.isAllCaps = not config.Text.isAllCaps
			
			if inicfg.save(config, config_file_path) then
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NextColumn()
	
		if config.Text.isBold then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("BOLD", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.isBold = not config.Text.isBold
			
			if inicfg.save(config, config_file_path) then
				configureFont()
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NextColumn()
		
		if config.Text.isItalicised then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("ITALICS", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.isItalicised = not config.Text.isItalicised
			
			if inicfg.save(config, config_file_path) then
				configureFont()
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NextColumn()
		
		if config.Text.isBordered then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("BORDER", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.isBordered = not config.Text.isBordered
			
			if inicfg.save(config, config_file_path) then
				configureFont()
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig.NextColumn()
		ig.SetCursorPosX(ig.GetCursorPosX() - (screenHeight / 360))
		
		if config.Text.isShadowed then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("SHADOW", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.isShadowed = not config.Text.isShadowed
			
			if inicfg.save(config, config_file_path) then
				configureFont()
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		end
		
		ig_style.ItemSpacing = ig.ImVec2(0, 0)
		ig.Columns()
		
		ig.NewLine() ig.NewLine()
		
		-----------------------
		-- ALIGNMENT & POSITION
		-----------------------
		
		ig_style.ItemSpacing = ig.ImVec2(0, screenHeight / 360)
		ig.Text("Alignment & Position:")
		
		ig.Columns(3, _, false)
	
		if config.Text.alignment == 1 then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("LEFT", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.alignment = 1
			isRefreshNeeded = true
		end
		
		ig.NextColumn()
		
		if config.Text.alignment == 2 then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("CENTRE", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.alignment = 2
			isRefreshNeeded = true
		end
		
		ig.NextColumn()
		ig.SetCursorPosX(ig.GetCursorPosX() - (screenHeight / 360))
		
		if config.Text.alignment == 3 then
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.25, 0.25, 0.25, 1)
		else
			ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		end
		
		if ig.Button("RIGHT", ig.ImVec2(ig.GetColumnWidth() - (screenHeight / 240), common_buttonHeight)) then
			requestRefreshText()
			
			config.Text.alignment = 3
			isRefreshNeeded = true
		end
		
		ig_style.ItemSpacing = ig.ImVec2(0, 0)
		ig.Columns()
		ig.NewLine() ig.NewLine()
		
		ig_style.Colors[ig.Col.Button] = ig.ImVec4(0.1, 0.1, 0.1, 1)
		
		ig.SetCursorPosX((ig.GetWindowWidth() - (common_buttonHeight * 3.3)) / 2)
		
		if ig.Button("MOVE PANEL\n [/movestp]", ig.ImVec2(common_buttonHeight * 3.3, common_buttonHeight * 1.6)) then
			isMoveRequestedFromMenu = true
			isPlayerMovingPanel = true
			ig.Process = false
		end
		
	end
	
	
	ig.SetCursorPosY(setWindowHeight * 0.87)
	
	ig.Text("Developer: Bear (Swapnil#9308)")
	
	if isRefreshTextNeededOnce or isRefreshTextNeededTwice then
		ig.SameLine()
		ig.SetCursorPosX(ig.GetWindowWidth() - (screenHeight / 11.5))
		ig.Text("Processing...")
	end
	
	ig.NewLine()
	
	--------
	-- CLOSE
	--------
	
	if ig.Button("CLOSE", ig.ImVec2(ig.GetWindowWidth() - (screenHeight / 90), common_buttonHeight)) then ig.Process = false end
	
	ig.End()
end

function onD3DPresent()
	if isServerRequirementMet and config.Display.panel and not isPauseMenuActive() and sampGetChatDisplayMode() > 0 then
		if config.Display.box or isBoxEnabledTemp then
			renderDrawBox(drawBox.posX, drawBox.posY, drawBox.sizeX, drawBox.sizeY, boxColor)
		end
		
		if isPanelEmpty then
			renderFontDrawText(font, emptyPanelText.str, emptyPanelText.posX, emptyPanelText.posY, 0xFFFFFFFF, true)
		else
			for _, selectedStat in pairs(statInfo) do
				if selectedStat.isEnabled then
					renderFontDrawText(font, selectedStat.statText, selectedStat.posX, selectedStat.posY, 0xFFFFFFFF, true)
				end
			end
		end
	end
end


-----------------------------------------------------
-- MAIN
-----------------------------------------------------


function main()
	emptyPanelText.str_length = renderGetFontDrawTextLength(font, emptyPanelText.str, true)
	
	for _, selectedName in pairs(statNames) do
		statInfo[selectedName].statLength = emptyPanelText.str_length
	end
	
	maxStatLength = emptyPanelText.str_length
	
	configureEmptyPanel()
	
	repeat wait(50) until isSampAvailable()
	repeat wait(50) until string.find(sampGetCurrentServerName(), "Horizon Roleplay")
	isServerRequirementMet = true
	
	sampAddChatMessage("--- {00EECC}Stats Panel for HZRP v" .. script.this.version .. " {FFFFFF}| Use {00EECC}/stp {FFFFFF}or {00EECC}/statspanel", -1)
	
	------------
	-- FUNCTIONS
	------------
	
	function cmd_stp()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			ig.Process = not ig.Process
		else
			sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Log in to HZRP for use.", -1)
		end
	end
	
	sampRegisterChatCommand("stp", cmd_stp)
	sampRegisterChatCommand("statspanel", cmd_stp) -- alias to the above
	
	sampRegisterChatCommand("showstp", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			config.Display.panel = not config.Display.panel
			
			if inicfg.save(config, config_file_path) then
				isRefreshNeeded = true
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Panel toggle failed - contact the developer for help.", -1)
			end
		else
			sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Log in to HZRP for use.", -1)
		end
	end)
	
	sampRegisterChatCommand("stpref", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			config.Display.refreshIndicator = not config.Display.refreshIndicator
			
			if inicfg.save(config, config_file_path) then
				if config.Display.refreshIndicator then
					isRefreshNeeded = true
					sampAddChatMessage("--- {00EECC}Stats Panel: {FFFFFF}Refresh Indicator On", -1)
				else
					sampAddChatMessage("--- {00EECC}Stats Panel: {FFFFFF}Refresh Indicator Off", -1)
				end
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		else
			sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Log in to HZRP for use.", -1)
		end
	end)
	
	sampRegisterChatCommand("stpbox", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			config.Display.box = not config.Display.box
			
			if inicfg.save(config, config_file_path) then
				if config.Display.box then
					sampAddChatMessage("--- {00EECC}Stats Panel: {FFFFFF}Box On", -1)
				else
					sampAddChatMessage("--- {00EECC}Stats Panel: {FFFFFF}Box Off", -1)
				end
			else
				sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving display data to config failed - contact the developer for help.", -1)
			end
		else
			sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Log in to HZRP for use.", -1)
		end
	end)
	
	sampRegisterChatCommand("movestp", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			isPlayerMovingPanel = true
		else
			sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Log in to HZRP for use.", -1)
		end
	end)
	
	sampRegisterChatCommand("stats", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			for _, selectedLine in pairs(statLines) do
				selectedLine.isLineRequestedManually = true
			end
		end
		
		sampSendChat("/stats")
	end)
	
	sampRegisterChatCommand("inv", function ()
		if string.find(sampGetCurrentServerName(), "Horizon Roleplay") then
			for _, selectedLine in pairs(inventoryLines) do
				selectedLine.isLineRequestedManually = true
			end
		end
		
		sampSendChat("/inv")
	end)
	
	---------------------
	-- ADDITIONAL THREADS
	---------------------
	
	lua_thread.create(function()
		local r1_x, r1_y
		
		while true do
			r1_x, r1_y = getScreenResolution()
			wait(1000)
			fetchRes()
			
			if not (r1_x == window_resX and r1_y == window_resY) then
				configureFont()
				
				isRefreshNeeded = true
				hasResChanged = true
			end
		end
	end)
	
	lua_thread.create(function()
		while true do
			if isPlayerMovingPanel then
				if not config.Display.panel then
					config.Display.panel = true
					
					if not inicfg.save(config, config_file_path) then
						sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Panel toggle failed - contact the developer for help.", -1)
					end
				end
				
				repeat wait(0) until isPanelConfigured
				sampToggleCursor(true)
				
				repeat
					cursorX, cursorY = getCursorPos()
					drawBox.posX, drawBox.posY = cursorX, cursorY
					
					if displayedStatsCount > 0 then
						local displayIndex = 0
			
						for _, selectedName in pairs(statNames) do
							if config.Display[selectedName] then
								statInfo[selectedName].posX = drawBox.posX + (textSize() / 2) + ((maxStatLength - statInfo[selectedName].statLength) * (config.Text.alignment - 1) / 2)
								statInfo[selectedName].posY = drawBox.posY + (textSize() / 4) + (displayIndex * textSize() * 2)
					
								displayIndex = displayIndex + 1
							end
						end
					else
						emptyPanelText.posX = drawBox.posX + (textSize() / 2)
						emptyPanelText.posY = drawBox.posY + (textSize() / 4)
					end
					
					if ig.Process then break end
					wait(0)
				until wasKeyPressed(vk.VK_LBUTTON)
				
				repeat wait(0) until wasKeyReleased(vk.VK_LBUTTON)
				
				if ig.Process then
					if isMoveRequestedFromMenu then isMoveRequestedFromMenu = false end
					
					isPlayerMovingPanel = false
				else
					sampToggleCursor(false)
					
					fetchRes()
					
					config.Text.posX = (drawBox.posX + ((config.Text.alignment - 1) / 2 * drawBox.sizeX)) / window_resX
					config.Text.posY = cursorY / window_resY
					
					if not inicfg.save(config, config_file_path) then
						sampAddChatMessage("--- {00EECC}Stats Panel for HZRP {FFFFFF}- Saving position data to config failed - contact the developer for help.", -1)
					end
					
					isPlayerMovingPanel = false
					if isMoveRequestedFromMenu then
						isMoveRequestedFromMenu = false
						ig.Process = true
					end
				end
			end
			
			wait(100)
		end
	end)
	
	-- An extra thread that initiates a 13-second spam cooldown
	lua_thread.create(function()
		while true do
			wait(200)
			if isPlayerMuted then wait(13000) isPlayerMuted = false end
		end
	end)
	
	--------------
	-- MAIN THREAD
	--------------
	
	while true do
		repeat wait(100) until config.Display.panel
		isPanelConfigured = false
		
		displayedStatsCount = 0
		areStatLinesInUse = false
		areInventoryLinesInUse = false
		
		for _, selectedName in pairs(statNames) do
			if config.Display[selectedName] then
				displayedStatsCount = displayedStatsCount + 1
				
				if selectedName == "tire" or selectedName == "firstaid" or selectedName == "bugSweep" or selectedName == "lockpicks" then
					areInventoryLinesInUse = true
				else
					areStatLinesInUse = true
				end
			end
		end
		
		if displayedStatsCount > 0 then
			isAnyStatPending = true
			
			while isAnyStatPending and config.Display.panel do
				if areStatLinesInUse then
					for _, selectedLine in pairs(statLines) do
						selectedLine.isLineTextAwaited = true
					end
				end
					
				if areInventoryLinesInUse then
					for _, selectedLine in pairs(inventoryLines) do
						selectedLine.isLineTextAwaited = true
					end
				end
				
				if areStatLinesInUse then
					while isPlayerMuted do wait(0) end
					sampSendChat("/stats")
				end
				
				if areInventoryLinesInUse then
					if areStatLinesInUse then wait((config.Display.refreshCooldown / 2) * 1000) end
					while isPlayerMuted do wait(0) end
					sampSendChat("/inv")
				end
				
				for i = 1, 20 do -- ~2 second loop
					isAnyStatPending = false
					
					if areStatLinesInUse then
						for _, selectedLine in pairs(statLines) do
							if selectedLine.isLineTextAwaited then isAnyStatPending = true end
						end
					end
					
					if areInventoryLinesInUse then
						for _, selectedLine in pairs(inventoryLines) do
							if selectedLine.isLineTextAwaited then isAnyStatPending = true end
						end
					end
					
					if isAnyStatPending and config.Display.panel then
						wait(100)
					else break
					end
				end
			end
			
			local timeDuringLastRefresh = os.time()
			
			--------------------
			-- PARSING STAT TEXT
			--------------------
			
			local statText, statLength = "", 0
			
			if areStatLinesInUse then
				if config.Display.nameAndLevel then
					statText = string.gsub(statLines.line2.lineText:match(".+Level: %d+%)"), "%- %(Level: ", "%(") or "--"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.nameAndLevel.statText = statText
					statInfo.nameAndLevel.statLength = statLength
				end
				
				if config.Display.playingHours then
					statText = statLines.line2.lineText:match("Playing hours: [^)]+") or "Playing hours: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.playingHours.statText = statText
					statInfo.playingHours.statLength = statLength
				end
				
				if config.Display.phoneNumber then
					statText = string.gsub(statLines.line2.lineText:match("Phone number: [^)]+"), "Phone number", "PHN") or "PHN: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.phoneNumber.statText = statText
					statInfo.phoneNumber.statLength = statLength
				end
				
				if config.Display.warnings then
					statText = statLines.line2.lineText:match("Warnings: [^)]+") or "Warnings: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.warnings.statText = statText
					statInfo.warnings.statLength = statLength
				end
				
				if config.Display.job1 then
					statText = string.gsub(statLines.line3.lineText:match("Job: [^)]+"), "Job", "Job 1") or "Job 1: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.job1.statText = statText
					statInfo.job1.statLength = statLength
				end
				
				if config.Display.job2 then
					statText = statLines.line3.lineText:match("Job 2: [^)]+") or "Job 2: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.job2.statText = statText
					statInfo.job2.statLength = statLength
				end
				
				if config.Display.totalWealth then
					statText = statLines.line4.lineText:match("Total wealth: [^)]+") or "Total wealth: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.totalWealth.statText = statText
					statInfo.totalWealth.statLength = statLength
				end
				
				if config.Display.cash then
					statText = statLines.line4.lineText:match("Cash: [^)]+") or "Cash: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.cash.statText = statText
					statInfo.cash.statLength = statLength
				end
				
				if config.Display.bankBalance then
					statText = statLines.line4.lineText:match("Bank balance: [^)]+") or "Bank balance: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.bankBalance.statText = statText
					statInfo.bankBalance.statLength = statLength
				end
				
				if config.Display.insurance then
					statText = statLines.line4.lineText:match("Insurance: [^)]+") or "Insurance: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.insurance.statText = statText
					statInfo.insurance.statLength = statLength
				end
				
				if config.Display.respectPoints then
					statText = statLines.line5.lineText:match("Respect points: [^)]+") or "Respect points: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.respectPoints.statText = statText
					statInfo.respectPoints.statLength = statLength
				end
				
				if config.Display.radio then
					statText = statLines.line5.lineText:match("Radio: [^)]+") or "Radio: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.radio.statText = statText
					statInfo.radio.statLength = statLength
				end
				
				if config.Display.materials then
					statText = statLines.line6.lineText:match("Materials: [^)]+") or "Materials: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.materials.statText = statText
					statInfo.materials.statLength = statLength
				end
				
				if config.Display.pot then
					statText = statLines.line6.lineText:match("Pot: [^)]+") or "Pot: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.pot.statText = statText
					statInfo.pot.statLength = statLength
				end
				
				if config.Display.crack then
					statText = statLines.line6.lineText:match("Crack: [^)]+") or "Crack: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.crack.statText = statText
					statInfo.crack.statLength = statLength
				end
				
				if config.Display.rope then
					statText = statLines.line7.lineText:match("Rope: [^)]+") or "Rope: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.rope.statText = statText
					statInfo.rope.statLength = statLength
				end
				
				if config.Display.cigars then
					statText = statLines.line7.lineText:match("Cigars: [^)]+") or "Cigars: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.cigars.statText = statText
					statInfo.cigars.statLength = statLength
				end
				
				if config.Display.sprunk then
					statText = statLines.line7.lineText:match("Sprunk: [^)]+") or "Sprunk: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.sprunk.statText = statText
					statInfo.sprunk.statLength = statLength
				end
				
				if config.Display.spray then
					statText = statLines.line7.lineText:match("Spray: [^)]+") or "Spray: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.spray.statText = statText
					statInfo.spray.statLength = statLength
				end
				
				if config.Display.seeds then
					statText = statLines.line7.lineText:match("Seeds: [^)]+") or "Seeds: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.seeds.statText = statText
					statInfo.seeds.statLength = statLength
				end
				
				if config.Display.blindfolds then
					statText = statLines.line7.lineText:match("Blindfolds: [^)]+") or "Blindfolds: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.blindfolds.statText = statText
					statInfo.blindfolds.statLength = statLength
				end
				
				if config.Display.refTokens then
					statText = statLines.line7.lineText:match("Ref Tokens: [^)]+") or "Ref Tokens: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.refTokens.statText = statText
					statInfo.refTokens.statLength = statLength
				end
				
				if config.Display.donator then
					statText = statLines.line7.lineText:match("Donator: [^)]+") or "Donator: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.donator.statText = statText
					statInfo.donator.statLength = statLength
				end
			end
			
			
			if areInventoryLinesInUse then
				if config.Display.tire then
					statText = string.gsub(inventoryLines.line4.lineText:match("Tire: [^)]+"), "e:", "es:") or "Tires: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.tire.statText = statText
					statInfo.tire.statLength = statLength
				end
				
				if config.Display.firstaid then
					statText = string.gsub(inventoryLines.line5.lineText:match("Firstaid: [^)]+"), "d:", "ds:") or "Firstaids: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.firstaid.statText = statText
					statInfo.firstaid.statLength = statLength
				end
				
				if config.Display.bugSweep then
					statText = string.gsub(inventoryLines.line6.lineText:match("Bug Sweep: [^)]+"), "p:", "ps:") or "Bug Sweeps: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.bugSweep.statText = statText
					statInfo.bugSweep.statLength = statLength
				end
				
				if config.Display.lockpicks then
					statText = inventoryLines.line7.lineText:match("Lockpicks: [^)]+") or "Lockpicks: --"
					if config.Text.isAllCaps then statText = statText:upper() end
					
					statLength = renderGetFontDrawTextLength(font, statText, true)
					
					statInfo.lockpicks.statText = statText
					statInfo.lockpicks.statLength = statLength
				end
			end
			
			------------------
			-- RENDERING STATS
			------------------
			
			maxStatLength = emptyPanelText.str_length
			
			for _, selectedStat in pairs(statInfo) do
				if maxStatLength < selectedStat.statLength then maxStatLength = selectedStat.statLength end
			end
			
			drawBox.sizeX = maxStatLength + textSize()
			drawBox.posX = (window_resX * config.Text.posX) - ((config.Text.alignment - 1) / 2 * drawBox.sizeX)
		
			displayedStatsCount = 0
			for _, selectedName in pairs(statNames) do
				if config.Display[selectedName] then displayedStatsCount = displayedStatsCount + 1 end
			end
			
			drawBox.sizeY = displayedStatsCount * textSize() * 2 + (textSize() / 2)
			drawBox.posY = window_resY * config.Text.posY
			
			local displayIndex = 0
			
			for _, selectedName in pairs(statNames) do
				if config.Display[selectedName] then
					statInfo[selectedName].posX = drawBox.posX + (textSize() / 2) + ((maxStatLength - statInfo[selectedName].statLength) * (config.Text.alignment - 1) / 2)
					statInfo[selectedName].posY = drawBox.posY + (textSize() / 4) + (displayIndex * textSize() * 2)
					statInfo[selectedName].isEnabled = true
					
					displayIndex = displayIndex + 1
				else
					statInfo[selectedName].isEnabled = false
				end
			end
			
			if config.Display.panel then isPanelEmpty = false end
			
			if config.Display.refreshIndicator then
				lua_thread.create(function()
					isBoxEnabledTemp = true
					
					setDrawboxColor(getHexOpacity(255 - config.Text.boxOpacity), "FFFFFF")
					wait(100)
					setDrawboxColor(getHexOpacity(255 - config.Text.boxOpacity), "000000")
					wait(100)
					
					isBoxEnabledTemp = false
					
					setDrawboxColor(getHexOpacity(config.Text.boxOpacity), "000000")
				end)
			end
			
		else
			configureEmptyPanel()
			isPanelEmpty = true
			
		end
		
		isPanelConfigured = true
		
		if isRefreshTextNeededTwice then
			isRefreshTextNeededTwice = false
			isRefreshTextNeededOnce = true
		else
			isRefreshTextNeededOnce = false
		end
		
		-- Cooldown before requesting stats again
		for i = 1, (config.Display.refreshCooldown / ((areStatLinesInUse and areInventoryLinesInUse) and 2 or 1)) * 10 do
			if (config.Display.panel and not isRefreshNeeded) or isPanelEmpty or isPlayerMovingPanel then
				wait(100)
			else break
			end
		end
		
		isRefreshNeeded = false
		
		if timeDuringLastRefresh and os.time() - timeDuringLastRefresh < 3 then wait(2000) end
	end
end