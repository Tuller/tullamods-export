﻿--[[
	general.lua
		The general panel of the mangos options menu
--]]

local L = LibStub('AceLocale-3.0'):GetLocale('Mangos-Config')
local Mangos = Mangos
local Options = Mangos.Options

--[[ Buttons ]]--

--toggle config mode
local lock = Options:NewButton('Config Mode', 136, 22)
lock.UpdateText = function(self) self:SetText(Mangos:Locked() and L.EnterConfigMode or L.ExitConfigMode) end
lock:SetScript('OnShow', lock.UpdateText)
lock:SetScript('OnClick', function(self) Mangos:ToggleLockedFrames() self:UpdateText() end)
lock:SetPoint('TOPLEFT', 12, -72)

--toggle keybinding mode
local kb = LibStub('LibKeyBound-1.0')
local bind = Options:NewButton('Binding Mode', 136, 22)
bind.UpdateText = function(self) self:SetText(kb:IsShown() and L.ExitBindingMode or L.EnterBindingMode) end
bind:SetScript('OnShow', bind.UpdateText)
bind:SetScript('OnClick', function(self) kb:Toggle() self:UpdateText() end)
bind:SetPoint('LEFT', lock, 'RIGHT', 4, 0)


--[[ Check Buttons ]]--

--local action bar button positions
local lockButtons = Options:NewCheckButton(L.LockActionButtons)
lockButtons:SetScript('OnShow', function(self)
	self:SetChecked(LOCK_ACTIONBAR == '1')
end)
lockButtons:SetScript('OnClick', function(self)
	if self:GetChecked() then
		SetCVar('lockActionBars', 1)
		LOCK_ACTIONBAR = '1'
	else
		SetCVar('lockActionBars', 0)
		LOCK_ACTIONBAR = '0'
	end
end)
lockButtons:SetPoint('TOPLEFT', lock, 'BOTTOMLEFT', 0, -24)

--show empty buttons
local showEmpty = Options:NewCheckButton(L.ShowEmptyButtons)
showEmpty:SetScript('OnShow', function(self)
	self:SetChecked(Mangos:ShowGrid())
end)
showEmpty:SetScript('OnClick', function(self)
	Mangos:SetShowGrid(self:GetChecked())
end)
showEmpty:SetPoint('TOP', lockButtons, 'BOTTOM', 0, -10)

--show keybinding text
local showBindings = Options:NewCheckButton(L.ShowBindingText)
showBindings:SetScript('OnShow', function(self)
	self:SetChecked(Mangos:ShowBindingText())
end)
showBindings:SetScript('OnClick', function(self)
	Mangos:SetShowBindingText(self:GetChecked())
end)
showBindings:SetPoint('TOP', showEmpty, 'BOTTOM', 0, -10)

--show macro text
local showMacros = Options:NewCheckButton(L.ShowMacroText)
showMacros:SetScript('OnShow', function(self)
	self:SetChecked(Mangos:ShowMacroText())
end)
showMacros:SetScript('OnClick', function(self)
	Mangos:SetShowMacroText(self:GetChecked())
end)
showMacros:SetPoint('TOP', showBindings, 'BOTTOM', 0, -10)


--[[ Sliders ]]--

--[[
--minimum scale slider
local scale = Options:NewSlider(L.Scale, 50, 150, 1)
scale:SetScript('OnShow', function(self)
	self.onShow = true
	self:SetValue(100)
	self.onShow = nil
end)
scale:SetScript('OnValueChanged', function(self, value)
	self.valText:SetText(value)
	if not self.onShow then
		Mangos.Frame:ForAll('SetFrameScale', value/100)
	end
end)
scale:SetPoint('TOPLEFT', showMacros, 'BOTTOMLEFT', 0, -18)

--opacity
local opacity = Options:NewSlider(L.Opacity, 0, 100, 1)
opacity:SetScript('OnShow', function(self)
	self.onShow = true
	self:SetValue(100)
	self.onShow = nil
end)
opacity:SetScript('OnValueChanged', function(self, value)
	self.valText:SetText(value)
	if not self.onShow then
		Mangos.Frame:ForAll('SetFrameAlpha', value/100)
	end
end)
opacity:SetPoint('TOPLEFT', scale, 'BOTTOMLEFT', 0, -20)

--faded opacity
local faded = Options:NewSlider(L.FadedOpacity, 0, 100, 1)
faded:SetScript('OnShow', function(self)
	self.onShow = true
	self:SetValue(100)
	self.onShow = nil
end)
faded:SetScript('OnValueChanged', function(self, value)
	self.valText:SetText(value)
	if not self.onShow then
		Mangos.Frame:ForAll('SetFadeAlpha', value/100)
	end
end)
faded:SetPoint('TOPLEFT', opacity, 'BOTTOMLEFT', 0, -20)

--padding
local padding = Options:NewSlider(L.Padding, -16, 32, 1)
padding:SetScript('OnShow', function(self)
	self.onShow = true
	self:SetValue(0)
	self.onShow = nil
end)
padding:SetScript('OnValueChanged', function(self, value)
	self.valText:SetText(value)
	if not self.onShow then
		Mangos.Frame:ForAll('SetPadding', value)
	end
end)
padding:SetPoint('TOPLEFT', faded, 'BOTTOMLEFT', 0, -20)

--spacing
local spacing = Options:NewSlider(L.Spacing, -8, 32, 1)
spacing:SetScript('OnShow', function(self)
	self.onShow = true
	self:SetValue(0)
	self.onShow = nil
end)
spacing:SetScript('OnValueChanged', function(self, value)
	self.valText:SetText(value)
	if not self.onShow then
		Mangos.Frame:ForAll('SetSpacing', value)
	end
end)
spacing:SetPoint('TOPLEFT', padding, 'BOTTOMLEFT', 0, -20)
--]]



--[[ Dropdowns ]]--

do
	local info = {}
	local function AddItem(text, value, func, checked, arg1)
		info.text = text
		info.func = func
		info.value = value
		info.checked = checked
		info.arg1 = arg1
		UIDropDownMenu_AddButton(info)
	end

	local function AddClickActionSelector(self, name, action)
		local dd = self:NewDropdown(name)

		dd:SetScript('OnShow', function(self)
			UIDropDownMenu_SetWidth(110, self)
			UIDropDownMenu_Initialize(self, self.Initialize)
			UIDropDownMenu_SetSelectedValue(self, GetModifiedClick(action) or 'NONE')
		end)

		local function Item_OnClick()
			SetModifiedClick(action, this.value)
			UIDropDownMenu_SetSelectedValue(dd, this.value)
			SaveBindings(GetCurrentBindingSet())
		end

		function dd.Initialize()
			local selected = GetModifiedClick(action) or 'NONE'

			AddItem(ALT_KEY, 'ALT', Item_OnClick, 'ALT' == selected)
			AddItem(CTRL_KEY, 'CTRL', Item_OnClick, 'CTRL' == selected)
			AddItem(SHIFT_KEY, 'SHIFT', Item_OnClick, 'SHIFT' == selected)
			AddItem(NONE_KEY, 'NONE', Item_OnClick, 'NONE' == selected)
		end
		return dd
	end

	local function AddRightClickTargetSelector(self)
		local dd = self:NewDropdown(L.RightClickUnit)

		dd:SetScript('OnShow', function(self)
			UIDropDownMenu_SetWidth(110, self)
			UIDropDownMenu_Initialize(self, self.Initialize)
			UIDropDownMenu_SetSelectedValue(self, Mangos:GetRightClickUnit() or 'NONE')
		end)

		local function Item_OnClick()
			Mangos:SetRightClickUnit(this.value ~= 'NONE' and this.value or nil)
			UIDropDownMenu_SetSelectedValue(dd, this.value)
		end

		function dd.Initialize()
			local selected = Mangos:GetRightClickUnit()  or 'NONE'

			AddItem('Player', 'player', Item_OnClick, 'player' == selected)
			AddItem('Focus', 'focus', Item_OnClick, 'focus' == selected)
			AddItem('Mouseover', 'mouseover', Item_OnClick, 'mouseover' == selected)
			AddItem(NONE_KEY, 'NONE', Item_OnClick, 'NONE' == selected)
		end
		return dd
	end

	local function AddPossessBarSelector(self)
		local dd = self:NewDropdown(L.PossessBar)

		dd:SetScript('OnShow', function(self)
			UIDropDownMenu_SetWidth(110, self)
			UIDropDownMenu_Initialize(self, self.Initialize)
			UIDropDownMenu_SetSelectedValue(self, Mangos:GetPossessBar().id)
		end)

		local function Item_OnClick()
			Mangos:SetPossessBar(this.value)
			UIDropDownMenu_SetSelectedValue(dd, this.value)
		end

		function dd.Initialize()
			local selected = Mangos:GetPossessBar().id

			for i = 1, Mangos:NumBars() do
				AddItem('Action Bar ' .. i, i, Item_OnClick, i == selected)
			end
			AddItem('Pet Bar', 'pet', Item_OnClick, 'pet' == selected)
		end
		return dd
	end

	local selfCast = AddClickActionSelector(Options, L.SelfcastKey, 'SELFCAST')
	selfCast:SetPoint('TOPRIGHT', -10, -120)

	local quickMove = AddClickActionSelector(Options, L.QuickMoveKey, 'PICKUPACTION')
	quickMove:SetPoint('TOP', selfCast, 'BOTTOM', 0, -16)

	local rightClickUnit = AddRightClickTargetSelector(Options)
	rightClickUnit:SetPoint('TOP', quickMove, 'BOTTOM', 0, -16)

	local possess = AddPossessBarSelector(Options)
	possess:SetPoint('TOP', rightClickUnit, 'BOTTOM', 0, -16)
end
