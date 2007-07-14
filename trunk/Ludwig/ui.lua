--[[
	ui.lua
		A UI for Ludwig
--]]

LWUI_SHOWN, LWUI_STEP = 15, 15

local L = LUDWIG_LOCALS
local ITEM_WIDTH = 300
local display, displayChanged --all things to display on the list
local filter = {}
local uiFrame


--[[ Main Frame Functions ]]--

function LudwigUI_OnLoad(self)
	local name = self:GetName()
	tinsert(UISpecialFrames, name)
	local items = {}

	local item = CreateFrame("Button", name .. 1, self, "LudwigItemButtonTemplate")
	item:SetPoint("TOPLEFT", self, "TOPLEFT", 19, -75)
	item.icon = getglobal(item:GetName() .. "Icon")
	items[1] = item

	for i = 2, LWUI_SHOWN do
		item = CreateFrame("Button", name .. i, self, "LudwigItemButtonTemplate")
		item:SetPoint("TOPLEFT", items[i-1], "BOTTOMLEFT")
		item:SetPoint("TOPRIGHT", items[i-1], "BOTTOMRIGHT")
		item.icon = getglobal(item:GetName() .. "Icon")
		items[i] = item
	end

	self.items = items
	self.title = getglobal(name .. "Text")
	self.scrollFrame = getglobal(name.. "Scroll")
	self.quality = getglobal(name .. "Quality")
	self.type = getglobal(name .. "Type")
	self.frame = frame
	uiFrame = self
end

function LudwigUI_OnShow()
	LudwigUI_Refresh()
end

function LudwigUI_OnHide()
	for i in pairs(display) do display[i] = nil end
	LudwigUI_Reset()
end

function LudwigUI_Refresh()
	Ludwig:ReloadDB()
	LudwigUI_UpdateList(true)
end

function LudwigUI_Reset()
	local changed
	for i in pairs(filter) do
		if(filter[i] ~= nil) then
			changed = true
			filter[i] = nil
		end
	end

	--reset search text
	local search = getglobal(uiFrame:GetName() .. "Search")
	if(search:HasFocus()) then
		search:SetText("")
	else
		search:SetText(SEARCH)
	end

	getglobal(uiFrame:GetName() .. "MinLevel"):SetText("")
	getglobal(uiFrame:GetName() .. "MaxLevel"):SetText("")

	LudwigUI_UpdateTypeText()
	LudwigUI_UpdateQualityText()

	if(uiFrame:IsShown()) then
		LudwigUI_UpdateList(changed)
	end
end

--[[ Scroll Frame Events ]]--

function LudwigUI_OnScrollFrameShow()
	uiFrame.items[1]:SetWidth(ITEM_WIDTH)
end

function LudwigUI_OnScrollFrameHide()
	uiFrame.items[1]:SetWidth(ITEM_WIDTH + 20)
end


--[[ List Updating ]]--

function LudwigUI_UpdateList(changed)
	--update list only if there are changes
	if not display or changed then
		displayChanged = nil
		display = Ludwig:GetItems(filter.name, filter.quality, filter.type, filter.subType, filter.equipLoc, filter.minLevel, filter.maxLevel)
	end

	local size = #display
	uiFrame.title:SetText(format(L.FrameTitle, size))

	FauxScrollFrame_Update(uiFrame.scrollFrame, size, LWUI_SHOWN, LWUI_STEP)

	local offset = uiFrame.scrollFrame.offset
	for i,button in ipairs(uiFrame.items) do
		local index = i + offset
		if index > size then
			button:Hide()
		else
			local id = display[index]
			button.icon:SetTexture(Ludwig:GetItemTexture(id))
			button:SetText(Ludwig:GetItemName(id, true))
			button:SetID(id)
			button:Show()
		end
	end
end


--[[ Item Button ]]--

local function Item_UpdateTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetHyperlink(Ludwig:GetItemLink(self:GetID()))

	if IsShiftKeyDown() then
		GameTooltip_ShowCompareItem()
	end
	GameTooltip:Show()
end

function LudwigUI_OnItemClick(self)
	if IsShiftKeyDown() then
		ChatFrameEditBox:Insert(Ludwig:GetItemLink(self:GetID()))
	elseif IsControlKeyDown() then
		DressUpItemLink(Ludwig:GetItemLink(self:GetID()))
	else
		SetItemRef(Ludwig:GetItemLink(self:GetID()))
	end
end

function LudwigUI_OnItemEvent(self)
	Item_UpdateTooltip(self)
end

function LudwigUI_OnItemEnter(self)
	self:RegisterEvent("MODIFIER_STATE_CHANGED")
	Item_UpdateTooltip(self)
end

function LudwigUI_OnItemLeave(self)
	self:UnregisterEvent("MODIFIER_STATE_CHANGED")
	GameTooltip:Hide()
end


--[[ Text Search ]]--

function LudwigUI_OnSearchChanged(self, text)
	if(self:HasFocus()) then
		if text == "" then
			text = nil
		end
		if(filter.name ~= text) then
			filter.name = text
			LudwigUI_UpdateList(true)
		end
	end
end

function LudwigUI_OnMinLevelChanged(self, text)
	if(self:HasFocus()) then
		if text == "" then
			text = nil
		end
		if(filter.minLevel ~= tonumber(text)) then
			filter.minLevel = tonumber(text)
			LudwigUI_UpdateList(true)
		end
	end
end

function LudwigUI_OnMaxLevelChanged(self, text)
	if(self:HasFocus()) then
		if text == "" then
			text = nil
		end
		if(filter.maxLevel ~= tonumber(text)) then
			filter.maxLevel = tonumber(text)
			LudwigUI_UpdateList(true)
		end
	end
end


--[[ Dropdowns ]]--

local info = {}
local function AddItem(text, value, func, hasArrow, level, arg1, arg2)
	info.text = text
	info.func = func
	info.value = value
	info.hasArrow = (hasArrow and true) or nil
	info.notCheckable = true
	info.arg1 = arg1
	info.arg2 = arg2
	UIDropDownMenu_AddButton(info, level)
end


--[[ Quality ]]--

local function Quality_GetText(index)
	if tonumber(index) then
		local hex = select(4, GetItemQualityColor(index))
		return hex .. getglobal("ITEM_QUALITY" .. index .. "_DESC") .. "|r"
	end
	return ALL
end

local function Quality_OnClick()
	if(this.value == ALL) then
		filter.quality = nil
	else
		filter.quality = this.value
	end
	LudwigUI_UpdateQualityText()
	LudwigUI_UpdateList(true)
end

--add all buttons to the dropdown menu
local function Quality_Initialize()
	AddItem(ALL, ALL, Quality_OnClick)
	for i = 6, 0, -1 do
		AddItem(Quality_GetText(i), i, Quality_OnClick)
	end
end

function LudwigUI_OnQualityShow(self)
	UIDropDownMenu_Initialize(self, Quality_Initialize)
	UIDropDownMenu_SetWidth(90, self)
	LudwigUI_UpdateQualityText()
end

function LudwigUI_UpdateQualityText()
	getglobal(uiFrame.quality:GetName() .. "Text"):SetText(Quality_GetText(filter.quality))
end


--[[ Type ]]--

local function Types_Generate()
	local types = {GetAuctionItemClasses()}
	table.insert(types, L.Quest)
	table.insert(types, L.Key)

	local subTypes = {}
	for i in ipairs(types) do
		if GetAuctionItemSubClasses(i) then
			subTypes[i] = {GetAuctionItemSubClasses(i)}
		end
	end

	local tradeGoods = subTypes[5] or {}
	table.insert(tradeGoods, L.TradeGoods)
	table.insert(tradeGoods, L.Devices)
	table.insert(tradeGoods, L.Explosives)
	table.insert(tradeGoods, L.Parts)
	subTypes[5] = tradeGoods

	local misc = subTypes[11] or {}
	table.insert(misc, L.Junk)
	subTypes[11] = misc

	return types, subTypes
end
local types, subTypes = Types_Generate()
local type, subType

local function Type_UpdateText()
	local text
	if(filter.type) then
		if(filter.subType) then
			text = format("%s - %s", filter.type, filter.subType)
			if(filter.equipLoc) then
				text = format("%s - %s", filter.subType, getglobal(filter.equipLoc))
			end
		else
			text = filter.type
		end
	else
		text = ALL
	end
	getglobal(uiFrame.type:GetName() .. "Text"):SetText(text)
end

local function Type_OnClick(arg1, arg2)
	local type, subType = this.arg1, this.arg2
	local text

	filter.type = nil
	filter.subType = nil
	filter.equipLoc = nil

	if(type) then
		filter.type = types[type]
		if(subType) then
			filter.subType = subTypes[type][subType]
			filter.equipLoc = select(this.value, GetAuctionInvTypes(type, subType))
		else
			filter.subType = subTypes[type][this.value]
		end
	else
		filter.type = types[this.value]
	end
	LudwigUI_UpdateTypeText()
	LudwigUI_UpdateList(true)
end

local function AddTypes(level)
	AddItem(ALL, ALL, Type_OnClick)
	for i,text in pairs(types) do
		AddItem(text, i, Type_OnClick, subTypes[i], level)
	end
end

local function AddSubTypes(level)
	type = UIDROPDOWNMENU_MENU_VALUE

	if subTypes[type] then
		for i,text in ipairs(subTypes[type]) do
			AddItem(text, i, Type_OnClick, GetAuctionInvTypes(type, i), level, type)
		end
	end
end

local function AddEquipLocations(level)
	subType = UIDROPDOWNMENU_MENU_VALUE

	for i = 1, select("#", GetAuctionInvTypes(type, subType)) do
		local equipLoc = getglobal(select(i, GetAuctionInvTypes(type, subType)))
		AddItem(equipLoc, i, Type_OnClick, false, level, type, subType)
	end
end

local function Type_Initialize(level)
	local level = level or 1

	if(level == 1) then
		AddTypes(level)
	elseif(level == 2) then
		AddSubTypes(level)
	elseif(level == 3) then
		AddEquipLocations(level)
	end
end

function LudwigUI_UpdateTypeText()
	local text
	if(filter.type) then
		if(filter.subType) then
			text = format("%s - %s", filter.type, filter.subType)
			if(filter.equipLoc) then
				text = format("%s - %s", filter.subType, getglobal(filter.equipLoc))
			end
		else
			text = filter.type
		end
	else
		text = ALL
	end
	getglobal(uiFrame.type:GetName() .. "Text"):SetText(text)
end

function LudwigUI_OnTypeShow(self)
	UIDropDownMenu_Initialize(self, Type_Initialize)
	UIDropDownMenu_SetWidth(200, self)
	LudwigUI_UpdateTypeText()
end