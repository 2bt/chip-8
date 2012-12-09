require "helper"
require "bit"

-- 16 keys
keys = {}
keys["1"] = 1
keys["2"] = 2
keys["3"] = 3
keys["q"] = 4
keys["w"] = 5
keys["e"] = 6
keys["a"] = 7
keys["s"] = 8
keys["d"] = 9
keys["y"] = 10
keys["x"] = 0
keys["c"] = 11
keys["4"] = 12
keys["r"] = 13
keys["f"] = 14
keys["v"] = 15

input = {}

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	end

	for k, v in pairs(keys) do
		if key == k then
			input[v] = true
		end
	end
end

function love.keyreleased(key)
	for k, v in pairs(keys) do
		if key == k then
			input[v] = false
		end
	end
end



function love.load()
	love.mouse.setVisible(false)

	-- prepare memory
	mem = { 0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70,
			0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0, 0x90,
			0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0, 0xF0, 0x80,
			0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40, 0xF0, 0x90, 0xF0,
			0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0, 0xF0, 0x90, 0xF0, 0x90,
			0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0, 0xF0, 0x80, 0x80, 0x80, 0xF0,
			0xE0, 0x90, 0x90, 0x90, 0xE0, 0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0,
			0x80, 0xF0, 0x80, 0x80 }

	local i = 0x200
	for b in io.open("roms/BLITZ"):read("*a"):gmatch(".") do
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
	reg.D = 0
	reg.S = 0
	
	stack = {}

	display = {}
	for i = 0, 64 * 32 - 1 do
		display[i] = 0
	end

end


function love.update(dt)
--	love.timer.sleep((1 - dt) * 1000 / 60) -- doesn't work \:

end


function cycle()
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
		stack[#stack + 1] = reg.C
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
		reg[b] = (reg[b] + cd) % 256

	elseif a == 8 then
		if d == 0 then	-- set
			reg[b] = reg[c]

		elseif d == 1 then	-- or
			reg[b] = bit.bor(reg[b], reg[c])

		elseif d == 2 then	-- and
			reg[b] = bit.band(reg[b], reg[c])

		elseif d == 3 then	-- xor
			reg[b] = bit.bxor(reg[b], reg[c])

		elseif d == 4 then	-- add
			reg[b] = (reg[b] + reg[c]) % 256
			reg[15] = reg[b] + reg[c] >= 256 and 1 or 0

		elseif d == 5 then	-- sub
			reg[15] = reg[b] <= reg[c] and 0 or 1
			reg[b] = (reg[b] - reg[c] + 256) % 256

		elseif d == 6 then	-- shr
			reg[15] = reg[b] % 2
			reg[b] = math.floor(reg[b] / 2)

		elseif d == 7 then	-- subn
			reg[15] = reg[c] <= reg[b] and 0 or 1
			reg[b] = (reg[c] - reg[b] + 256) % 256

		elseif d == 0xe then	-- shr
			reg[15] = math.floor(reg[b] / 128)
			reg[b] = (reg[b] * 2) % 256

		else
			print(a, b, c, d)
		end


	elseif a == 9 and d == 0 then	-- sne
		if reg[b] ~= reg[c] then
			reg.C = reg.C + 2
		end

	elseif a == 0xa then	-- sne
		reg.I = b * 256 + cd

	elseif a == 0xb then	-- jp
		reg.C = (b * 256 + cd + reg[0]) % 0x1000

	elseif a == 0xc then	-- rnd
		reg[b] = bit.band(math.random(0, 255), cd)

	elseif a == 0xd then	-- drw
		local x = reg[b]
		local y = reg[c]

		reg[15] = 0
		for i = 0, d - 1 do
			local m = mem[reg.I + i]
			for j = 0, 7 do
				if bit.band(m, 2 ^ (7 - j)) > 0 then
					local q = display[(x + j) % 64 + ((y + i) % 32) * 64]
					if q == 1 then
						reg[15] = 1
					end
					display[(x + j) % 64 + ((y + i) % 32) * 64] = 1 - q
				end
			end
		end

	elseif a == 0xe then
		if cd == 0x9e then	-- skp
			if input[reg[b]] then
				reg.C = reg.C + 2
			end

		elseif cd == 0xa1 then	-- skp
			if not input[reg[b]] then
				reg.C = reg.C + 2
			end

		else
			print(a, b, c, d)
		end

	-- TODO: more opcodes...


	elseif a == 0xf then

		if cd == 0x07 then	-- timer
			reg[b] = reg.D
			if reg.D > 0 then
				reg.D = reg.D - 1
				return true
			end

		elseif cd == 0x0a then -- wait for key
			reg.C = reg.C - 2
			for i = 0, 15 do
				if input[i] then
					reg[b] = i
					reg.C = reg.C + 2
					break
				end
			end

		elseif cd == 0x15 then	-- timer
			reg.D = reg[b]

		elseif cd == 0x18 then	-- timer
			reg.S = reg[b]

		elseif cd == 0x1e then
			reg.I = (reg.I + reg[b]) % 0x1000


		elseif cd == 0x29 then		-- ld
			reg.I = reg[b] * 5 + 1


		elseif cd == 0x33 then		-- bcd stuff
			mem[reg.I + 0] = math.floor(reg[b] / 100)
			mem[reg.I + 1] = math.floor(reg[b] / 10) % 10
			mem[reg.I + 2] = reg[b] % 10


		elseif cd == 0x55 then		-- ld
			for i = 0, b do
				mem[reg.I + i] = reg[i]
			end
			reg.I = reg.I + b + 1

		elseif cd == 0x65 then		-- ld
			for i = 0, b do
				reg[i] = mem[reg.I + i]
			end
			reg.I = reg.I + b + 1


		else
			print(a, b, c, d)
		end
	else
		print(a, b, c, d)

	end

end


function love.draw()

	-- testing
	for i = 1, 15 do
		if cycle() then
			break
		end
	end

	-- render display

	for i = 0, 64 * 32 - 1 do
		local x = i % 64
		local y = math.floor(i / 64)
		local b = display[i]

		local color = b == 1 and { 255, 255, 255 } or { 0, 0, 0 }
		love.graphics.setColor(unpack(color))
		love.graphics.rectangle("fill", x * 4, y * 4, 4, 4)
		
	end


end


