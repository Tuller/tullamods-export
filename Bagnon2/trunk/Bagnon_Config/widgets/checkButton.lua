--[[
	dropdown.lua
		A bagnon dropdown menu
--]]

local OptionsCheckButton = Bagnon.Classy:New('CheckButton')
Bagnon.OptionsCheckButton = OptionsCheckButton

function OptionsCheckButton:New(name, parent)
	local b = self:Bind(CreateFrame('CheckButton', parent:GetName() .. name, parent, 'InterfaceOptionsCheckButtonTemplate'))
	_G[b:GetName() .. 'Text']:SetText(name)

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnShow', b.OnShow)

	return b
end

function OptionsCheckButton:OnClick()
	self:EnableSetting(self:GetChecked())
end

function OptionsCheckButton:OnShow()
	self:UpdateChecked()
end

function OptionsCheckButton:UpdateChecked()
	self:SetChecked(self:IsSettingEnabled())
end

function OptionsCheckButton:EnableSetting(enable)
	self:OnEnableSetting(enable)
	self:UpdateChecked()
end

function OptionsCheckButton:OnEnableSetting(enable)
	assert(false, 'Hey you forgot to implement OnEnableSetting for ' .. self:GetName())
end

function OptionsCheckButton:IsSettingEnabled()
	assert(false, 'Hey you forgot to implement IsSettingEnabled for ' .. self:GetName())
end