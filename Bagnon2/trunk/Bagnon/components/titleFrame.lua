--[[
	titleFrame.lua
		A title frame widget
--]]


local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')

local TitleFrame = Bagnon.Classy:New('Button')
TitleFrame:Hide()
Bagnon.TitleFrame = TitleFrame


--[[ Constructor ]]--

function TitleFrame:New(text, frameID, parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))	
	b:SetToplevel(true)

	b:SetNormalFontObject('GameFontNormalLeft')
	b:SetHighlightFontObject('GameFontHighlightLeft')
	b:RegisterForClicks('anyUp')
	
	b:SetScript('OnShow', b.OnShow)
	b:SetScript('OnHide', b.OnHide)
	b:SetScript('OnMouseDown', b.OnMouseDown)
	b:SetScript('OnMouseUp', b.OnMouseUp)

	b:SetFrameID(frameID)
	b:SetTitleText(text)
	b:UpdateEvents()

	return b
end


--[[ Messages ]]--

function TitleFrame:PLAYER_UPDATE(msg, frameID, player)
	if frameID == self:GetFrameID() then
		self:UpdateText()
	end
end


--[[ Frame Events ]]--

function TitleFrame:OnShow()
	self:UpdateText()
	self:UpdateEvents()
end

function TitleFrame:OnHide()
	self:StopMovingFrame()
end

function TitleFrame:OnMouseDown()
	if self:IsFrameMovable() or IsAltKeyDown() then
		self:StartMovingFrame()
	end
end

function TitleFrame:OnMouseUp()
	self:StopMovingFrame()
end

function TitleFrame:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	
	self:UpdateTooltip()
end

function TitleFrame:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end


--[[ Update Methods ]]--

function TitleFrame:UpdateText()
	self:SetText(self:GetTitleText():format(self:GetPlayer()))
end

function TitleFrame:UpdateTooltip()
	if not GameTooltip:IsOwned(self) then return end
	
	GameTooltip:SetText(self:GetText(), 1, 1, 1)
	GameTooltip:Show()
end

function TitleFrame:UpdateEvents()
	self:UnregisterAllMessages()
	
	if self:IsVisible() then
		self:RegisterMessage('PLAYER_UPDATE')
	end
end

function TitleFrame:StartMovingFrame()
	self:SendMessage('FRAME_MOVE_START', self:GetFrameID())
end

function TitleFrame:StopMovingFrame()
	self:SendMessage('FRAME_MOVE_STOP', self:GetFrameID())
end


--[[ Properties ]]--

function TitleFrame:SetFrameID(frameID)
	if self:GetFrameID() ~= frameID then
		self.frameID = frameID
		self:UpdateText()
	end
end

function TitleFrame:GetFrameID()
	return self.frameID
end

function TitleFrame:SetTitleText(text)
	if self:GetTitleText() ~= text then
		self.titleText = text
		self:UpdateText()
	end
end

function TitleFrame:GetTitleText()
	return self.titleText or ''
end


--[[ Frame Settings ]]--

function TitleFrame:GetSettings()
	return Bagnon.FrameSettings:Get(self:GetFrameID())
end

function TitleFrame:GetPlayer()
	return self:GetSettings():GetPlayerFilter()
end

function TitleFrame:IsFrameMovable()
	return self:GetSettings():IsMovable()
end