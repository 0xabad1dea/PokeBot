local utils = {}

local memory = require "util.memory"

-- GENERAL

function utils.dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2))
end

function utils.each(table, func)
	for key,val in pairs(table) do
		func(key.." = "..tostring(val)..",")
	end
end

function utils.eachi(table, func)
	for idx,val in ipairs(table) do
		if val then
			func(idx.." "..val)
		else
			func(idx)
		end
	end
end

function utils.match(needle, haystack)
	for i,val in ipairs(haystack) do
		if needle == val then
			return true
		end
	end
	return false
end

function utils.key(needle, haystack)
	for key,val in pairs(haystack) do
		if needle == val then
			return key
		end
	end
	return nil
end

-- GAME

function utils.canPotionWith(potion, forDamage, curr_hp, max_hp)
	local potion_hp
	if potion == "full_restore" then
		potion_hp = 9001
	elseif potion == "super_potion" then
		potion_hp = 50
	else
		potion_hp = 20
	end
	return math.min(curr_hp + potion_hp, max_hp) >= forDamage - 1
end

function utils.ingame()
	return memory.raw(0x020E) > 0
end

function utils.onPokemonSelect(battleMenu)
	return battleMenu == 8 or battleMenu == 48 or battleMenu == 184 or battleMenu == 224
end

-- TIME

function utils.igt()
	local secs = memory.raw(0x1A44)
	local mins = memory.raw(0x1A43)
	local hours = memory.raw(0x1A41)
	return secs + mins * 60 + hours * 3600
end

local function clockSegment(unit)
	if unit < 10 then
		unit = "0"..unit
	end
	return unit
end

function utils.timeSince(prevTime)
	local currTime = utils.igt()
	local diff = currTime - prevTime
	local timeString
	if diff > 0 then
		local secs = diff % 60
		local mins = math.floor(diff / 60)
		timeString = clockSegment(mins)..":"..clockSegment(secs)
	end
	return currTime, timeString
end

function utils.elapsedTime()
	local secs = memory.raw(0x1A44)
	if secs < 10 then
		secs = "0"..secs
	end
	local mins = memory.raw(0x1A43)
	if mins < 10 then
		mins = "0"..mins
	end
	return memory.raw(0x1A41)..":"..mins..":"..secs
end

function utils.frames()
	local totalFrames = memory.raw(0x1A41) * 60
	totalFrames = (totalFrames + memory.raw(0x1A43)) * 60
	totalFrames = (totalFrames + memory.raw(0x1A44)) * 60
	return totalFrames + memory.raw(0x1A45)
end

return utils
