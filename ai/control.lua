local Control = {}

local Battle
local Combat = require "ai.combat"
local Strategies

local Bridge = require "util.bridge"
local Memory = require "util.memory"
local Paint = require "util.paint"
local Utils = require "util.utils"

local Data = require "data.data"
local Inventory = require "storage.inventory"
local Pokemon = require "storage.pokemon"

local potionInBattle = true
local encounters = 0

local canDie, shouldFight, minExp
local shouldCatch, attackIdx
local extraEncounter, maxEncounters
local battleYolo
local encountersSection

local yellow = YELLOW

Control.areaName = "Unknown"
Control.getMoonExp = true
Control.yolo = false

local function withinOneKill(forExp)
	return Pokemon.getExp() + 80 > forExp
end

local controlFunctions = {

	a = function(data)
		Control.areaName = data.a
		return true
	end,

	potion = function(data)
		if data.b ~= nil then
			Control.battlePotion(data.b)
		end
		battleYolo = data.yolo
	end,

	encounters = function(data)
		if RESET_FOR_TIME then
			maxEncounters = data.limit
			extraEncounter = data.extra
		end
	end,

	pp = function(data)
		Combat.factorPP(data.on)
	end,

	thrash = function(data)
		Combat.setDisableThrash(data.disable)
	end,

	disableCatch = function()
		shouldCatch = nil
		shouldFight = nil
	end,

	-- RED

	viridianExp = function()
		minExp = 210
		shouldFight = {{name="rattata",levels={2,3}}, {name="pidgey",levels={2}}}
	end,

	viridianBackupExp = function()
		minExp = 210
		shouldFight = {{name="rattata",levels={2,3}}, {name="pidgey",levels={2,3}}}
	end,

	nidoranBackupExp = function()
		minExp = 210
		shouldFight = {{name="rattata"}, {name="pidgey"}, {name="nidoran"}, {name="nidoranf",levels={2}}}
	end,

	trackEncounters = function(data)
		local area = data.area
		if area then
			encountersSection = "encounters_"..area
			Data.run[encountersSection] = 0
		else
			encountersSection = nil
		end
	end,

	startMtMoon = function()
		Control.canDie(false)
		Control.getMoonExp = not yellow
	end,

	moon1Exp = function()
		if Control.getMoonExp then
			minExp = 2704
			shouldFight = {{name="zubat",levels={9,10,11,12},exp9=69}}
			oneHits = true
		end
	end,

	moon2Exp = function()
		if Control.getMoonExp then
			minExp = 3011
			shouldFight = {{name="zubat",exp9=69}, {name="paras"}}
			oneHits = not withinOneKill(minExp)
		end
	end,

	moon3Exp = function()
		if Control.getMoonExp then
			local expTotal = Pokemon.getExp()
			minExp = 3798
			shouldFight = {{name="zubat",exp9=69}, {name="paras"}}
			oneHits = not withinOneKill(minExp)
		end
	end,

	catchNidoran = function()
		shouldCatch = {{name="nidoran",levels={3,4}}, {name="spearow"}}
	end,

	catchFlier = function()
		if Pokemon.inParty("pidgey", "spearow") then
			shouldCatch = {{name="sandshrew"}}
		else
			shouldCatch = {{name="spearow",alt="pidgey",hp=15}, {name="pidgey",alt="spearow",hp=15}}
		end
	end,

	catchParas = function()
		shouldCatch = {{name="paras",hp=16}}
	end,

	catchOddish = function()
		shouldCatch = {{name="oddish",alt="paras",hp=26}}
	end,

	-- YELLOW

	catchNidoranYellow = function()
		shouldCatch = {{name="nidoran",levels={6}}}
	end,

	moonExpYellow = function()
		minExp = 2704 --TODO
		shouldFight = {{name="geodude"}, {name="clefairy",levels={12,13}}}
		oneHits = true
	end,

	catchCutterYellow = function()
		shouldCatch = {{name="sandshrew"}, {name="paras",levels={9,10,11,12}}}
	end,

}

-- COMBAT

function Control.battlePotion(enable)
	potionInBattle = enable
end

function Control.canDie(enabled)
	if enabled == nil then
		return canDie
	end
	canDie = enabled
end

function Control.shouldFight()
	if not shouldFight then
		return false
	end
	local expRemaining = minExp - Pokemon.getExp()
	if expRemaining > 0 then
		local oid = Memory.value("battle", "opponent_id")
		local opponentLevel = Memory.value("battle", "opponent_level")
		for i,encounter in ipairs(shouldFight) do
			if oid == Pokemon.getID(encounter.name) and (not encounter.levels or Utils.match(opponentLevel, encounter.levels)) then
				if oneHits then
					local move = Combat.bestMove()
					if move and move.maxDamage * 0.925 < Memory.double("battle", "opponent_hp") then
						return false
					end
				end
				if expRemaining < 100 then
					local getExp = encounter["exp"..opponentLevel]
					if getExp and getExp < expRemaining then
						return false
					end
				end
				return true
			end
		end
	end
end

function Control.canCatch(partySize)
	if not partySize then
		partySize = Memory.value("player", "party_size")
	end
	local pokeballs = Inventory.count("pokeball")
	local minimumCount = (yellow and 3 or 4) - partySize
	if pokeballs < minimumCount then
		if yellow and Pokemon.inParty("nidoran", "nidorino", "nidoking") and Pokemon.inParty("pidgey", "spearow") then
			return false
		end
		Strategies.reset("pokeballs", "Not enough PokeBalls", pokeballs)
		return false
	end
	return true
end

function Control.shouldCatch(partySize)
	if maxEncounters and encounters > maxEncounters then
		local extraCount = extraEncounter and Pokemon.inParty(extraEncounter)
		if not extraCount or encounters > maxEncounters + 1 then
			Strategies.reset("encounters", "Too many encounters", encounters)
			return false
		end
	end
	if not shouldCatch then
		return false
	end
	if yellow and not Inventory.contains("pokeball") then
		return false
	end
	if not partySize then
		partySize = Memory.value("player", "party_size")
	end
	if partySize == 4 then
		shouldCatch = nil
		return false
	end
	if not Control.canCatch(partySize) then
		return true
	end
	local oid = Memory.value("battle", "opponent_id")
	local opponentLevel = Memory.value("battle", "opponent_level")
	for i,poke in ipairs(shouldCatch) do
		if oid == Pokemon.getID(poke.name) and not Pokemon.inParty(poke.name, poke.alt) then
			if not poke.levels or Utils.match(opponentLevel, poke.levels) then
				local penultimate = poke.hp and Memory.double("battle", "opponent_hp") > poke.hp
				if penultimate then
					penultimate = Combat.nonKill()
				end
				if penultimate then
					require("action.battle").fight(penultimate.midx)
				else
					Inventory.use("pokeball", nil, true)
				end
				return true
			end
		end
	end
end

-- Items

function Control.canRecover()
	return potionInBattle and (not battleYolo or not Control.yolo) and Pokemon.mainFighter()
end

function Control.set(data)
	local controlFunction = controlFunctions[data.c]
	if controlFunction then
		controlFunction(data)
	else
		p("INVALID CONTROL", data.c, GAME_NAME)
	end
end

function Control.setYolo(enabled)
	Control.yolo = enabled
end

function Control.setPotion(enabled)
	potionInBattle = enabled
end

function Control.encounters()
	return encounters
end

function Control.encounter(battleState)
	if battleState > 0 then
		local wildBattle = battleState == 1
		local isCritical
		local battleMenu = Memory.value("battle", "menu")
		if battleMenu == 94 then
			isCritical = false
			Control.missed = false
		elseif Memory.double("battle", "our_hp") == 0 then
			if Memory.value("battle", "critical") == 1 then
				isCritical = true
			end
		elseif not Control.missed then
			local turnMarker = Memory.value("battle", "our_turn")
			if turnMarker == 100 or turnMarker == 128 then
				local isMiss = Memory.value("battle", "miss") == 1
				if isMiss then
					if not Control.ignoreMiss and Battle.accurateAttack and Memory.value("battle", "accuracy") == 7 then
						local exclaim = Strategies.deepRun and ";_; " or ""
						Bridge.chat("gen 1 missed "..exclaim.."(1 in 256 chance)")
					end
					Control.missed = true
					Data.increment("misses")
				end
			end
		end
		if isCritical ~= nil and isCritical ~= Control.criticaled then
			Control.criticaled = isCritical
			Data.increment("criticals")
		end
		if wildBattle then
			local opponentAlive = Battle.opponentAlive()
			if not Control.inBattle then
				if opponentAlive then
					Control.killedCatch = false
					Control.inBattle = true
					encounters = encounters + 1
					Paint.wildEncounters(encounters)
					Bridge.encounter()
					if encountersSection then
						Data.increment(encountersSection)

						if Pokemon.isOpponent("zubat") then
							local zubatCount = Data.increment("encounters_zubats")
							Data.run.encounters_zubats = zubatCount
							if STREAMING_MODE then
								Bridge.chat(Utils.multiplyString("NightBat", zubatCount))
							end
						end
					end
				end
			else
				if not opponentAlive and shouldCatch and not Control.killedCatch then
					local gottaCatchEm = {"pidgey", "spearow", "paras", "oddish"}
					local opponent = Battle.opponent()
					for i,catch in ipairs(gottaCatchEm) do
						if opponent == catch then
							if not Pokemon.inParty(catch) then
								local criticaled = Memory.value("battle", "critical") == 1
								Bridge.chat("accidentally killed "..Utils.capitalize(catch).." with a "..(criticaled and "critical" or "high damage range").." :(")
								Control.killedCatch = true
							end
							break
						end
					end
				end
			end
		end
	elseif Control.inBattle then
		Control.inBattle = false
		Control.escaped = Memory.value("battle", "battle_turns") == 0
	end
end

function Control.reset()
	canDie = false
	oneHits = false
	shouldCatch = nil
	shouldFight = nil
	extraEncounter = nil
	potionInBattle = true
	encounters = 0
	battleYolo = false
	maxEncounters = nil

	Control.yolo = false
	Control.inBattle = false
	Control.preferredPotion = nil
end

function Control.init()
	Battle = require("action.battle")
	Strategies = require("ai."..GAME_NAME..".strategies")
end

return Control
