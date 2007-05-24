--[[
	BActionBar - A Bongos Actionbar
--]]

--basically, BActionBar inherits all methods from BBar
BActionBar = setmetatable(CreateFrame("Button"), {__index = BBar})
local Bar_MT = {__index = BActionBar}

local L = BONGOS_LOCALS

--constants
local CLASS = BONGOS_CLASS
local MAX_BUTTONS = BONGOS_MAX_BUTTONS
local STANCES = BONGOS_STANCES
local MAX_PAGES = BONGOS_MAX_PAGES

local BUTTON_SIZE = 36
local PROWL_STATE = 7
local HELP_STATE = 15

local DEFAULT_SPACING = 2
local DEFAULT_SIZE = 12
local DEFAULT_COLS = 12

--2.1 statemap function!
local function GenerateStateButton()
	local pageMap = "10:p1;11:p2;12:p3;13:p4;14:p5;15:help"
	local pageMap2 = "10:p1s;11:p2s;12:p3s;13:p4s;14:p5s;15:helps"

	local classStates, stanceMap, stanceMap2
	if(CLASS == "ROGUE" or CLASS == "PRIEST") then
		stanceMap = "1:s1"
		stanceMap2 = "1:s1s"
	elseif(CLASS == "WARRIOR") then
		stanceMap = "1:s1;2:s2;3:s3"
		stanceMap2 = "1:s1s;2:s2s;3:s3s"
	elseif(CLASS == "DRUID") then
		stanceMap = "1:s1;2:s2;3:s3;4:s4;5:s5;6:s6;7:s7"
		stanceMap2 = "1:s1s;2:s2s;3:s3s;4:s4s;5:s5s;6:s6s;7:s7s"
	end

	local stateButton1, stateButton2
	if(STANCES) then
		stateButton1 = format("%s;%s", stanceMap, pageMap)
		stateButton2 =  format("%s;%s", stanceMap2, pageMap2)
	else
		stateButton1 = pageMap
		stateButton2 = pageMap2
	end

	return stateButton1, stateButton2
end
local stateButton1, stateButton2 = GenerateStateButton()


--[[ Constructor/Destructor]]--

local function OnShow(self)
	self:UpdateVisibility()
end

function BActionBar:Create(id)
	local defaults
	if(id == 1) then
		defaults = {p1 = 1, p2 = 2, p3 = 3, p4 = 4, p5 = 5}
		if CLASS == "DRUID" then
			defaults.s1 = 8; defaults.s3 = 6
		elseif CLASS == "WARRIOR" then
			defaults.s1 = 6; defaults.s2 = 7; defaults.s3 = 8
		elseif CLASS == "ROGUE" then
			defaults.s1 = 6
		end
	end

	local bar = setmetatable(BBar:CreateSecure(id, nil, nil, defaults), Bar_MT)
	bar:SetAttribute("statemap-state", "$input")
	bar:SetAttribute("statebutton", stateButton1)
	bar:SetAttribute("statebutton2", stateButton2)

	bar:SetRightClickUnit(BongosActionConfig:GetRightClickUnit())
	bar:UpdateStateHeader()
	bar:SetScript("OnShow", OnShow)

	--layout the bar
	if not bar:IsUserPlaced() then
		local start = bar:GetStartID()
		local row = mod(start-1, 12)
		local col = ceil(start / 12) - 1
		bar:SetPoint("CENTER", UIParent, "CENTER", 36 * row, -36 * col)
	end
	bar:Layout()
	SecureStateHeader_Refresh(bar)

	return bar
end

function BActionBar:OnDelete()
	self:SetScript("OnShow", nil)

	for i = self:GetStartID(), self:GetEndID() do
		local button = BongosActionButton:Get(i)
		if button then
			button:Release()
		end
	end
end


--[[ State Functions ]]--

--generates a new stance header based on what states we want to switch in
--priority is modifier, then pages, then stances, then friendly target, then default
function BActionBar:UpdateStateHeader()
	UnregisterStateDriver(self, "state", 0)

	local header
	for i = 1, MAX_PAGES do
		if(self:GetStateOffset("p" .. i)) then
			local state = format("[actionbar:%d]%d;", i+1, i+9)
			header = (header and header .. state) or state
		end
	end

	local maxState = 0
	if CLASS == "ROGUE" or CLASS == "PRIEST" then
		maxState = 1
	elseif CLASS == "WARRIOR" then
		maxState = 3
	end

	--rogue, priest, warrior states
	for i = 1, maxState do
		if(self:GetStateOffset("s" .. i)) then
			local state = format("[stance:%d]%d;", i, i)
			header = (header and header .. state) or state
		end
	end

	--druid states
	if(CLASS == "DRUID") then
		local hasProwl = self:GetStateOffset("s7")
		for i = 1, 7 do
			if(i == 3 and hasProwl) then
				if(self:GetStateOffset("s" .. i)) then
					local state = format("[stance:%d,nostealth]%d;", i, i)
					header = (header and header .. state) or state
				end
				local state = format("[stance:%d,stealth]%d;", i, PROWL_STATE)
				header = (header and header .. state) or state
			else
				if(self:GetStateOffset("s" .. i)) then
					local state = format("[stance:%d]%d;", i, i)
					header = (header and header .. state) or state
				end
			end
		end
	end

	if(self:GetStateOffset("help")) then
		local state = format("[help]%d;", HELP_STATE)
		header = (header and header .. state) or state
	end

	--add in default state
	if(header) then
		header = header .. "0"
		RegisterStateDriver(self, "state", header)
	end

	self:SetAttribute("state", self:GetCurrentState())
end

--returns the current state of the given bar
function BActionBar:GetCurrentState()
	--page check
	local page = GetActionBarPage()-1
	if(page > 0 and self:GetStateOffset("p" .. page)) then
		return page + 9
	end
	
	--stance check
	local stance = GetShapeshiftForm()
	if(stance > 0) then
		--prowl check
		if(stance == 3 and IsStealthed() and self:GetStateOffset("s7")) then
			return PROWL_STATE
		end

		--some sort of stance
		if(self:GetStateOffset("s" .. stance)) then
			return stance
		end
	end
	
	--friently target check
	if(UnitCanAssist("player", "target") and self:GetStateOffset("help")) then
		return HELP_STATE
	end

	--default state
	return 0
end


--[[ Menu Functions ]]--

local function StanceSlider_OnShow(self)
	local frame = self:GetParent().frame

	self:SetMinMaxValues(0, BongosActionBar:GetNumber())
	self:SetValue(frame.sets[self.id] or 0)
	getglobal(self:GetName() .. "High"):SetText(BongosActionBar:GetNumber()-1)
end

local function StanceSlider_OnValueChanged(self, value)
	local menu = self:GetParent()
	if not menu.onShow then
		menu.frame:SetStateOffset(self.id, value)
	end
	getglobal(self:GetName() .. "ValText"):SetText(value)
end

local function Panel_AddStanceSlider(self, id, title)
	local name = self:GetName() .. "Stance" .. id

	local slider = self:CreateSlider(name)
	slider.id = id

	slider:SetScript("OnShow", StanceSlider_OnShow)
	slider:SetScript("OnValueChanged", StanceSlider_OnValueChanged)
	slider:SetValueStep(1)

	getglobal(name .. "Text"):SetText(title)
	getglobal(name .. "Low"):SetText(0)
end

local function Panel_AddLayoutSliders(panel)
	local name = panel:GetName()
	--spacing
	local spacing = panel:CreateSpacingSlider(name .. "Spacing")
	spacing:SetScript("OnShow", function(self)
		local parent = self:GetParent()
		self:SetValue(parent.frame:GetSpacing())
	end)
	spacing:SetScript("OnValueChanged", function(self, value)
		local parent = self:GetParent()
		if not parent.onShow then
			parent.frame:SetSpacing(value)
		end
		getglobal(self:GetName() .. "ValText"):SetText(value)
	end)

	--columns
	local cols = panel:CreateSlider(name .. "Cols")
	cols:SetScript("OnShow", function(self)
		local parent = self:GetParent()
		self:SetValue(parent.frame:GetSize() - parent.frame:GetColumns() + 1)
	end)
	cols:SetScript("OnValueChanged", function(self, value)
		local parent = self:GetParent()
		if not parent.onShow then
			parent.frame:SetColumns(parent.frame:GetSize() - value + 1)
		end
		getglobal(self:GetName() .. "ValText"):SetText(parent.frame:GetColumns())
	end)
	cols:SetValueStep(1)
	getglobal(name .. "ColsText"):SetText(L.Columns)
	getglobal(name .. "ColsHigh"):SetText(1)

	--size
	local size = panel:CreateSlider(name .. "Size")
	size:SetScript("OnShow", function(self)
		local frame = self:GetParent().frame
		getglobal(name .. "Size"):SetMinMaxValues(1, frame:GetMaxSize())
		getglobal(name .. "Size"):SetValue(frame:GetSize())
		getglobal(name .. "SizeHigh"):SetText(frame:GetMaxSize())
	end)
	size:SetScript("OnValueChanged", function(self, value)
		local parent = self:GetParent()
		if not parent.onShow then
			parent.frame:SetSize(value)
		end
		getglobal(self:GetName() .. "ValText"):SetText(value)

		local size = parent.frame:GetSize()
		local cols = parent.frame:GetColumns()
		getglobal(name .. "Cols"):SetMinMaxValues(1, size)
		getglobal(name .. "Cols"):SetValue(size - cols + 1)
		getglobal(name .. "ColsLow"):SetText(size)
		getglobal(name .. "ColsValText"):SetText(cols)
	end)
	size:SetValueStep(1)
	getglobal(name .. "SizeText"):SetText(L.Size)
	getglobal(name .. "SizeLow"):SetText(1)
end

function BActionBar:CreateMenu()
	local name = format("BongosMenu%s", self.id)
	local menu, panel = BongosMenu:Create(name, true)

	--layout panel
	Panel_AddLayoutSliders(panel)

	--stances panel
	local stancePanel = menu:AddPanel(L.Stances)
	Panel_AddStanceSlider(stancePanel, "help", L.FriendlyStance)
	if(STANCES) then
		for i in ipairs(STANCES) do
			Panel_AddStanceSlider(stancePanel, "s" .. i, STANCES[i])
		end
	end

	--paging panel
	local panel = menu:AddPanel(L.Paging)
	for i = MAX_PAGES, 1, -1 do
		Panel_AddStanceSlider(panel, "p" .. i, format(L.Page, i))
	end

	return menu
end

--Called when the right click menu is shown, loads the correct values to the checkbuttons/sliders/text
function BActionBar:ShowMenu()
	--a metatable trickish
	if not BActionBar.menu then
		BActionBar.menu = self:CreateMenu()
	end

	local menu = self.menu
	if menu:IsShown() then
		menu:Hide()
	end

	menu:SetFrame(self)
	menu.text:SetText(format(L.ActionBar, self.id))

	menu.onShow = true
	self:PlaceMenu(menu)
	menu:ShowPanel(L.Layout)
	menu.onShow = nil
end


--[[ Sizing ]]--

function BActionBar:SetSize(size)
	if not size or size == DEFAULT_SIZE then
		size = nil
	end
	self.sets.size = size
	self:Layout()
end

function BActionBar:GetSize()
	return min(self.sets.size or DEFAULT_SIZE, self:GetMaxSize())
end

function BActionBar:GetMaxSize()
	return MAX_BUTTONS / BongosActionBar:GetNumber()
end


--[[ Columns ]]--

function BActionBar:SetColumns(cols)
	if not cols or cols == DEFAULT_COLS then
		cols = nil
	end
	self.sets.cols = cols
	self:Layout()
end

function BActionBar:GetColumns()
	return min(self.sets.cols or DEFAULT_COLS, self:GetSize())
end


--[[ Spacing ]]--

function BActionBar:SetSpacing(spacing)
	if not spacing or spacing == DEFAULT_SPACING then
		spacing = nil
	end
	self.sets.spacing = spacing
	self:Layout()
end

function BActionBar:GetSpacing()
	return self.sets.spacing or DEFAULT_SPACING
end


--[[ Start, End, and MaxIDs ]]--

--returns the first button ID on the given bar
function BActionBar:GetStartID()
	local prev = self:Get(self.id - 1)
	if prev then
		self.start = prev:GetMaxID() + 1
	else
		self.start = 1
	end
	return self.start
end

--returns the last button ID shown on the given bar
function BActionBar:GetEndID()
	return self:GetStartID() + self:GetSize() - 1
end

--returns the last button ID alloted to the bar
function BActionBar:GetMaxID()
	return self:GetStartID() + self:GetMaxSize() - 1
end


--[[ Layout ]]--

function BActionBar:Layout()
	if InCombatLockdown() then return end

	local startID = self:GetStartID()
	local endID = self:GetEndID()
	local maxID = self:GetMaxID()

	local size = self:GetSize()
	local cols = self:GetColumns()
	local spacing = self:GetSpacing()
	local buttonSize = BUTTON_SIZE + spacing

	--size the bar
	self:SetWidth(buttonSize * cols - spacing)
	self:SetHeight(buttonSize * ceil(size / cols) - spacing)

	--place all used buttons, and update those buttons showstates and hotkeys
	for i = 1, size do
		local row = mod(i-1, cols)
		local col = ceil(i / cols) - 1
		local button = BongosActionButton:Set(startID + i-1, self)
		button:SetPoint("TOPLEFT", self, "TOPLEFT", buttonSize * row, -buttonSize * col)
	end

	--remove any unused buttons
	if startID < maxID then
		for i = endID + 1, maxID do
			local button = BongosActionButton:Get(i)
			if button then
				button:Release()
			else break end
		end
	end
end

function BActionBar:UpdateVisibility()
	local s = self:GetStartID()
	local e = self:GetEndID()
	local changed

	for i = s, e do
		local button = BongosActionButton:Get(i)
		if button:UpdateVisibility() then
			changed = true
		end
	end

	if changed then
		SecureStateHeader_Refresh(self)
	end
end


--[[ Stance Settings ]]--

function BActionBar:SetStateOffset(state, offset)
	if(offset == 0) then offset = nil end
	self.sets[state] = offset
	self:UpdateStateHeader()

	for i = self:GetStartID(), self:GetEndID() do
		local button = BongosActionButton:Get(i)
		button:UpdateStates()
	end
	SecureStateHeader_Refresh(self, self:GetCurrentState())
end

function BActionBar:GetStateOffset(state)
	local offset = self.sets[state]
	if(offset and offset ~= 0) then
		return offset * self:GetMaxSize()
	end
	return nil
end


--[[ Utility ]]--

function BActionBar:SetRightClickUnit(unit)
	self:SetAttribute("*unit2", unit)
	for i = 1, MAX_PAGES do
		self:SetAttribute("*unit-p" .. i .. "s", unit)
	end

	if(STANCES) then
		for i in pairs(STANCES) do
			self:SetAttribute("*unit-s" .. i .. "s", unit)
		end
	end
	self:SetAttribute("*unit-helps", unit)
end