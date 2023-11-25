require "drawtext"

function toRGBA(ARGB) --Converts to a color
    return bit.lshift(ARGB, 8) + bit.rshift(ARGB, 24)
end

--colors
white = toRGBA(0xFFFFFFFF)
blue = toRGBA(0xFF003FFF)
green = toRGBA(0xFF3FFF00)
yellow = toRGBA(0xFFFFBF00)
red = toRGBA(0xFFFF3F00)
gray = toRGBA(0xFFBFBFBF)
black = toRGBA(0xFF000000)

function discord(message)
    local file = io.open("discord.txt","a")
    file:write(tostring(message).."\n")
    file:close()
end

function run(filename)
	program,err=loadfile(filename)
	if not program then
		return false,err
	end
	program = coroutine.create(program)
	while true do
		success,err = coroutine.resume(program)
		if success == false then
			return false,err
		elseif err == true then
			return true,filename .. " ran successfully"
		end
		interrupt=loadfile("interrupt.lua")
		if interrupt then
			interruptclear = io.open("interrupt.lua","w")
			if interruptclear then interruptclear:close() end
			restartprog = nil
			pcall(interrupt)
			if restartprog then
				return run(restartprog)
			end
		end
		emu.frameadvance()
	end
end

luigiofilename = "luigio-smb3.lua"
while true do
	success,err = run(luigiofilename)
	if success then
		break
	end
	while true do
		drawtext.draw(err,0,128,red,black)
		interrupt=loadfile("interrupt.lua")
		if interrupt then
			restartprog = nil
			interruptclear = io.open("interrupt.lua","w")
			if interruptclear then interruptclear:close() end
			pcall(interrupt)
			if restartprog then
				luigiofilename = restartprog
				break
			end
		end
		emu.frameadvance()
	end
end
