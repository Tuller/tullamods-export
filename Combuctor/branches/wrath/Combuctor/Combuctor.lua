--[[
	Combuctor.lua
		Some sort of crazy visual inventory management system
--]]

LoadAddOn('Bagnon_Forever')

Combuctor = LibStub('AceAddon-3.0'):NewAddon('Combuctor', 'AceEvent-3.0', 'AceConsole-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale('Combuctor')
local CURRENT_VERSION = GetAddOnMetadata('Combuctor', 'Version')

--set the binding name stuff here, since its mostly locale independent
BINDING_HEADER_COMBUCTOR = 'Combuctor'
BINDING_NAME_COMBUCTOR_TOGGLE_INVENTORY = L.ToggleInventory
BINDING_NAME_COMBUCTOR_TOGGLE_BANK = L.ToggleBank

--[[
	Loading/Profile Functions
--]]

function Combuctor:OnInitialize()
	self.profile = self:InitDB()

	--version update
	local version = self.db.version
	if version then
		if version ~= CURRENT_VERSION then
			self:UpdateSettings(version:match('(%w+)%.(%w+)%.(%w+)'))
			self:UpdateVersion()
		end
	--new user
	else
		version = CURRENT_VERSION
	end

	--slash command support
	self:RegisterChatCommand('combuctor', 'OnSlashCommand')
	self:RegisterChatCommand('cbt', 'OnSlashCommand')
end

function Combuctor:InitDB()
	if not CombuctorDB2 then
		CombuctorDB2 = {
			version = CURRENT_VERSION,
			global = {
				maxScale = 1.5,
			},
			profiles = {
			}
		}
	end
	self.db = CombuctorDB2

	return self:GetProfile() or self:InitProfile()
end

function Combuctor:GetProfile(player)
	if not player then
		player = UnitName('player')
	end
	return self.db.profiles[player .. ' - ' .. GetRealmName()]
end


local function addSet(sets, name, ...)
	if select('#', ...) > 0 then
		table.insert(sets, {['name'] = name, ['exclude'] = {...}})
	else
		table.insert(sets, {['name'] = name})
	end
end

local function getDefaultInventorySets(class)
	local sets = {}
	if class == 'HUNTER' then
		addSet(sets, L.All, L.All, L.Shards)
	elseif class == 'WARLOCK' then
		addSet(sets, L.All, L.All, L.Ammo)
	else
		addSet(sets, L.All, L.All, L.Ammo, L.Shards)
	end
	return sets
end

local function getDefaultBankSets(class)
	local sets = {}
	addSet(sets, L.All, L.All, L.Shards, L.Ammo, L.Keys)
	addSet(sets, L.Equipment)
	addSet(sets, L.TradeGood)
	addSet(sets, L.Misc)

	return sets
end

function Combuctor:InitProfile()
	local player, realm = UnitName('player'), GetRealmName()
	local class = select(2, UnitClass('player'))
	local profile = self:GetBaseProfile()

	profile.inventory.sets = getDefaultInventorySets(class)
	profile.bank.sets = getDefaultBankSets(class)

	self.db.profiles[player .. ' - ' .. realm] = profile
	return profile
end

function Combuctor:GetBaseProfile()
	return {
		inventory = {
			bags = {-2, 0, 1, 2, 3, 4},
			position = {'RIGHT'},
			showBags = false,
			w = 384,
			h = 512,
		},

		bank = {
			bags = {-1, 5, 6, 7, 8, 9, 10, 11},
			showBags = false,
			w = 512,
			h = 512,
		}
	}
end

function Combuctor:UpdateSettings(major, minor, bugfix)
end

function Combuctor:UpdateVersion()
	self.db.version = CURRENT_VERSION
	self:Print(format(L.Updated, self.db.version))
end


--[[
	Events
--]]

function Combuctor:OnEnable()
	local profile = Combuctor:GetProfile(UnitName('player'))

	self.frames = {
		self.Frame:New(L.InventoryTitle, profile.inventory, false, 'inventory'),
		self.Frame:New(L.BankTitle, profile.bank, true, 'bank')
	}

	self:HookBagEvents()
end

function Combuctor:HookBagEvents()
	local AutoShowInventory = function()
		self:Show(BACKPACK_CONTAINER, true)
	end
	local AutoHideInventory = function()
		self:Hide(BACKPACK_CONTAINER, true)
	end

	--auto magic display code
	OpenBackpack = AutoShowInventory
	hooksecurefunc('CloseBackpack', AutoHideInventory)

	ToggleBag = function(bag)
		self:Toggle(bag)
	end

	ToggleBackpack = function()
		self:Toggle(BACKPACK_CONTAINER)
	end

	ToggleKeyRing = function()
		self:Toggle(KEYRING_CONTAINER)
	end

	OpenAllBags = function(force)
		if force then
			self:Show(BACKPACK_CONTAINER)
		else
			self:Toggle(BACKPACK_CONTAINER)
		end
	end

	--closing the game menu triggers this function, and can be done in combat,
	hooksecurefunc('CloseAllBags', function()
		self:Hide(BACKPACK_CONTAINER)
	end)

	BankFrame:UnregisterAllEvents()
	self:RegisterMessage('COMBUCTOR_BANK_OPENED', function()
		self:Show(BANK_CONTAINER, true)
		self:Show(BACKPACK_CONTAINER, true)
	end)
	self:RegisterMessage('COMBUCTOR_BANK_CLOSED', function()
		self:Hide(BANK_CONTAINER, true)
		self:Hide(BACKPACK_CONTAINER, true)
	end)

	self:RegisterEvent('MAIL_CLOSED', AutoHideInventory)
	self:RegisterEvent('TRADE_SHOW', AutoShowInventory)
	self:RegisterEvent('TRADE_CLOSED', AutoHideInventory)
	self:RegisterEvent('TRADE_SKILL_SHOW', AutoShowInventory)
	self:RegisterEvent('TRADE_SKILL_CLOSE', AutoHideInventory)
	self:RegisterEvent('AUCTION_HOUSE_SHOW', AutoShowInventory)
	self:RegisterEvent('AUCTION_HOUSE_CLOSED', AutoHideInventory)
	self:RegisterEvent('AUCTION_HOUSE_SHOW', AutoShowInventory)
	self:RegisterEvent('AUCTION_HOUSE_CLOSED', AutoHideInventory)
end

function Combuctor:Show(bag, auto)
	for _,frame in pairs(self.frames) do
		for _,bagID in pairs(frame.sets.bags) do
			if bagID == bag then
				frame:ShowFrame(auto)
				return
			end
		end
	end
end

function Combuctor:Hide(bag, auto)
	for _,frame in pairs(self.frames) do
		for _,bagID in pairs(frame.sets.bags) do
			if bagID == bag then
				frame:HideFrame(auto)
				return
			end
		end
	end
end

function Combuctor:Toggle(bag, auto)
	for _,frame in pairs(self.frames) do
		for _,bagID in pairs(frame.sets.bags) do
			if bagID == bag then
				frame:ToggleFrame(auto)
				return
			end
		end
	end
end

function Combuctor:OnSlashCommand(msg)
	local msg = msg and msg:lower()

	if msg == 'bank' then
		self:Toggle(BANK_CONTAINER)
	elseif msg == 'bags' then
		self:Toggle(BACKPACK_CONTAINER)
	else
		self:Print('Commands (/cbt or /combuctor)')
		DEFAULT_CHAT_FRAME:AddMessage('- bank: Toggle bank')
		DEFAULT_CHAT_FRAME:AddMessage('- bags: Toggle inventory')
	end
end


--[[ Utility Functions ]]--

function Combuctor:SetMaxItemScale(scale)
	self.db.global.maxScale = scale or 1
end

function Combuctor:GetMaxItemScale()
	return self.db.global.maxScale
end

--utility function: create a widget class
function Combuctor:NewClass(type, parentClass)
	local class = CreateFrame(type)
	class.mt = {__index = class}

	if parentClass then
		class = setmetatable(class, {__index = parentClass})
		class.super = parentClass
	end

	function class:Bind(o)
		return setmetatable(o, self.mt)
	end

	return class
end