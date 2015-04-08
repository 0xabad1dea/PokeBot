local Input = {}

local Bridge = require "util.bridge"
local Memory = require "util.memory"
local Utils = require "util.utils"

local lastSend
local currentButton, remainingFrames, setForFrame
local debug
local bCancel = true

local function bridgeButton(btn)
	if btn ~= lastSend then
		lastSend = btn
		Bridge.input(btn)
	end
end

local function sendButton(button, ab)
	local inputTable = {[button] = true}
	joypad.set(inputTable)
	if debug then
		Utils.drawText(0, 7, button.." "..remainingFrames)
	end
	if ab then
		buttonbutton = "A,B"
	end
	bridgeButton(button)
	setForFrame = button
end

function Input.press(button, frames)
	if setForFrame then
		print("ERR: Reassigning "..setForFrame.." to "..button)
		return
	end
	if frames == nil or frames > 0 then
		if button == currentButton then
			return
		end
		if not frames then
			frames = 1
		end
		currentButton = button
		remainingFrames = frames
	else
		remainingFrames = 0
	end
	bCancel = button ~= "B"
	sendButton(button)
end

function Input.cancel(accept)
	if accept and Memory.value("menu", "shop_current") == 20 then
		Input.press(accept)
	else
		local button
		if bCancel then
			button = "B"
		else
			button = "A"
		end
		remainingFrames = 0
		sendButton(button, true)
		bCancel = not bCancel
	end
end

function Input.escape()
	local inputTable = {Right=true, Down=true}
	joypad.set(inputTable)
	bridgeButton("D,R")
end

function Input.clear()
	currentButton = nil
	remainingFrames = -1
end

function Input.update()
	if currentButton then
		remainingFrames = remainingFrames - 1
		if remainingFrames >= 0 then
			if remainingFrames > 0 then
				sendButton(currentButton)
				return true
			end
		else
			currentButton = nil
		end
	end
	setForFrame = nil
end

function Input.advance()
	if not setForFrame then
		bridgeButton("e")
	end
end

function Input.setDebug(enabled)
	debug = enabled
end

function Input.test(fn, completes)
	while true do
		if not Input.update() then
			if fn() and completes then
				break
			end
		end
		emu.frameadvance()
	end
	if completes then
		print(completes.." complete!")
	end
end

return Input
