--[[
	BActionBar - A Bongos Actionbar
--]]

local Bongos = LibStub('AceAddon-3.0'):GetAddon('Bongos3')
local Action = Bongos:GetModule('ActionBar')
local Config = Bongos:GetModule('ActionBar-Config')
local L = LibStub('AceLocale-3.0'):GetLocale('Bongos3-AB')

local ActionBar = Bongos:CreateWidgetClass('Frame', Bongos.Bar)
Action.Bar = ActionBar
local bars = {}

ActionBar.POSSESS_STATE = 999

function ActionBar:Create(numRows, numCols, point, x, y)
	if numRows * numCols <= self:NumFreeIDs() then
		--get the next available barID
		local id = 1
		while self.super:Get(id) do
			id = id + 1
		end

		local bar, isNew = self.super.Create(self, id, {rows = numRows, cols = numCols})
		if isNew then
			bar:OnCreate()
		end

		bar:UpdateUsedIDs()
		bar:UpdateActions()
		bar:UpdateStateDriver()
		bar:UpdateShowConditions()
		bar:SetRightClickUnit(Config:GetRightClickUnit())
		bar:Layout()

		--place the bar, the point starts relative to UIParent bottom left, make it not that
		bar:ClearAllPoints()
		bar:SetPoint(point, UIParent, 'BOTTOMLEFT', x, y)
		bar:SavePosition()

		bars[id] = bar
		return bar
	else
		UIErrorsFrame:AddMessage('Not Enough Available Action IDs', 1, 0.2, 0.2, 1, UIERRORS_HOLD_TIME)
	end
end

function ActionBar:Load(id)
	local bar, isNew = self.super.Create(self, id)
	if isNew then
		bar:OnCreate()
	end

	bar:LoadIDs()
	bar:UpdateActions()
	bar:UpdateStateDriver()
	bar:UpdateShowConditions()
	bar:SetRightClickUnit(Config:GetRightClickUnit())
	bar:Layout()

	bars[id] = bar
	return bar
end

function ActionBar:OnCreate()
	self.bar = CreateFrame('Frame', nil, self, 'SecureStateHeaderTemplate')
	self.bar:SetAttribute('statemap-state', '$input')
	self.bar:SetAttribute('statebindings', '*:main')
	self.buttons = {}
end

function ActionBar:OnDelete()
	for i,button in self:GetButtons() do
		button:Release()
		self.buttons[i] = nil
	end
	self:ReleaseAllIDs()

	self.bar:SetAttribute('statebutton', nil)
	self.bar:SetAttribute('*statebutton2', nil)
	UnregisterStateDriver(self.bar, 'state', 0)
	UnregisterStateDriver(self.bar, 'visibility', 'show')

	bars[self.id] = nil
end

--[[ Dimensions ]]--

function ActionBar:SetSize(rows, cols)
	local newSize = rows * cols
	local oldSize = self:GetRows() * self:GetCols()
	self.sets.rows = rows
	self.sets.cols = cols

	if newSize ~= oldSize then
		self:UpdateUsedIDs()
		self:UpdateActions()
	end
	self:Layout()
end

function ActionBar:GetRows()
	return self.sets.rows or 1
end

function ActionBar:GetCols()
	return self.sets.cols or 1
end

--spacing
function ActionBar:SetSpacing(spacing)
	self.sets.spacing = spacing
	self:Layout()
end

function ActionBar:GetSpacing()
	return self.sets.spacing or 1
end


--[[ Update & Layout ]]--

--add/remove buttons and update their actionsIDs for each state
--needs to be called whenever the size/number of pages of a bar changes
function ActionBar:UpdateActions()
	local states = self:NumSets()
	local ids = self.sets.ids
	local numButtons = self:GetCols() * self:GetRows()
	local index = 1

	for state = 1, self:NumSets() do
		for index = 1, numButtons do
			local button = self:GetButton(index) or self:AddButton(index)
			local actionID = ids[index + numButtons*(state-1)]
			if state == 1 then
				button:SetAttribute('action', actionID)
				button.needsUpdate = true
			else
				button:SetAttribute(format('*action-s%d', state), actionID)
				button:SetAttribute(format('*action-s%ds', state), actionID)
			end
		end
	end

	if self:IsPossessBar() then
		for i = 1, 12 do
			local button = self:GetButton(i)
			if button then
				button:SetAttribute('*action-possess', 120 + i)
			end
		end
	end

	for i = numButtons + 1, #self.buttons do
		local button = self.buttons[i]
		button:Release()
		self.buttons[i] = nil
	end
end

--layout needs to be called whenever the amount of buttons or dimensions of a bar change
--layout must be performed only AFTER we actually have buttons
function ActionBar:Layout()
	local spacing = self:GetSpacing()
	local buttonSize = 37 + spacing
	local rows, cols = self:GetRows(), self:GetCols()

	self:SetWidth(buttonSize*cols - spacing)
	self:SetHeight(buttonSize*rows - spacing)

	for i = 1, rows do
		for j = 1, cols do
			local button = self.buttons[j + cols*(i-1)]
			button:ClearAllPoints()
			button:SetPoint('TOPLEFT', self, 'TOPLEFT', buttonSize*(j-1), -buttonSize*(i-1))
		end
	end

	self:UpdateShowStates()
end

function ActionBar:UpdateShowStates()
	local changed = false
	for _,button in self:GetButtons() do
		if button:UpdateShowStates() then
			changed = true
		end
	end

	if changed then
		SecureStateHeader_Refresh(self.bar)
		if not InCombatLockdown() then
			self:UpdateShowEmpty()
		end
	end
end

function ActionBar:UpdateShowEmpty()
	for _,button in self:GetButtons() do
		button:UpdateShown()
	end
end

function ActionBar:UpdateAction(id)
	for _,button in self:GetButtons() do
		button:UpdateAction(id)
	end
end


--[[ States ]]--

--states: allow us to map a button to multiple virtual buttons
function ActionBar:SetNumSets(numSets)
	if numSets ~= self:NumSets() then
		self.sets.numSets = numSets

		--this code is order dependent!
		self:UpdateUsedIDs()
		self:UpdateStateDriver()
		self:UpdateActions()
		self:UpdateShowStates()
		self:SetRightClickUnit(Config:GetRightClickUnit())
	end
end

--todo: cleanup code
function ActionBar:UpdateStateButton()
	local sb1, sb2

	for i = 2, self:NumSets() do
		local state1 = i .. ':s' .. i
		local state2 = state1 .. 's'

		sb1 = (sb1 and sb1 .. ';' .. state1) or state1
		sb2 = (sb2 and sb2 .. ';' .. state2) or state2
	end

	if self:IsPossessBar() then
		local state = self.POSSESS_STATE .. ':possess'
		sb1 = (sb1 and sb1 .. ';' .. state) or state
		sb2 = (sb2 and sb2 .. ';' .. state) or state
	end

	self.bar:SetAttribute('statebutton', sb1)
	self.bar:SetAttribute('*statebutton2', sb2)
end

function ActionBar:NumSets()
	return self.sets.numSets or 1
end


--[[ Condition - State Mapping ]]--

--needs to be called whenever we change a state condition
--or when we change the number of available states
function ActionBar:UpdateStateDriver()
	UnregisterStateDriver(self.bar, 'state', 0)

	local header = ''

	if self:IsPossessBar() then
		header = header .. format('[bonusbar:5]%d;', self.POSSESS_STATE)
	end

	local maxState = self:NumSets()
	for _,condition in ipairs(Config:GetStateConditions()) do
		local state = self:GetConditionSet(condition)
		if state and state <= maxState then
			header = header .. condition .. state .. ';'
		end
	end

	self:UpdateStateButton()

	if header ~= '' then
		RegisterStateDriver(self.bar, 'state', header .. '0')
	end
end

--state conditions specify when we  switch states.  uses the macro syntax for now
function ActionBar:SetConditionSet(condition, state)
	if not self.sets.setMap then
		self.sets.setMap = {}
	end

	if self.sets.setMap[condition] ~= state then
		self.sets.setMap[condition] = state
		self:UpdateStateDriver()
	end
end

function ActionBar:GetConditionSet(condition)
	return self.sets.setMap and self.sets.setMap[condition]
end


function ActionBar:SetIsPossessBar(enable)
	self.sets.possessBar = enable or nil
	self:UpdateStateDriver()
	self:UpdateActions()
	self:UpdateShowStates()
end

function ActionBar:IsPossessBar()
	return self.sets.possessBar
end


--[[ Button Creation ]]--

function ActionBar:AddButton(index)
	local button = Action.Button:Get(self.bar)
	self.buttons[index] = button

	button.index = index
	self:UpdateButtonBindings(index)

	return button
end

function ActionBar:GetButton(index)
	return self.buttons[index]
end

function ActionBar:GetButtons()
	return pairs(self.buttons)
end


--[[ ID Updating ]]--

function ActionBar:LoadIDs()
	if self.sets.ids then
		for _,id in pairs(self.sets.ids) do
			self:TakeID(id)
		end
		self:SortAvailableIDs()
	else
		self:UpdateUsedIDs()
	end
end

function ActionBar:UpdateUsedIDs()
	if not self.sets.ids then
		self.sets.ids = {}
	end

	local ids = self.sets.ids
	local numActions = self:GetRows() * self:GetCols() * self:NumSets()

	for i = 1, (self:GetRows() * self:GetCols() * self:NumSets()) do
		if not ids[i] then
			ids[i] = self:TakeID()
		end
	end

	for i = #ids, numActions + 1, -1 do
		self:GiveID(ids[i])
		ids[i] = nil
	end
	self:SortAvailableIDs()
end

function ActionBar:ReleaseAllIDs()
	local ids = self.sets.ids
	for i = #self.sets.ids, 1, -1 do
		self:GiveID(ids[i])
	end
	self:SortAvailableIDs()
end


--[[ Action ID Stack Stuff ]]--

do
	local freeActions = {}
	for i = 1, 120 do
		freeActions[i] = i
	end

	function ActionBar:TakeID(id)
		if id then
			for i,availableID in pairs(freeActions) do
				if id == availableID then
					table.remove(freeActions, i)
					return
				end
			end
		else
			local id = table.remove(freeActions, 1)
			return id
		end
	end

	function ActionBar:GiveID(id)
		table.insert(freeActions, 1, id)
	end

	function ActionBar:NumFreeIDs()
		return #freeActions
	end

	function ActionBar:SortAvailableIDs()
		table.sort(freeActions)
	end
end


--[[ Bindings ]]--

local function splitNext(sep, body)
    if body then
        local pre, post = strsplit(sep, body, 2);
        if post then
            return post, pre;
        end
        return false, body;
    end
end
local function semicolonIterator(str) return splitNext, ';', str; end

function ActionBar:AddBinding(index, newBinding)
	if newBinding then
		local bindings = self:GetBindings(index)
		if bindings then
			if bindings == newBinding then
				return
			end

			for _,binding in semicolonIterator(bindings) do
				if binding == newBinding then
					return
				end
			end

			self.sets.bindings[index] = bindings .. ';' .. newBinding
		else
			if not self.sets.bindings then
				self.sets.bindings = {}
			end
			self.sets.bindings[index] = newBinding
		end
		self:UpdateButtonBindings(index)
	end
end

function ActionBar:RemoveBinding(index, binding)
	local bindings = self:GetBindings(index)
	local changed

	if bindings == binding then
		self.sets.bindings[index] = nil
		changed = true
	else
		local newBindings
		for _,b in semicolonIterator(bindings) do
			if b ~= binding then
				if newBindings then
					newBindings = newBindings .. ';' .. b
				else
					newBindings = b
				end
			else
				changed = true
			end
		end
		self.sets.bindings[index] = newBindings
	end
	self:UpdateButtonBindings(index)
	return changed
end

function ActionBar:FreeBinding(binding)
	local changed

	for _,bar in self:GetAll() do
		local bindings = bar.sets.bindings
		if bindings then
			for index in pairs(bindings) do
				if bar:RemoveBinding(index, binding) then
					changed = true
				end
			end
		end
	end
	return changed
end

function ActionBar:ClearBindings(index)
	local bindings = self:GetBindings(index)
	if bindings then
		self.sets.bindings[index] = nil
		self:UpdateButtonBindings(index)
	end
end

function ActionBar:GetBindings(index)
	return self.sets.bindings and self.sets.bindings[index]
end

function ActionBar:UpdateButtonBindings(index)
	local button = self:GetButton(index)
	if button then
		button:SetAttribute('bindings-main', self:GetBindings(index))
		button:UpdateHotkey()
		self.bar:SetAttribute('_bindingset', nil)
		SecureStateHeader_Refresh(self.bar)
	end
end


--[[ Right Click Selfcast ]]--

function ActionBar:SetRightClickUnit(unit)
	self.bar:SetAttribute('*unit2', unit)
	for i = 2, self:NumSets() do
		self.bar:SetAttribute(format('*unit-s%ds', i), unit)
	end
end


--[[ Menu Code ]]--

--layout panel
local function AddLayoutPanel(menu)
	local panel = menu:AddLayoutPanel()

	local possess = panel:CreateCheckButton(L.PossessBar)
	possess:SetScript('OnShow', function(self)
		local bar = Bongos.Bar:Get(self:GetParent().id)
		self:SetChecked(bar:IsPossessBar())
	end)
	possess:SetScript('OnClick', function(self)
		local bar = Bongos.Bar:Get(self:GetParent().id)
		bar:SetIsPossessBar(self:GetChecked())
	end)


	panel:CreateSpacingSlider()

	local states, rows, cols
	local function UpdateSliderSizes(bar)
		local freeIDs = bar:NumFreeIDs()

		local maxStates = bar:GetCols() * bar:GetRows()
		states:SetMinMaxValues(1, floor(freeIDs / maxStates) + bar:NumSets())

		local maxRows = bar:GetCols() * bar:NumSets()
		rows:SetMinMaxValues(1, floor(freeIDs / maxRows) + bar:GetRows())

		local maxCols = bar:GetRows() * bar:NumSets()
		cols:SetMinMaxValues(1, floor(freeIDs / maxCols) + bar:GetCols())
	end

	states = panel:CreateSlider(L.Sets, 1, 1, 1)
	function states:UpdateValue(value)
		local bar = Bongos.Bar:Get(self:GetParent().id)
		bar:SetNumSets(value)
		UpdateSliderSizes(bar)
	end
	function states:OnShow()
		local bar = Bongos.Bar:Get(self:GetParent().id)
		local freeIDs = bar:NumFreeIDs()
		local maxStates = bar:GetCols() * bar:GetRows()

		self:SetMinMaxValues(1, floor(freeIDs / maxStates) + bar:NumSets())
		self:SetValue(bar:NumSets())
	end

	cols = panel:CreateSlider(L.Columns, 1, 1, 1)
	function cols:UpdateValue(value)
		local bar = Bongos.Bar:Get(self:GetParent().id)
		bar:SetSize(bar:GetRows(), value)
		UpdateSliderSizes(bar)
	end
	function cols:OnShow()
		local bar = Bongos.Bar:Get(self:GetParent().id)
		local maxCols = bar:GetRows() * bar:NumSets()
		local freeIDs = bar:NumFreeIDs()

		self:SetMinMaxValues(1, floor(freeIDs / maxCols) + bar:GetCols())
		self:SetValue(bar:GetCols())
	end

	rows = panel:CreateSlider(L.Rows, 1, 1, 1)
	function rows:UpdateValue(value)
		local bar = Bongos.Bar:Get(self:GetParent().id)
		bar:SetSize(value, bar:GetCols())
		UpdateSliderSizes(bar)
	end
	function rows:OnShow()
		local bar = Bongos.Bar:Get(self:GetParent().id)
		local maxRows = bar:GetCols() * bar:NumSets()
		local freeIDs = bar:NumFreeIDs()

		self:SetMinMaxValues(1, floor(freeIDs / maxRows) + bar:GetRows())
		self:SetValue(bar:GetRows())
	end
end

--state slider template
local function StateSlider_OnShow(self)
	local f = ActionBar:Get(self:GetParent().id)
	self:SetMinMaxValues(1, f:NumSets())
	self:SetValue(f:GetConditionSet(self.state) or 1)
end

local function StateSlider_UpdateValue(self, value)
	local f = ActionBar:Get(self:GetParent().id)
	if value == 1 then
		f:SetConditionSet(self.state, nil)
	else
		f:SetConditionSet(self.state, value)
	end
end

local function StateSlider_Create(panel, state, text)
	local slider = panel:CreateSlider(state, 0, 1, 1)
	slider.OnShow = StateSlider_OnShow
	slider.UpdateValue = StateSlider_UpdateValue
	slider.state = state

	if text then
		getglobal(slider:GetName() .. 'Text'):SetText(text)
	end

	panel[state] = slider

	return slider
end

--stances panel
local AddForms = {}
do
	function AddForms:PRIEST()
		StateSlider_Create(self, '[bonusbar:1]', GetSpellInfo(15473))
	end

	function AddForms:DRUID()
		StateSlider_Create(self, '[bonusbar:1,stealth]', GetSpellInfo(5215))
		StateSlider_Create(self, '[bonusbar:4]', GetSpellInfo(33891) .. '/' .. GetSpellInfo(24858))
		StateSlider_Create(self, '[bonusbar:1]', GetSpellInfo(768))
		StateSlider_Create(self, '[bonusbar:3]', GetSpellInfo(5487))
	end

	function AddForms:WARRIOR()
		StateSlider_Create(self, '[bonusbar:1]', GetSpellInfo(2457))
		StateSlider_Create(self, '[bonusbar:2]', GetSpellInfo(71))
		StateSlider_Create(self, '[bonusbar:2]', GetSpellInfo(2458))
	end

	function AddForms:ROGUE()
		StateSlider_Create(self, '[bonusbar:1]', GetSpellInfo(1784))
	end
end

local function AddStancesPanel(menu)
	local class = select(2, UnitClass('player'))
	if AddForms[class] then
		local panel = menu:AddPanel(L.Stances)
		AddForms[class](panel) 
	end
end

--modifier panel
local function AddModifierPanel(menu)
	local panel = menu:AddPanel(L.Modifier)
	StateSlider_Create(panel, '[mod:shift]', SHIFT_KEY)
	StateSlider_Create(panel, '[mod:ctrl]', CTRL_KEY)
	StateSlider_Create(panel, '[mod:alt]', ALT_KEY)
end

--targeting
local function AddTargetingPanel(menu)
	local panel = menu:AddPanel(L.Targeting)
	StateSlider_Create(panel, '[help]', L.FriendlyTarget)
	StateSlider_Create(panel, '[harm]', L.EnemyTarget)
end

--paging
local function AddPagingPanel(menu)
	local panel = menu:AddPanel(L.Paging)
	for i = 6, 2, -1 do
		StateSlider_Create(panel, format('[bar:%d]', i), format(L.Page, i))
	end
end

--showstates
local function AddShowStatesPanel(menu)
	local panel = menu:AddPanel(L.ShowStates)
	panel.height = 56

	local editBox = CreateFrame('EditBox', panel:GetName() .. 'StateText', panel,  'InputBoxTemplate')
	editBox:SetWidth(148); editBox:SetHeight(20)
	editBox:SetPoint('TOPLEFT', 12, -10)
	editBox:SetAutoFocus(false)
	editBox:SetScript('OnShow', function(self)
		local showStates = ActionBar:Get(self:GetParent().id):GetShowConditions() or ''
		self:SetText(showStates)
	end)
	editBox:SetScript('OnEnterPressed', function(self)
		local text = self:GetText()
		if text == '' then
			ActionBar:Get(self:GetParent().id):SetShowConditions(nil)
		else
			ActionBar:Get(self:GetParent().id):SetShowConditions(text)
		end
	end)
	editBox:SetScript('OnEditFocusLost', function(self) self:HighlightText(0, 0) end)
	editBox:SetScript('OnEditFocusGained', function(self) self:HighlightText() end)

	local set = CreateFrame('Button', panel:GetName() .. 'Set', panel, 'UIPanelButtonTemplate')
	set:SetWidth(30); set:SetHeight(20)
	set:SetText(L.Set)
	set:SetScript('OnClick', function(self)
		local text = editBox:GetText()
		if text == '' then
			ActionBar:Get(self:GetParent().id):SetShowConditions(nil)
		else
			ActionBar:Get(self:GetParent().id):SetShowConditions(text)
		end
	end)
	set:SetPoint('BOTTOMRIGHT', -8, 2)

	return panel
end

function ActionBar:CreateMenu()
	local menu = Bongos.Menu:Create(self.id)
	ActionBar.menu = menu

	AddLayoutPanel(menu)
	AddStancesPanel(menu)
	AddModifierPanel(menu)
	AddTargetingPanel(menu)
	AddPagingPanel(menu)
	AddShowStatesPanel(menu)

	return menu
end

--[[ Showstates ]]--

function ActionBar:SetShowConditions(showStates)
	self.sets.showStates = showStates
	self:UpdateShowConditions()
end

function ActionBar:UpdateShowConditions()
	UnregisterStateDriver(self.bar, 'visibility', 'show')
	self.bar:Show()

	local conditions = self:GetShowConditions()
	if conditions then
		RegisterStateDriver(self.bar, 'visibility', conditions .. 'show;hide', 'show')
	end
end

function ActionBar:GetShowConditions()
	return self.sets.showStates
end


--[[ Utility Functions ]]--

function ActionBar:ForAll(method, ...)
	for _,bar in pairs(bars) do
		bar[method](bar, ...)
	end
end

function ActionBar:ForAllShown(method, ...)
	for _,bar in pairs(bars) do
		if bar:IsShown() then
			bar[method](bar, ...)
		end
	end
end