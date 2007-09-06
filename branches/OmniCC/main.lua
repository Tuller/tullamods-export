--[[
	OmniCC
		A universal cooldown count, based on an idea by Gello
--]]

local L = OMNICC_LOCALS
local ICON_SCALE = 37

local active = {}
local activePulses = {}
local blackList = {}

local function msg(message, showAddon)
	if showAddon then
		ChatFrame1:AddMessage(format("|cFF33FF99OmniCC|r: %s", tostring(message)))
	else
		ChatFrame1:AddMessage(tostring(message))
	end
end

OmniCC = CreateFrame("Frame")
OmniCC:Hide()

OmniCC:SetScript("OnEvent", function(self, event, arg1)
	if arg1 == "OmniCC" then
		self:UnregisterEvent(event)
		self:Init()
	end
end)
OmniCC:RegisterEvent("ADDON_LOADED")

OmniCC:SetScript("OnUpdate", function(self)
	if next(activePulses) then
		for pulse in pairs(activePulses) do
			self:UpdatePulse(pulse)
		end
	else
		self:Hide()
	end
end)


--[[ Settings Loading ]]--

function OmniCC:Init()
	self:LoadSettings()
	self:LoadFont()
end

function OmniCC:LoadSettings()
	local current = GetAddOnMetadata("OmniCC", "Version")

	if not(OmniCC2DB and OmniCC2DB.version) then
		self:LoadDefaults(current)
		msg(L.Initialized, true)
	else
		local cMajor, cMinor = current:match("(%d+)%.(%d+)")
		local major, minor = OmniCC2DB.version:match("(%d+)%.(%d+)")

		if major ~= cMajor then
			self:LoadDefaults(current)
			msg(L.UpgradeIncompatible, true)
		elseif minor ~= cMinor then
			self:UpdateSettings(current)
		end
	end
	self.sets = OmniCC2DB
end

function OmniCC:LoadDefaults(current)
	OmniCC2DB = {
		version = current,								--minimum duration to show text
		vlong = {r = 0.8, g = 0.8, b = 0.9, s = 0.6}, 	--settings for cooldowns greater than an hour
		long = {r = 0.8, g = 0.8, b = 0.9, s = 0.8}, 	--settings for cooldowns greater than one minute
		med = {r = 1, g = 1, b = 0.4, s = 1}, 			--settings for cooldowns under a minute
		short = {r = 1, g = 0, b = 0, s = 1.3}, 		--settings for cooldowns less than five seconds
		useBlacklist = 1,
	}
end

function OmniCC:UpdateSettings(current)
	OmniCC2DB.useBlacklist = 1
	OmniCC2DB.version = current
	msg(format(L.Updated, OmniCC2DB.version), true)
end


--[[ Config Functions ]]--

function OmniCC:UpdateActiveTimers()
	for timer in pairs(active) do
		self:UpdateTimer(timer)
	end
end

function OmniCC:Reset()
	self:LoadDefaults(GetAddOnMetadata("OmniCC", "Version"))
	self:UpdateActiveTimers()
end


--font
function OmniCC:LoadFont()
	if not self.font then
		self.font = CreateFont("OmniCCFont")
	end

	local font, size = self:GetFont()

	if not self.font:SetFont(font, size) then
		self.sets.font = nil
		self.font:SetFont(STANDARD_TEXT_FONT, size)
	end
end

function OmniCC:SetFont(font)
	self.sets.font = font
	self:LoadFont()
	self:UpdateActiveTimers()
end

function OmniCC:SetFontSize(size)
	self.sets.fontSize = size
	self:UpdateActiveTimers()
end

function OmniCC:SetFontFormat(index, r, g, b, s)
	local sets = self.sets[index]
	if sets then
		sets.r = r or sets.r
		sets.g = g or sets.g
		sets.b = b or sets.b
		sets.s = s or sets.s
	end
	self:UpdateActiveTimers()
end

function OmniCC:GetFont()
	return self.sets.font or STANDARD_TEXT_FONT, self.sets.fontSize or 20
end


--model
function OmniCC:ToggleModel()
	if self.sets.hideModel then
		self.sets.hideModel = nil
	else
		self.sets.hideModel = 1
	end
end

function OmniCC:ShowingModel()
	return not self.sets.hideModel
end


--time format
function OmniCC:ToggleMMSS()
	if self.sets.mmSS then
		self.sets.mmSS = nil
	else
		self.sets.mmSS = 1
	end
	self:UpdateActiveTimers()
end

function OmniCC:InMMSSFormat()
	return self.sets.mmSS
end


--minimum duration
function OmniCC:SetMinimumDuration(duration)
	self.sets.minDur = duration
end

function OmniCC:GetMinimumDuration()
	return self.sets.minDur or 3
end


--pulse
function OmniCC:TogglePulse()
	if self.sets.pulse then
		self.sets.pulse = nil
	else
		self.sets.pulse = 1
	end
end

function OmniCC:ShowingPulse()
	return self.sets.pulse
end


--frame blacklisting
function OmniCC:ToggleBlacklist()
	if self.sets.useBlacklist then
		self.sets.useBlacklist = nil
	else
		self.sets.useBlacklist = 1
	end
end

function OmniCC:UsingBlacklist()
	return self.sets.useBlacklist
end

function OmniCC:Blacklist(name)
	table.insert(blackList, name)
end


--[[ Cooldown Timer Code ]]--

local function GetFormattedTime(s)
	local mmSSFormat = OmniCC:InMMSSFormat()

	if s >= 86400 then
		return format("%dd", floor(s/86400 + 0.5)), mod(s, 86400)
	elseif s >= 3600 then
		return format("%dh", floor(s/3600 + 0.5)), mod(s, 3600)
	elseif s >= 180 or (not mmSSFormat and s >= 60.5) then
		return format("%dm", floor(s/60 + 0.5)), mod(s, 60)
	elseif mmSSFormat and s >= 60.5 then
		return format("%d:%02d", floor(s/60), mod(s, 60)), s - floor(s)
	end
	return floor(s + 0.5), s - floor(s)
end

local function GetFormattedFont(s)
	local index
	if s >= 3600 then
		index = "vlong"
	elseif s >= 60.5 then
		index = "long"
	elseif s >= 5.5 then
		index = "med"
	end
	local sets = OmniCC.sets[index or "short"]
	local font, size = OmniCC:GetFont()

	return font, size * (sets.s or 1), (sets.r or 1), (sets.g or 1), (sets.b or 1)
end

local function Timer_OnUpdate(self, elapsed)
	local icon = self.icon
	if self.toNextUpdate <= 0 or not icon:IsVisible() then
		--check and see if the frame we're on is still visible
		if(not icon:IsVisible()) then
			OmniCC:StopTimer(self)
			return
		end
	
		--icon check for bufs
		local texture = icon:GetTexture()
		if texture ~= self.texture then
			OmniCC:StopTimer(self)
			return
		end
		
		--update text
		local remain = self.duration - (GetTime() - self.start)
		if floor(remain + 0.5) > 0 then
			local time, toNextUpdate = GetFormattedTime(remain)
			local font, size, r, g, b = GetFormattedFont(remain)
			local scale = min(self:GetWidth() / ICON_SCALE, 1)

			--hide the timer if text is too small to see
			if (size * scale) >= 8 then
				self.text:SetFont(font, size * scale, "OUTLINE")
				self.text:SetText(time)
				self.text:SetTextColor(r, g, b)
			else
				OmniCC:StopTimer(self)
				return
			end
			self.toNextUpdate = toNextUpdate
		--finished cooldown, show pulse
		else
			OmniCC:StopTimer(self)
			if OmniCC:ShowingPulse() then
				OmniCC:StartPulse(self)
			end
		end
	else
		self.toNextUpdate = self.toNextUpdate - elapsed
	end
end

local function Timer_Create(parent, cooldown, icon)
	local timer = CreateFrame("Frame", nil, parent)
	timer:SetFrameLevel(parent:GetFrameLevel() + 3)
	timer:SetToplevel(true)
	timer:Hide()

	timer:SetAllPoints(parent)
	timer:SetScript("OnUpdate", Timer_OnUpdate)

	timer.icon = icon
	timer.text = timer:CreateFontString(nil, "OVERLAY")
	timer.text:SetPoint("CENTER", timer, "CENTER", 0, 1)

	parent.timer = timer

	return timer
end

local function Cooldown_OnHide(self)
	OmniCC:StopTimer(self:GetParent().timer)
end

function OmniCC:StartTimer(cooldown, start, duration)
	local parent = cooldown:GetParent()
	if parent then
		local icon = parent.icon
		local name = parent:GetName()
		if(not(icon) and name) then
			icon = getglobal(name .. "Icon") or getglobal(name .. "IconTexture")
		end

		if icon then
			local timer = parent.timer or Timer_Create(parent, cooldown, icon)
			timer.start = start
			timer.duration = duration
			timer.toNextUpdate = 0
			timer.texture = icon:GetTexture()
			active[timer] = true
			timer:Show()
			cooldown:SetScript("OnHide", Cooldown_OnHide)
		end
	end
end

function OmniCC:StopTimer(timer)
	if timer then
		active[timer] = nil
		timer:Hide()
	end
end

function OmniCC:UpdateTimer(timer)
	timer.toNextUpdate = 0
end

hooksecurefunc("CooldownFrame_SetTimer", function(frame, start, duration, enable)
	if not OmniCC:ShowingModel() then
		frame:Hide()
	end

	if start > 0 and duration > OmniCC:GetMinimumDuration() and enable == 1 then
		if OmniCC:UsingBlacklist() then
			local frameName = frame:GetName()
			if(frameName) then
				for _, name in pairs(blackList) do
					if frameName:match(name) then return end
				end
			end
		end
		OmniCC:StartTimer(frame, start, duration)
	else
		local timer = frame:GetParent().timer
		if timer then
			OmniCC:StopTimer(timer)
		end
	end
end)


--[[  Pulse Code ]]--

local function Pulse_Create(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetToplevel(true)
	frame:SetAllPoints(parent)

	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER", frame, "CENTER")
	icon:SetBlendMode("ADD")
	icon:SetHeight(frame:GetHeight())
	icon:SetWidth(frame:GetWidth())
	frame.icon = icon

	parent.pulse = frame

	return frame
end

function OmniCC:StartPulse(cooldown)
	local parent = cooldown:GetParent()

	if parent and parent:IsVisible() then
		local pulse = parent.pulse or Pulse_Create(parent)
		pulse.scale = 1
		pulse.icon:SetTexture(cooldown.icon:GetTexture())
		pulse:Show()
		activePulses[pulse] = true

		self:Show()
	end
end

function OmniCC:UpdatePulse(pulse)
	if pulse.scale >= 2 then
		pulse.dec = 1
	end

	if pulse.dec then
		pulse.scale = pulse.scale - pulse.scale * 0.09
	else
		pulse.scale = pulse.scale + pulse.scale * 0.09
	end

	if pulse.scale <= 1 then
		activePulses[pulse] = nil

		pulse:Hide()
		pulse.dec = nil
	else
		pulse.icon:SetHeight(pulse:GetHeight() * pulse.scale)
		pulse.icon:SetWidth(pulse:GetWidth() * pulse.scale)
	end
end


--[[ Slash Commands ]]--

local function PrintCommands()
	local cmdStr = " - |cffffd700%s|r: %s"
	msg(L.Commands, true)
	msg(format(cmdStr, "size <size>", L.SetSizeDesc))
	msg(format(cmdStr, "font <font>", L.SetFontDesc))
	msg(format(cmdStr, "color <dur> <r> <g> <b>", L.SetColorDesc))
	msg(format(cmdStr, "scale <dur> <scale>", L.SetScaleDesc))
	msg(format(cmdStr, "min <time>", L.SetMinDurDesc))
	msg(format(cmdStr, "model", L.ToggleModelDesc))
	msg(format(cmdStr, "pulse", L.TogglePulseDesc))
	msg(format(cmdStr, "mmss", L.ToggleMMSSDesc))
	msg(format(cmdStr, "blacklist", L.ToggleBlacklistDesc))
	msg(format(cmdStr, "reset", L.ResetDesc))
end

SlashCmdList["OmniCCCOMMAND"] = function(message)
	if not message or message == "" or message:lower() == "help" or message == "?" then
		PrintCommands();
	else
		local args = {strsplit(" ", message:lower())}
		local cmd = args[1]

		if cmd == "font" then
			OmniCC:SetFont(args[2])
			msg(format(L.SetFont, (OmniCC:GetFont())), true)
		elseif cmd == "size" then
			OmniCC:SetFontSize(tonumber(args[2]))
			msg(format(L.SetFontSize, select(2, OmniCC:GetFont())), true)
		elseif cmd == "min" then
			OmniCC:SetMinimumDuration(tonumber(args[2]))
			msg(format(L.SetMinDur, OmniCC:GetMinimumDuration(), true))
		elseif cmd == "model" then
			OmniCC:ToggleModel()
			if OmniCC:ShowingModel() then
				msg(L.ModelsEnabled, true)
			else
				msg(L.ModelsDisabled, true)
			end
		elseif cmd == "pulse" then
			OmniCC:TogglePulse()
			if OmniCC:ShowingPulse() then
				msg(L.PulseEnabled, true)
			else
				msg(L.PulseDisabled, true)
			end
		elseif cmd == "mmss" then
			OmniCC:ToggleMMSS()
			if OmniCC:InMMSSFormat() then
				msg(L.MMSSEnabled, true)
			else
				msg(L.MMSSDisabled, true)
			end
		elseif cmd == "blacklist" then
			OmniCC:ToggleBlacklist()
			if OmniCC:UsingBlacklist() then
				msg(L.BlacklistEnabled, true)
			else
				msg(L.BlacklistDisabled, true)
			end
		elseif cmd == "color" then
			OmniCC:SetFontFormat(args[2], tonumber(args[3]), tonumber(args[4]), tonumber(args[5]))
		elseif cmd == "scale" then
			OmniCC:SetFontFormat(args[2], nil, nil, nil, tonumber(args[3]))
		elseif cmd == "reset" then
			OmniCC:Reset()
			msg(L.Reset, true)
		else
			msg(format(L.InvalidCommand, cmd), true)
		end
	end
end
SLASH_OmniCCCOMMAND1 = "/omnicc"