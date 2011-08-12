require "helper"
require "bit"

-- 16 keys
keys = {}
keys["1"] = 1
keys["1"] = 1
keys["1"] = 1

	"1", "2", "3",
	"q", "w", "e",
	"a", "s", "d",
	"y", [0]="x" "c",
	"4", "r", "f", "v"
}
input = {}


function love.keypressed(key)
	if key == "escape" then
		love.event.push("q")
	end

	for k, v in pairs(keys) do
		
	end

end


function love.load()
	love.mouse.setVisible(false)

	-- prepare memory
	mem = {}
	local i = 0x200
	for b in io.open("roms/MAZE"):read("*a"):gmatch(".") do
		mem[i] = string.byte(b)
		i = i + 1
	end
	while i < 0x1000 do
		mem[i] = 0
		i = i + 1
	end

	reg = {}
	for i = 0, 15 do
		reg[i] = 0
	end
	reg.I = 0
	reg.C = 0x200
	
	stack = {}

	display = {}
	for i = 0, 64 * 32 - 1 do
		display[i] = 0
	end

end


function love.update(dt)
--	love.timer.sleep((1 - dt) * 1000 / 60) -- doesn't work \:

end


function love.draw()

	local ab = mem[reg.C]
	local cd = mem[reg.C + 1]

	local op = ab * 256 + cd

	local a = math.floor(ab / 16)
	local b = ab % 16
	local c = math.floor(cd / 16)
	local d = cd % 16

	reg.C = reg.C + 2

	if op == 0x00e0 then			-- clear screen
		for i = 0, 64 * 32 - 1 do
			display[i] = 0
		end

	elseif op == 0x00ee then		-- return
		reg.C = stack[#stack]
		stack[#stack] = nil

	elseif a == 1 then				-- jump
		reg.C = b * 256 + cd

	elseif a == 2 then				-- call
		stack[#stack + 1] = reg.C + 2
		reg.C = b * 256 + cd

	elseif a == 3 then				-- skip
		if reg[b] == cd then
			reg.C = reg.C + 2
		end

	elseif a == 4 then				-- skip
		if reg[b] ~= cd then
			reg.C = reg.C + 2
		end

	elseif a == 5 and d == 0 then	-- skip
		if reg[b] == reg[c] then
			reg.C = reg.C + 2
		end

	elseif a == 6 then				-- set
		reg[b] = cd

	elseif a == 7 then				-- add
		reg[b] = reg[b] + cd

	elseif a == 8 and d == 0 then	-- set
		reg[b] = reg[c]

	elseif a == 8 and d == 1 then	-- or
		reg[b] = bit.bor(reg[b], reg[c])

	elseif a == 8 and d == 2 then	-- and
		reg[b] = bit.band(reg[b], reg[c])

	elseif a == 8 and d == 3 then	-- xor
		reg[b] = bit.bxor(reg[b], reg[c])

	elseif a == 8 and d == 4 then	-- add
		reg[b] = reg[b] + reg[c]
		reg[15] = math.floor(reg[b] / 256)
		reg[b] = reg[b] % 256

	elseif a == 8 and d == 5 then	-- sub
		reg[15] = reg[b] > reg[c] and 1 or 0
		reg[b] = (reg[b] - reg[c] + 256) % 256

	elseif a == 8 and d == 6 then	-- shr
		reg[15] = reg[b] % 2
		reg[b] = math.floor(reg[b] / 2)

	elseif a == 8 and d == 7 then	-- subn
		reg[15] = reg[c] > reg[b] and 1 or 0
		reg[b] = (reg[c] - reg[b] + 256) % 256

	elseif a == 8 and d == 14 then	-- shr
		reg[15] = math.floor(reg[b] / 128)
		reg[b] = (reg[b] * 2) % 256

	elseif a == 9 and d == 0 then	-- sne
		if reg[b] ~= reg[c] then
			reg.C = reg.C + 2
		end

	elseif a == 10 then	-- sne
		reg.I = b * 256 + cd

	elseif a == 11 then	-- jp
		reg.C = b * 256 + cd + reg[0]

	elseif a == 12 then	-- rnd
		reg[b] = bit.band(math.random(0, 255), cd)

	elseif a == 13 then	-- drw
		local x = b
		local y = c
		reg[15] = 0
		for i = reg.I, reg.I + d - 1 do
			local m = mem[i]
			for j = 0, 7 do
				if bit.band(m, 2 ^ (7 - j)) > 0 then
					display[x + j + y * 64] = 1 - display[x + y * 64]
					reg[15] = 1
				end
			end
			y = y + 1
		end








	end


	for i = 0, 64 * 32 - 1 do
		local x = i % 64
		local y = math.floor(i / 64)
		local b = display[i]

		local color = b == 1 and { 255, 255, 255 } or { 0, 0, 0}
		love.graphics.setColor(unpack(color))
		love.graphics.rectangle("fill", x * 4, y * 4, 4, 4)
		
	end


end


