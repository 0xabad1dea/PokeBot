local Settings = {}

local Textbox = require "action.textbox"

local Memory = require "util.memory"
local Menu = require "util.menu"

local yellow = YELLOW

local settings_menu
if yellow then
	settings_menu = 93
else
	settings_menu = 94
end

local desired = {}
if yellow then
	desired.text_speed = 1
	desired.battle_animation = 128
	desired.battle_style = 64
else
	desired.text_speed = 1
	desired.battle_animation = 10
	-- desired.battle_style =
end

local function isEnabled(name)
	if yellow then
		local matching = {
			text_speed = 0xF,
			battle_animation = 128,
			battle_style = 64
		}
		local settingMask = Memory.value("setting", "yellow_bitmask", true)
		return bit.band(settingMask, matching[name]) == desired[name]
	else
		return Memory.value("setting", name) == desired[name]
	end
end

-- PUBLIC

function Settings.set(...)
	for i,name in ipairs(arg) do
		if not isEnabled(name) then
			if Menu.open(settings_menu, 1) then
				Menu.setOption(name, desired[name])
			end
			return false
		end
	end
	return Menu.cancel(settings_menu)
end

function Settings.startNewAdventure()
	local startMenu, withBattleStyle
	if yellow then
		startMenu = Memory.raw(0x0F95) == 0
		withBattleStyle = "battle_style"
	else
		startMenu = Memory.value("player", "name") ~= 0
	end
	if startMenu and Menu.getCol() ~= 0 then
		if Settings.set("text_speed", "battle_animation", withBattleStyle) then
			Menu.select(0)
		end
	elseif math.random(0, START_WAIT) == 0 then
		Input.press("Start")
	end
end

function Settings.choosePlayerNames()
	local name
	if Memory.value("player", "name2") == 80 then
		name = "E"
	else
		name = "B"
	end
	Textbox.name(name, true)
end

function Settings.pollForResponse()
	local response = Bridge.process()
	if response then
		Bridge.polling = false
		Textbox.setName(tonumber(response))
	end
end

return Settings
