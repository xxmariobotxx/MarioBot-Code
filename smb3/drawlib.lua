draw = {}

local function color(hex) --Converts to a color
	return bit.tobit(256*hex + 255)
end
draw.color = color
local function tcolor(hex) --Converts to a color
	return bit.tobit(hex)
end
draw.tcolor = tcolor

local zero = {' ###### ','##----##','#--##--#','#--##--#','#--##--#','##----##',' ###### '}
local nine = {' ###### ','##----##','#--##--#','##-----#',' ####--#',' #----##',' ###### '}
local eight= {' ###### ','##----##','#--##--#','##----##','#--##--#','##----##',' ###### '}
local seven= {'########','#------#','#####--#','   #--##','  #--## ',' #--##  ',' ####   '}
local six  = {' ###### ','##----# ','#--#### ','#-----##','#--##--#','##----##',' ###### '}
local five = {'####### ','#-----# ','#--#### ','#-----##','#####--#','#-----##','####### '}
local four = {'####### ','#--##-# ','#--##-# ','#--##-##','#------#','#####-##','    ### '}
local three= {'####### ','#-----##','#####--#',' #----# ','#####--#','#-----##','####### '}
local two  = {' ###### ','#-----##','#####--#',' #----# ','#--#####','#------#','########'}
local one  = {' #####  ',' #---#  ',' ##--#  ','  #--#  ',' ##--## ',' #----# ',' ###### '}
local digits = {[0]=zero,one,two,three,four,five,six,seven,eight,nine}
draw.DIGITS = digits

local white = color(0xFFFFFF)
draw.WHITE = white
local black = color(0x000000)
draw.BLACK = black

local grayscale = {[' ']=0,['#']=black,['-']=white}
draw.GRAYSCALE = grayscale

local cyan = color(0x7FFFFF)
draw.CYAN = cyan
local blue = color(0x003FFF)
draw.BLUE = blue
local green = color(0x3FFF00)
draw.GREEN = green
local yellow = color(0xFFBF00)
draw.YELLOW = yellow
local red = color(0xFF3F00)
draw.RED = red
local gray = color(0xBFBFBF)
draw.GRAY = gray

local function drawrect(x,y,w,h,c)
	gui.drawbox(x,y,x+w-1,y+h-1,c,c)
end
draw.rect = drawrect

local function drawborder(x,y,w,h,c)
	w=w-1
	h=h-1
	gui.drawbox(x,y,x+w,y,c,c)
	gui.drawbox(x,y,x,y+h,c,c)
	gui.drawbox(x,y+h,x+w,y+h,c,c)
	gui.drawbox(x+w,y,x+w,y+h,c,c)
end
draw.border = drawborder

local function drawimage(x,y,img,palette)
	for py,row in ipairs(img) do
		for px=1,string.len(row) do
			local color = palette[string.sub(row,px,px)]
			gui.drawbox(x+px-1,y+py-1,x+px-1,y+py-1,color,color)
		end
	end
end
draw.image = drawimage

local function drawnumber(x,y,num,numdig)
	for p=1,numdig do
		local digit = math.floor(num/math.pow(10,numdig-p))%10
		drawimage(x+(p-1)*8,y,digits[digit],grayscale)
	end
end
draw.number = drawnumber

return draw