--[[----------------------------------------------------------------------------
Wiirdle v1.0.0

Copyright (C) 2022  HTV04

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
------------------------------------------------------------------------------]]

-- Libraries
local date, timer, binser

-- Game setup variables
local curDate, firstDate, day, words, solutions, solution, nextDate, save

-- Floater variables
local floaterWords, floaterWordsLen, floaters

-- Wiimote variables
local wiimote, wiimotePressed, pointer

-- Rumble variables and functions
local rumbleTimer, rumbleStop, rumble

-- Fonts
local logoFont, textFont, tileFont

-- Font functions
local shadowText

-- Stats menu
local statsMenu

-- Keyboard variables
local keys, keyCol, keyRow, keySize, keyFuncs

-- Tile drawing functions
local tileColorFuncs, drawTile, drawAttemptedTile

-- Textures
local roundedBox

function love.load()
	local function packToStr(table)
		local str = ""

		for _, v in ipairs(table) do
			str = str .. v
		end

		return str
	end

	local function hideStatsMenu() -- For stats menu timers
		statsMenu.shown = false
	end

	local function newFloater()
		table.insert(floaters, {
			x = 640,
			y = math.random(0, 480),

			text = floaterWords[love.math.random(floaterWordsLen)],
			speed = love.math.random(10, 20)
		})

		timer.after(3, newFloater)
	end

	local letterPos = {
		[" "] = 0,
		["A"] = 16,
		["B"] = 19,
		["C"] = 17,
		["D"] = 17,
		["E"] = 19,
		["F"] = 19,
		["G"] = 16,
		["H"] = 17,
		["I"] = 24,
		["J"] = 22,
		["K"] = 17,
		["L"] = 19,
		["M"] = 16,
		["N"] = 17,
		["O"] = 16,
		["P"] = 19,
		["Q"] = 16,
		["R"] = 18,
		["S"] = 18,
		["T"] = 16,
		["U"] = 17,
		["V"] = 16,
		["W"] = 13,
		["X"] = 16,
		["Y"] = 16,
		["Z"] = 17
	}

	love.graphics.setBackgroundColor(24, 24, 24)

	date = require("lib.date")
	timer = require("lib.timer")
	binser = require("lib.binser")

	curDate = date()
	firstDate = date(2022, 4, 2)
	day = math.floor(date.diff(curDate, firstDate):spandays())
	words = require("data.words")
	solutions = require("data.solutions")
	solution = solutions[day]
	nextDate = date(curDate:getyear(), curDate:getmonth(), curDate:getday() + 1)
	if love.filesystem.exists("save.bin") then
		save = binser.deserializeN(love.filesystem.read("save.bin"))
	else
		save = {
			-- Game setup variables
			day = 0, -- Forces day update, which will populate the save table

			-- Stats variables
			played = 0,
			won = 0,
			streak = 0,
			maxStreak = 0,
			guesses = {0, 0, 0, 0, 0, 0},

			-- Settings
			rumble = true
		}
	end

	floaterWords = {}
	for k, _ in pairs(words) do
		table.insert(floaterWords, k)
	end
	floaterWordsLen = #floaterWords
	floaters = {}

	wiimote = love.wiimote.getWiimotes()[1]
	pointer = love.graphics.newTexture("assets/pointer.png")

	function rumbleStop()
		wiimote:setRumble(false)
	end
	function rumble(duration)
		if not save.rumble then return end

		if rumbleTimer then timer.cancel(rumbleTimer) end

		if not duration then
			wiimote:setRumble(true)
		elseif duration > 0 then
			wiimote:setRumble(true)

			rumbleTimer = timer.after(duration, rumbleStop)
		else
			wiimote:setRumble(false)
		end
	end

	logoFont = love.graphics.newFont(25)
	textFont = love.graphics.newFont(12)
	tileFont = love.graphics.newFont(30)

	function shadowText(text, x, y, r, sx, sy, ox, oy)
		local r = r or 0
		local sx, sy = sx or 1, sy or 1
		local ox, oy  = ox or 0, oy or 0

		love.graphics.setColor(0, 0, 0)
		love.graphics.print(text, x + 1, y + 1, r, sx, sy, ox, oy)
		love.graphics.setColor(255, 255, 255)
		love.graphics.print(text, x, y, r, sx, sy, ox, oy)
	end

	statsMenu = {
		-- Variables
		shown = false,
		fadeValue = 0,
		position = -480,
		shareScreen = false,

		-- Textures
		fade = love.graphics.newTexture("assets/stats/fade.png"),
		box = love.graphics.newTexture("assets/stats/box.png"),

		-- Functions
		show = function()
			statsMenu.shown = true

			if statsMenu.fadeTimer then timer.cancel(statsMenu.fadeTimer) end
			if statsMenu.boxTimer then timer.cancel(statsMenu.boxTimer) end

			timer.tween(0.5, statsMenu, {fadeValue = 64})
			timer.tween(0.5, statsMenu, {position = 0}, "out-cubic")
		end,
		hide = function()
			if statsMenu.fadeTimer then timer.cancel(statsMenu.fadeTimer) end
			if statsMenu.boxTimer then timer.cancel(statsMenu.boxTimer) end

			timer.tween(0.25, statsMenu, {fadeValue = 0})
			timer.tween(0.25, statsMenu, {position = -480}, "in-cubic", hideStatsMenu)
		end
	}

	-- QWERTY layout, may be customizable in the future
	keys = {
		{"q", "w", "e", "r", "t", "y", "u", "i", "o", "p"},
		{"a", "s", "d", "f", "g", "h", "j", "k", "l"},
		{"enter", "z", "x", "c", "v", "b", "n", "m", "< (B)"}
	}
	keyCol, keyRow = 0, 0
	keySize = {factor = 1} -- Will also have "timer" value
	keyFuncs = {
		-- Enter attempt
		["enter"] = function()
			local attempt = save.attempts[save.curAttempt]
			local curAttempt = save.curAttempt
			local keyStates = save.keyStates

			if save.curPosition < 6 or not words[packToStr(attempt)] then return end

			local attemptState = save.attemptStates[curAttempt]

			local letterCounts = {} -- Store number of times letter appears
			local correctCount = 0 -- Number of correct letters

			-- Pass 1: Correct letters
			for i = 1, 5 do
				local letter  = attempt[i]
				local key = string.lower(letter)

				if not letterCounts[letter] then letterCounts[letter] = 0 end

				if letter == string.sub(solution, i, i) then -- Letter is in the correct position
					attemptState[i] = 3
					if keyStates[key] < 3 then keyStates[key] = 3 end

					letterCounts[letter] = letterCounts[letter] + 1
					correctCount = correctCount + 1
				end
			end

			-- Pass 2: Detemine win and check wrong letters
			if correctCount == 5 then -- Won :)
				save.completed = true

				save.played = save.played + 1
				save.won = save.won + 1
				save.streak = save.streak + 1
				save.maxStreak = math.max(save.streak, save.maxStreak)

				save.guesses[save.curAttempt] = save.guesses[save.curAttempt] + 1

				statsMenu.show()
			else
				for i = 1, 5 do
					if attemptState[i] == 0 then -- Only check if the letter state is uninitialized
						local letter  = attempt[i]
						local _, appearances = string.gsub(solution, letter, "")
						local key = string.lower(letter)

						if letterCounts[letter] < appearances then -- Letter is in the wrong place, false if appearances == 0
							attemptState[i] = 2
							if keyStates[key] < 2 then keyStates[key] = 2 end

							letterCounts[letter] = letterCounts[letter] + 1
						else -- Letter is not in the solution
							attemptState[i] = 1
							if keyStates[key] < 1 then keyStates[key] = 1 end
						end
					end
				end

				if curAttempt == 6 then -- Lost :(
					save.completed = true

					save.played = save.played + 1
					save.streak = 0

					statsMenu.show()
				end
			end

			-- Advance to next attempt
			save.curAttempt = curAttempt + 1
			save.curPosition = 1
		end,

		-- Clear last letter (backspace)
		["< (B)"] = function()
			local curPosition = save.curPosition

			if curPosition > 1 then save.curPosition = curPosition - 1 end

			save.attempts[save.curAttempt][curPosition - 1] = " "
		end
	}

	tileColorFuncs = {
		function(modifier) -- Wrong
			local modifier = modifier or 0

			love.graphics.setColor(58 + modifier, 58 + modifier, 60 + modifier) -- Gray
		end,
		function(modifier) -- Letter in wrong place
			local modifier = modifier or 0

			love.graphics.setColor(181 + modifier, 159 + modifier, 59 + modifier) -- Yellow
		end,
		function(modifier) -- Correct
			local modifier = modifier or 0

			love.graphics.setColor(83 + modifier, 141 + modifier, 78 + modifier) -- Green
		end,

		[0] = function(modifier) -- Uninitialized or other
			local modifier = modifier or 0

			love.graphics.setColor(129 + modifier, 131 + modifier, 132 + modifier) -- Light gray
		end
	}
	function drawTile(letter, x, y)
		love.graphics.rectangle(false, x, y, 55, 55)
		shadowText(letter, x + letterPos[letter], y + 38)
	end
	function drawAttemptedTile(state, letter, x, y)
		tileColorFuncs[state]()

		love.graphics.rectangle(true, x, y, 55, 55)

		love.graphics.setColor(255, 255, 255)
		shadowText(letter, x + letterPos[letter], y + 38)
	end

	roundedBox = love.graphics.newTexture("assets/rounded-box.png")

	newFloater() -- Inits floater cycle

	if save.completed then statsMenu.show() end
end

function love.homepressed()
	if statsMenu.shown then
		if statsMenu.shareScreen then
			statsMenu.shareScreen = false

			return true -- Don't exit
		end

		love.filesystem.write("save.bin", binser.serialize(save))

		return false -- Safe to exit
	else
		statsMenu.show()

		return true -- Don't exit
	end
end

function love.update(dt)
	local wiimoteX, wiimoteY = wiimote:getPosition()
	local oldKeyCol, oldKeyRow = keyCol, keyRow

	timer.update(dt)

	curDate = date()
	day = math.floor(date.diff(curDate, firstDate):spandays())

	-- Update save data for day
	if save.day ~= day then
		solution = solutions[day]
		nextDate = date(curDate:getyear(), curDate:getmonth(), curDate:getday() + 1)

		-- Game setup variables
		save.day = day
		save.completed = false

		-- Gameplay variables
		save.attempts = {
			{" ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " "}
		}
		-- 1: wrong, 2: letter in wrong place, 3: correct
		-- 0 is used as a placeholder until the attempt is made
		save.attemptStates = {
			{0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0}
		}
		save.curAttempt = 1
		save.curPosition = 1
		save.keyStates = {
			["a"] = 0,
			["b"] = 0,
			["c"] = 0,
			["d"] = 0,
			["e"] = 0,
			["f"] = 0,
			["g"] = 0,
			["h"] = 0,
			["i"] = 0,
			["j"] = 0,
			["k"] = 0,
			["l"] = 0,
			["m"] = 0,
			["n"] = 0,
			["o"] = 0,
			["p"] = 0,
			["q"] = 0,
			["r"] = 0,
			["s"] = 0,
			["t"] = 0,
			["u"] = 0,
			["v"] = 0,
			["w"] = 0,
			["x"] = 0,
			["y"] = 0,
			["z"] = 0,

			["enter"] = 0,
			["< (B)"] = 0
		}

		if statsMenu.shown then statsMenu.hide() end
	end

	-- Floater cleanup
	for i = #floaters, 1, -1 do
		local floater = floaters[i]

		floater.x = floater.x - floater.speed * dt

		if floater.x <= -110 then table.remove(floaters, i) end
	end

	keyCol, keyRow = 0, 0 -- Reset highlighted key

	if statsMenu.shown then
		if statsMenu.shareScreen then
			if not wiimotePressed and wiimote:isDown("b") then
				wiimotePressed = true

				statsMenu.shareScreen = false
			elseif not wiimote:isDown("b") then
				wiimotePressed = false
			end

			return
		end

		if not wiimotePressed then
			if save.completed and wiimote:isDown("a") then
				wiimotePressed = true

				statsMenu.shareScreen = true
			elseif wiimote:isDown("b") then
				wiimotePressed = true

				statsMenu.hide()
			elseif wiimote:isDown("1") then
				wiimotePressed = true

				save.rumble = not save.rumble

				rumble(0.1)
			end
		elseif not wiimote:isDown("a") and not wiimote:isDown("b") and not wiimote:isDown("1") then
			wiimotePressed = false
		end

		return
	end

	-- Process keyboard keys
	for i, row in ipairs(keys) do
		local start = math.floor((641 - 53 * (#row + 2)) / 2)

		for j, key in ipairs(row) do
			local posX, posY = start + j * 53, 330 + i * 37

			if wiimoteX >= posX and wiimoteX <= posX + 48 and wiimoteY >= posY and wiimoteY <= posY + 32 then
				keyCol, keyRow = i, j -- Set highlighted key

				-- Only redo tween if the key has changed
				if keyCol ~= oldKeyCol or keyRow ~= oldKeyRow then
					rumble(0.1)

					if keySize.timer then timer.cancel(keySize.timer) end
					keySize.factor = 1
					keySize.timer = timer.tween(0.1, keySize, {factor = 1.25})
				end

				if not save.completed and not wiimotePressed and wiimote:isDown("a") then
					wiimotePressed = true

					if keySize.timer then timer.cancel(keySize.timer) end
					keySize.factor = 1
					keySize.timer = timer.tween(0.1, keySize, {factor = 1.25})

					if keyFuncs[key] then
						keyFuncs[key]()
					else
						if save.curPosition <= 5 then
							save.attempts[save.curAttempt][save.curPosition] = string.upper(key)

							save.curPosition = save.curPosition + 1
						end
					end
				end
			end
		end

		if not save.completed and not wiimotePressed and wiimote:isDown("b") then
			wiimotePressed = true

			keyFuncs["< (B)"]()
		elseif not wiimote:isDown("a") and not wiimote:isDown("b") then
			wiimotePressed = false
		end

		if keyCol == 0 then -- Assume keyRow == 0
			rumble(0)
		end
	end
end

function love.draw()
	local attempts, attemptStates = save.attempts, save.attemptStates
	local keyColor

	if statsMenu.shown and statsMenu.shareScreen then
		-- Background
		tileColorFuncs[0](-32)
		love.graphics.draw(statsMenu.fade, 0, 0)
		love.graphics.setColor(255, 255, 255)

		-- Info
		love.graphics.setFont(logoFont)
		shadowText("Wiirdle #" .. save.day, 245, 35)
		shadowText("https://github.com/HTV04/wiirdle", 115, 455)
		love.graphics.setFont(textFont)
		shadowText("Press B to exit", 550, 475)

		-- Tiles
		for i = 1, 6 do
			for j = 1, 5 do
				tileColorFuncs[attemptStates[i][j]]()

				love.graphics.rectangle(true, 112 + j * 60, i * 60, 55, 55)
			end
		end
		love.graphics.setColor(255, 255, 255)

		-- Pointer
		love.graphics.draw(pointer, wiimote:getX(), wiimote:getY(), wiimote:getAngle(), 1, 1, 48, 48)

		return
	end

	local keyStates = save.keyStates

	-- Floaters
	love.graphics.setColor(0, 0, 0)
	love.graphics.setFont(tileFont)
	for _, v in ipairs(floaters) do
		love.graphics.print(v.text, v.x, v.y)
	end
	love.graphics.setColor(255, 255, 255)

	-- Title, version, and instructions
	love.graphics.setFont(logoFont)
	love.graphics.print("WiiRDLE", 30, 27)
	love.graphics.setFont(textFont)
	love.graphics.print("v1.0.0", 92, 43)

	love.graphics.print("Press HOME to view stats", 10, 82)
	love.graphics.print("and change settings", 10, 95)

	-- Credits
	love.graphics.print(tostring("==Credits=="), 480, 17)

	love.graphics.print("By HTV04", 480, 43)
	love.graphics.print("Powered by WiiLÖVE", 480, 56)

	love.graphics.print("\"Wordle\" by Josh Wardle", 480, 82)
	love.graphics.print("and The New York Times", 480, 95)

	-- Tiles
	love.graphics.setFont(tileFont)
	for i = 1, 6 do
		if i >= save.curAttempt then
			for j = 1, 5 do
				drawTile(attempts[i][j], 112 + j * 60, -55 + i * 60)
			end
		else
			for j = 1, 5 do
				drawAttemptedTile(attemptStates[i][j], attempts[i][j], 112 + j * 60, -55 + i * 60)
			end
		end
	end

	-- Keyboard keys
	love.graphics.setFont(textFont)
	for i, row in ipairs(keys) do
		local start = math.floor((641 - 53 * (#row + 2)) / 2)

		for j, key in ipairs(row) do
			if i ~= keyCol or j ~= keyRow then
				tileColorFuncs[keyStates[key]]()
				love.graphics.draw(roundedBox, start + j * 53, 330 + i * 37)

				shadowText(key, 4 + start + j * 53, 344 + i * 37)
			end
		end
	end

	-- Highlighted keyboard key
	if keyCol ~= 0 then -- Assume keyRow ~= 0
		local row = keys[keyCol]

		local start = math.floor((689 - 53 * (#row + 2)) / 2)
		local key = row[keyRow]

		keyColor = keyStates[key]

		tileColorFuncs[keyColor](24)
		love.graphics.draw(roundedBox, start + keyRow * 53, 346 + keyCol * 37, 0, keySize.factor, keySize.factor, 24, 16)

		shadowText(key, 4 + start + keyRow * 53, 360 + keyCol * 37, 0, keySize.factor, keySize.factor, 24, 16)
	end

	-- Stats menu
	if statsMenu.shown then
		local guesses, maxGuess, maxGuessNum = save.guesses, 1, 0

		local played = save.played

		for i = 2, 6 do
			if guesses[i] > guesses[maxGuess] then
				maxGuess = i
			end
		end
		maxGuessNum = guesses[maxGuess]

		love.graphics.setColor(255, 255, 255, math.floor(statsMenu.fadeValue))
		love.graphics.draw(statsMenu.fade, 0, 0)

		love.graphics.push()
			love.graphics.translate(106, 80 + statsMenu.position)

			tileColorFuncs[0]()
			love.graphics.draw(statsMenu.box, 0, 0)

			shadowText("Statistics", 185, 20)

			love.graphics.setFont(tileFont)
			shadowText(tostring(save.played), 70, 70)
			shadowText(tostring(played ~= 0 and math.floor((save.won / played) * 100) or 0), 143, 70)
			shadowText(tostring(save.streak), 217, 70)
			shadowText(tostring(save.maxStreak), 290, 70)

			love.graphics.setFont(textFont)
			shadowText("Played", 70, 90)
			shadowText("% Won", 143, 90)
			shadowText("Streak", 217, 90)
			shadowText("Max Streak", 290, 90)

			for i = 1, 6 do
				shadowText(tostring(i), 50, 100 + i * 20)

				if maxGuessNum > 0 then
					local guessNum = guesses[i]
					local guessPercent = guessNum / maxGuessNum

					if i == maxGuess then
						tileColorFuncs[3]()
					else
						tileColorFuncs[1]()
					end
					love.graphics.rectangle(true, 60, 91 + i * 20, 15 + 298 * guessPercent, 10)

					love.graphics.print(tostring(guessNum), 78 + 298 * guessPercent, 100 + i * 20)
				else
					tileColorFuncs[1]()
					love.graphics.rectangle(true, 60, 91 + i * 20, 15, 10)

					love.graphics.print("0", 78, 100 + i * 20)
				end
			end

			shadowText("Next Wiirdle:", 50, 250)
			love.graphics.setFont(logoFont)
			shadowText(date.diff(nextDate, curDate):fmt("%H:%M:%S"), 135, 254)

			love.graphics.setFont(textFont)
			shadowText("==Controls==", 50, 274)
			if save.completed then
				shadowText("A: Share    B: Return to game    HOME: Return to loader", 50, 287)
			else
				shadowText("B: Return to game    HOME: Return to loader", 50, 287)
			end
			if save.rumble then
				shadowText("1: Toggle rumble (enabled)", 50, 300)
			else
				shadowText("1: Toggle rumble (disabled)", 50, 300)
			end
		love.graphics.pop()
	end

	-- Pointer
	if keyColor then
		tileColorFuncs[keyColor](64)
	else
		love.graphics.setColor(255, 255, 255)
	end
	love.graphics.draw(pointer, wiimote:getX(), wiimote:getY(), wiimote:getAngle(), 1, 1, 48, 48)
	love.graphics.setColor(255, 255, 255)
end
