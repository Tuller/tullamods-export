--[[
	Sage.lua
		Driver for Sage bars
--]]

Sage = DongleStub("Dongle-1.0"):New("Sage")
Sage.dbName = "Sage2DB"

local CURRENT_VERSION = GetAddOnMetadata("Sage", "Version")
local TEXTURE_PATH = "Interface\\AddOns\\Sage\\textures\\%s"
local BLIZZ_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local L = SAGE_LOCALS


--[[ Startup ]]--

function Sage:Enable()
	self:RegisterMessage("DONGLE_PROFILE_CREATED")
	self:RegisterMessage("DONGLE_PROFILE_CHANGED")
	self:RegisterMessage("DONGLE_PROFILE_DELETED")
	self:RegisterMessage("DONGLE_PROFILE_COPIED")
	self:RegisterMessage("DONGLE_PROFILE_RESET")

	local defaults = {
		profile = {
			version = CURRENT_VERSION,
			locked = true,
			sticky = true,
			showText = false,
			showCastBars = true,
			showPercents = false,
			outlineBarFonts = false,
			outlineOutsideFonts = false,
			debuffColoring = true,
			fontSize = 14,
			barTexture = "skewed",
			frames = {}
		}
	}

	self.db = self:InitializeDB(self.dbName, defaults, "Default")
	self.profile = self.db.profile

	local cMajor, cMinor = CURRENT_VERSION:match("(%d+)%.(%d+)")
	local major, minor = self.profile.version:match("(%d+)%.(%d+)")

	if major ~= cMajor then
		self.db:ResetProfile()
		self:Print(L.UpdatedIncompatible)
	elseif minor ~= cMinor then
		self:UpdateVersion()
	end

	self:RegisterEvents()
	self:RegisterSlashCommands()
	self:LoadModules()
end

-- function Sage:Disable()
	-- local frameSettings = self.profile.frames
	-- for id in pairs(frameSettings) do
		-- if(not SageFrame:Get(id)) then
			-- frameSettings[id] = nil
		-- end
	-- end
-- end

function Sage:UpdateVersion()
	self.profile.version = CURRENT_VERSION
	self:Print(format(L.Updated, self.profile.version))
end

function Sage:LoadModules()
	SageFont:Update()
	for name, module in self:IterateModules() do
		assert(module.Load, format("Sage Module %s: Missing Load function", name))
		module:Load()
	end
	SageFrame:ForAll("Reanchor")
end

function Sage:UnloadModules()
	for name, module in self:IterateModules() do
		assert(module.Unload, format("Sage Module %s: Missing Unload function", name))
		module:Unload()
	end
end

function Sage:RegisterEvents()
	self:RegisterEvent("UNIT_HEALTH", "UpdateHealth")
	self:RegisterEvent("UNIT_MAXHEALTH", "UpdateHealth")

	self:RegisterEvent("UNIT_MANA", "UpdateMana")
	self:RegisterEvent("UNIT_RAGE", "UpdateMana")
	self:RegisterEvent("UNIT_FOCUS", "UpdateMana")
	self:RegisterEvent("UNIT_ENERGY", "UpdateMana")
	self:RegisterEvent("UNIT_MAXMANA", "UpdateMana")
	self:RegisterEvent("UNIT_MAXRAGE", "UpdateMana")
	self:RegisterEvent("UNIT_MAXFOCUS", "UpdateMana")
	self:RegisterEvent("UNIT_MAXENERGY", "UpdateMana")
	self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateMana")

	self:RegisterEvent("UNIT_AURA", "UpdateBuff")

	self:RegisterEvent("UNIT_FACTION", "UpdateInfo")
	self:RegisterEvent("UNIT_NAME_UPDATE", "UpdateInfo")
	self:RegisterEvent("UNIT_LEVEL", "UpdateInfo")
	self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateInfo")
	
	self:RegisterEvent("PARTY_LEADER_CHANGED", "UpdateInfo")
	self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED", "UpdateInfo")
	
	-- self:RegisterEvent("UNIT_MODEL_CHANGED", "DumpInfo")
	-- self:RegisterEvent("PARTY_MEMBER_ENABLE", "DumpInfo")

	self:SetShowCastBars(self:ShowingCastBars())
end


--[[ Profile Functions ]]--

function Sage:SetProfile(name, mustExist)
	local profile
	if(mustExist) then
		profile = self:MatchProfile(name)
	else
		profile = name
	end

	if profile and profile ~= self.db:GetCurrentProfile() then
		self:UnloadModules()
		self.db:SetProfile(profile)
	end
end

function Sage:DeleteProfile(name)
	local profile = self:MatchProfile(name)
	if profile and profile ~= self.db:GetCurrentProfile() then
		self.db:DeleteProfile(profile)
	else
		self:Print(L.CantDeleteCurrentProfile)
	end
end

function Sage:CopyProfile(name)
	local profile = self:MatchProfile(name)
	if profile and profile ~= self.db:GetCurrentProfile() then
		self:UnloadModules()
		self.db:CopyProfile(profile)
	end
end

function Sage:ResetProfile()
	self:UnloadModules()
	self.db:ResetProfile()
end

function Sage:ListProfiles()
	self:Print(L.AvailableProfiles)
	for i, k in ipairs(self.db:GetProfiles()) do
		self:Print(k)
	end
end

function Sage:MatchProfile(name)
	local profileList = self.db:GetProfiles()

	local name = name:lower()
	local nameRealm = format("%s - %s", name, GetRealmName():lower())

	for i, k in ipairs(profileList) do
		local key = k:lower()
		if key == name or key == nameRealm then
			return k
		end
	end
end


--[[ Events ]]--

function Sage:UpdateHealth(event, ...)
	SageHealth:OnEvent(...)
	if Sage:ShowingPercents() then
		SageInfo:OnHealthEvent(...)
	end
end

function Sage:UpdateMana(event, ...)
	SageMana:OnEvent(...)
end

function Sage:UpdateBuff(event, ...)
	SageBuff:OnEvent(...)
	SageHealth:OnBuffEvent(...)
end

function Sage:UpdateInfo(event, ...)
	SageInfo[event](SageInfo, ...)
end

function Sage:UpdateCast(event, ...)
	SageCast[event](SageCast, ...)
end

function Sage:DumpInfo(...)
	self:Print(...)
end


--[[ Messages ]]--

function Sage:DONGLE_PROFILE_CREATED(event, db, parent, sv_name, profile_key)
	if(sv_name == self.dbName) then
		self.profile = self.db.profile
		self:Print(format(L.ProfileCreated , profile_key))
	end
end

function Sage:DONGLE_PROFILE_CHANGED(event, db, parent, sv_name, profile_key)
	if(sv_name == self.dbName) then
		self.profile = self.db.profile
		self:Print(format(L.ProfileLoaded, profile_key))
	end
end

function Sage:DONGLE_PROFILE_DELETED(event, db, parent, sv_name, profile_key)
	if(sv_name == self.dbName) then
		self:Print(format(L.ProfileDeleted, profile_key))
	end
end

function Sage:DONGLE_PROFILE_COPIED(event, db, parent, sv_name, profile_key, intoProfile_key)
	if(sv_name == self.dbName) then
		self.profile = self.db.profile
		self:LoadModules()
		self:Print(format(L.ProfileCopied, profile_key, intoProfile_key))
	end
end

function Sage:DONGLE_PROFILE_RESET(event, db, parent, sv_name, profile_key)
	if(sv_name == self.dbName) then
		self.profile = self.db.profile
		self:LoadModules()
		self:Print(format(L.ProfileReset, profile_key))
	end
end


--[[ Settings Access ]]--

function Sage:SetFrameSets(id, sets)
	local id = tonumber(id) or id
	self.profile.frames[id] = sets
	return self.profile.frames[id]
end

function Sage:GetFrameSets(id)
	return self.profile.frames[tonumber(id) or id]
end


--[[ Slash Commands ]]--

function Sage:RegisterSlashCommands()
	local cmdStr = "|cFF33FF99%s|r: %s"

	local slash = self:InitializeSlashCommand("Sage Commands", "SAGE", "sage", "sg")
	slash:RegisterSlashHandler(format(cmdStr, "/sage", "Toggles the option menu"), "^$", "ShowMenu")
	slash:RegisterSlashHandler(format(cmdStr, "lock", L.LockFramesDesc), "^lock$", "ToggleLock")
	slash:RegisterSlashHandler(format(cmdStr, "sticky", L.StickyFramesDesc), "^sticky$", "ToggleSticky")

	slash:RegisterSlashHandler(format(cmdStr, "scale <frameList> <scale>", L.SetScaleDesc), "^scale (.+) ([%d%.]+)", "SetFrameScale")
	slash:RegisterSlashHandler(format(cmdStr, "setalpha <frameList> <opacity>", L.SetAlphaDesc), "^setalpha (.+) ([%d%.]+)", "SetFrameAlpha")
	slash:RegisterSlashHandler(format(cmdStr, "texture <texture>", "Sets the statusbar texture"), "^texture ([%w_]+)", "SetBarTexture")
	
	slash:RegisterSlashHandler(format(cmdStr, "set <profle>", L.SetDesc), "set (%w+)", "SetProfile")
	slash:RegisterSlashHandler(format(cmdStr, "copy <profile>", L.CopyDesc), "copy (%w+)", "CopyProfile")
	slash:RegisterSlashHandler(format(cmdStr, "delete <profile>", L.DeleteDesc), "^delete (%w+)", "DeleteProfile")
	slash:RegisterSlashHandler(format(cmdStr, "reset", L.ResetDesc), "^reset$", "ResetProfile")
	slash:RegisterSlashHandler(format(cmdStr, "list", L.ListDesc), "^list$", "ListProfiles")
	slash:RegisterSlashHandler(format(cmdStr, "version", L.PrintVersionDesc), "^version$", "PrintVersion")

	self.slash = slash
end

function Sage:ShowMenu()
	local enabled = select(4, GetAddOnInfo("Sage_Options"))
	if enabled then
		if SageOptions then
			if SageOptions:IsShown() then
				SageOptions:Hide()
			else
				SageOptions:Show()
			end
		else
			LoadAddOn("Sage_Options")
		end
	else
		self.slash:PrintUsage()
	end
end

function Sage:PrintVersion()
	self:Print(self.profile.version)
end

function Sage:SetFrameScale(args, scale)
	local scale = tonumber(scale)
	if scale and scale > 0 and scale <= 10 then
		for _,frameList in pairs({strsplit(" ", args)}) do
			SageFrame:ForFrame(frameList, "SetFrameScale", scale)
		end
	end
end

function Sage:SetFrameAlpha(args, alpha)
	local alpha = tonumber(alpha)
	if alpha and alpha >= 0 and alpha <= 1 then
		for _,frameList in pairs({strsplit(" ", args)}) do
			SageFrame:ForFrame(frameList, "SetFrameAlpha", alpha)
		end
	end
end


--[[ Config Functions ]]--

--lock frame positions
function Sage:SetLock(enable)
	self.profile.locked = enable or false
	SageFrame:ForAll((enable and "Lock") or "Unlock")
end

function Sage:IsLocked()
	return self.profile.locked
end

function Sage:ToggleLock()
	self:SetLock(not self:IsLocked())
end

--auto docking bars
function Sage:SetSticky(enable)
	self.profile.sticky = enable or false
	SageFrame:ForAll("Reanchor")
end

function Sage:IsSticky()
	return self.profile.sticky
end

function Sage:ToggleSticky()
	self:SetSticky(not self:IsSticky())
end

--text visibility
function Sage:SetShowText(enable)
	self.profile.showText = enable or false
	SageBar:ForAll("ShowText", enable)
end

function Sage:ShowingText()
	return self.profile.showText
end

--bar textures
function Sage:SetBarTexture(texture)
	self.profile.barTexture = texture
	SageBar:UpdateAllTextures()
end

function Sage:GetBarTexture()
	local texture = self.profile.barTexture or "Blizz"
	return (texture == "Blizz" and BLIZZ_TEXTURE) or format(TEXTURE_PATH, texture)
end

--font size
function Sage:SetFontSize(size)
	self.profile.fontSize = size
	SageFont:Update()
end

function Sage:GetFontSize()
	return self.profile.fontSize or DEFAULT_FONT_SIZE
end

--outline statusbar fonts
function Sage:SetOutlineBarFonts(enable)
	self.profile.outlineBarFonts = enable or false
	SageFont:UpdateBarFonts()
end

function Sage:OutlineBarFonts()
	return self.profile.outlineBarFonts
end

--outline outside fonts
function Sage:SetOutlineOutsideFonts(enable)
	self.profile.outlineOutsideFonts = enable or false
	SageFont:UpdateOutsideFonts()
end

function Sage:OutlineOutsideFonts()
	return self.profile.outlineOutsideFonts
end

--color healthbars when debuffed
function Sage:SetDebuffColoring(enable)
	self.profile.debuffColoring = enable or false
	SageHealth:ForAll("UpdateDebuff")
end

function Sage:DebuffColoring()
	return self.profile.debuffColoring
end

--health text mode
function Sage:SetHealthTextMode(mode)
	local sets = self:GetFrameSets(unit)
	if sets then
		sets.healthTextMode = mode
	end
end

function Sage:GetHealthTextMode(unit)
	local sets = self:GetFrameSets(unit)
	return sets and sets.healthTextMode
end

--mana text mode
function Sage:SetManaTextMode(mode)
	local sets = self:GetFrameSets(unit)
	if sets then
		sets.manaTextMode = mode
	end
end

function Sage:GetManaTextMode(unit)
	local sets = self:GetFrameSets(unit)
	return sets and sets.manaTextMode
end

--health percentages
function Sage:SetShowPercents(enable)
	self.profile.showPercents = enable or false
	SageInfo:ForAll("UpdatePercents")
end

function Sage:ShowingPercents()
	return self.profile.showPercents
end

--cast bars
function Sage:SetShowCastBars(enable)
	self.profile.showCastBars = enable or false
	if(enable) then
		self:RegisterEvent("UNIT_SPELLCAST_START", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_DELAYED", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_STOP", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_FAILED", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "UpdateCast")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "UpdateCast")
	else
		self:UnregisterEvent("UNIT_SPELLCAST_START")
		self:UnregisterEvent("UNIT_SPELLCAST_DELAYED")
		self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		self:UnregisterEvent("UNIT_SPELLCAST_STOP")
		self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	end
	SageCast:ForAll("Update")
end

function Sage:ShowingCastBars()
	return self.profile.showCastBars
end

function Sage:SetShowPartyInRaid(enable)
	self.profile.showPartyInRaid = enable or false
end

function Sage:ShowingPartyInRaid()
	return self.profile.showPartyInRaid
end