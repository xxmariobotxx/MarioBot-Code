local file = io.open("NESfont.txt","r") --open the font
local texttemplates = {} --list of bitmaps where the font will be stored
while true do
	local chr = file:read("*line") --read char
	if chr == nil then break end --end of file
	local bitmap = {}
	for i=1,7 do
		local line = file:read("*line") --read each line
		for j=1,7 do
			table.insert(bitmap,string.sub(line,j,j)=="#") --insert into bitmap as booleans
		end
	end
	texttemplates[chr] = bitmap --add to the table
end
local function draw(text,x,y,color,backcolor) --draws text
	local startx = x --original x to return to on \n
	for i=1,string.len(text) do
		local chr = string.sub(text,i,i)
		if chr == "\n" then
			x = startx
			y = y + 8
		else
			gui.drawbox(x,y,x+7,y+7,backcolor,backcolor) --put background
			local bitmap = texttemplates[chr]
			for px=0,6 do --loop through each coord
				for py=0,6 do
					if bitmap[py*7+px+1] then --draw pixel if it should be drawn
						gui.drawbox(x+px,y+py,x+px,y+py,color,color)
					end
				end
			end
			x = x + 8
		end
		if x>240 then
			x = startx
			y = y + 8
		end
	end
end
local keywordlist = {"and","break","do","else","elseif","end","false","for","function",
	"if","in","local","nil","not","or","repeat","return","then","true","until","while"}
local idcharstr = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local numcharstr = ".0123456789"
local keywords = {}
for i,keyword in ipairs(keywordlist) do
	keywords[keyword]=true
end
local idchars = {}
local stidchars = {}
local numchars = {}
for i=1,string.len(numcharstr) do
	local chr = string.sub(numcharstr,i,i)
	idchars[chr]=true
	numchars[chr]=true
end
for i=1,string.len(idcharstr) do
	local chr = string.sub(idcharstr,i,i)
	idchars[chr]=true
	stidchars[chr]=true
end
local function drawlua(text,x,y,color,idcolor,keycolor,numcolor,strcolor,comcolor,backcolor) --draws text
	text = text .. "\n"
	local startx = x --original x to return to on \n
	local mode = 0 -- 0 = normal, 1 = identifier, 2 = keyword, 3 = number, 4 = string ', 5 = string " 6 = comment
	local esc = false --right after a \ in a string
	for i=1,string.len(text) do
		local chr = string.sub(text,i,i)
		if chr == "\n" then
			x = startx
			y = y + 8
			mode = 0
		elseif chr == "\t" then
			x = startx + math.ceil((x-startx+1)/32)*32
		else
			if (mode==1 or mode==2) and not idchars[chr] then
				mode = 0
			end
			if mode==3 and not numchars[chr] then
				mode = 0
			end
			if mode==4 or mode==5 then
				if not esc then
					if chr=="\\" then
						esc = true
					end
					if (mode==4 and chr=="'") or (mode==5 and chr=='"') then
						mode = 0
						esc = true
					end
				else
					esc = false
				end
			end
			if mode==0 then
				if stidchars[chr] then
					mode = 1
					local j = 0
					local identifier = chr
					while true do
						j = j + 1
						local nchar = string.sub(text,i+j,i+j)
						if not idchars[nchar] then
							break
						end
						identifier = identifier .. nchar
					end
					if keywords[identifier] then
						mode = 2
					end
				end
				if numchars[chr] then
					mode = 3
				end
				if chr == "'" and not esc then
					mode = 4
				end
				if chr == '"' and not esc then
					mode = 5
				end
				if chr == "-" and string.sub(text,i+1,i+1)=="-" then
					mode = 6
				end
				esc = false
			end
			gui.drawbox(x,y,x+7,y+7,backcolor,backcolor) --put background
			local bitmap = texttemplates[chr]
			local charcolor
			if mode==0 then
				charcolor = color
			elseif mode==1 then
				charcolor = idcolor
			elseif mode==2 then
				charcolor = keycolor
			elseif mode==3 then
				charcolor = numcolor
			elseif mode==6 then
				charcolor = comcolor
			else
				charcolor = strcolor
			end
			if (chr == '"' or chr == "'") and mode ~= 6 then
				charcolor = strcolor
			end
			for px=0,6 do --loop through each coord
				for py=0,6 do
					if bitmap[py*7+px+1] then --draw pixel if it should be drawn
						gui.drawbox(x+px,y+py,x+px,y+py,charcolor,charcolor)
					end
				end
			end
			x = x + 8
		end
		if x>240 then
			x = startx
			y = y + 8
		end
	end
end
drawtext = {draw=draw,drawlua=drawlua}
return drawtext