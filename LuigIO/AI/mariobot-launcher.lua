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

discordtag = "<@&459702114709667860>" --if you are using a lua console bot and want it to tag you on an error

function discord(message) --writes to discord if you have lua console enabled
    local file = io.open("discord.txt","r")
    local prev = file:read("*all")
    file:close()
    local file = io.open("discord.txt","w")
    file:write(prev.."\n"..message)
    file:close()
end

function run(filename)
	program,err=loadfile(filename)
	if not program then
		file = io.open("discord.txt","w")
		file:write(discordtag.." "..err)
		file:close()
		return false,err
	end
	program = coroutine.create(program)
	while true do
		success,err = coroutine.resume(program)
		if success == false then
			file = io.open("discord.txt","w")
			file:write(discordtag.." "..err)
			file:close()
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

mariobotfilename = "MarioBot-V1.lua"
while true do
	success,err = run(mariobotfilename)
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
				mariobotfilename = restartprog
				break
			end
		end
		emu.frameadvance()
	end
end
