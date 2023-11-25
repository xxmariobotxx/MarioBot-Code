require "drawlib"
require "drawtext"

levelname = "1-1"

savestateSlotMap = 1 --savestate slot to save the map selection from.
savestateSlotLevel = 2
savestateSlotBOSS = 3
savestateObj = savestate.object(savestateSlotMap)
savestate.load(savestateObj)
LM = memory.readbyte(0x0726)
Player = 1 + LM

BoxRadius = 6 --The radius of the vision box around Luigi
InitialOscillations = {50,60,90} --Initial set of oscillation timers
BoxWidth = BoxRadius*2+1 --Full width of the box
BoxSize = BoxWidth*BoxWidth --Number of neurons in the box
Inputs = BoxSize + 3 + #InitialOscillations

InitialMutationRates = {
	linkInputBox=0.1,
	linkBottomRow=0.05,
	linkLayers=0.1,
	linkRandom=2.0,
	node=0.5,
	disable=0.4,
	enable=0.2,
	oscillation=0.2,
	nswitch=0.01,
	step=0.1
}

FramesPerEval = 5 --Number of frames between each network update

ButtonNames = {"A","B","up","down","left","right"}
ButtonNumbers = {A=1,B=2,up=3,down=4,left=5,right=6}

DeltaDisjoint = 4.0 --multiplier for disjoint in same species function
DeltaWeights = 0.4 --multiplier for weights in same species function
DeltaThreshold = 1.0 --threshold for delta to be in the same species
DeltaSwitch = 0.6 --threshold for delta of the network switch location

DisplaySlots = false --Display the sprite slots?
DisplaySprites = false --Display the sprite hitboxes?
DisplayGrid = 0 --Display a large network inputs grid?
DisplayNetwork = true --Display the neural network state?
DisplayStats = true --Display top stats bar?
DisplayRanges = false --Display special fitness ranges?
DisplayCounters = false --Display death/time counter?
ScrollWalkPause = false

Replay = false

ManualInput = false --Input manually rather than by network?

--Penalty coeffs for fitness rank of netswitched species
NetworkPenaltyInner = 0.8
NetworkPenaltyOuter = 0.87

CrossoverChance = 0.75 --Chance of crossing 2 genomes rather than copying 1

MajorBreakFitness = 30 --Fitness before a breakthrough is not counted as minor

BaseInterbreedChance = 0.07 --base interbreed chance per species
InterbreedCutoff = 2.86 --average species size when interbreed is turned off
InterbreedDegree = 1.0 --degree of interbreed curve

TimeBeforePopOscil = 6 --time in each oscillation before the population changes

MaxStaleness = 25 --max staleness before death

FramesOfDeathAnimation = 50 --amount of the death animation to show

WeightPerturbChance = 0.9
WeightResetChance = 0.9

MaxNodes = 1000000

FPS = 60

TurboMin = 0
TurboMax = 0
CompleteAutoTurbo = false
currentTurbo = false
emu.speedmode("normal")
marioAutoscroll = 0
basescroll = 0
marioWhiteblock = 0
boss = false
battle = false
basetimeout = 120
roottimeout = 120
preloaded = false
cardDistance = 9999
powerupFitness = 150
roottimeoutboss = 900

dirsep = "\\" --forward or backward slash for file separation? depends on OS

ProgramStartTime = os.time()
Startlocations={["0-1-2"]=true,["1-1-5"]=true,["2-1-5"]=true,["3-1-2"]=true,["4-1-4"]=true,["5-1-3"]=true,["6-1-1.5"]=true,["7-1-2.5"]=true}

marioPrevWhiteblock = 0
marioPrevAutoscroll = 0
scrollBonus = 0
scrollBonusAdjust = 0
lockBound = false
function getPositions(initial) 
	local marioHiX = memory.readbyte(0x0075)
	local marioLoX = memory.readbyte(0x0090)
	marioX = marioLoX+256*marioHiX
	marioScreenX = memory.readbyte(0x00AB)
	marioXVel = memory.readbyte(0x00BD)
	marioY = 400-(memory.readbyte(0x00A2)+256*memory.readbyte(0x0087))
	marioScreenY = memory.readbyte(0xB4)--memory.readbyte(0x0228)
	marioYVel = memory.readbyte(0x00CF)
	marioScore = memory.readbyte(0x0716)*2560 + memory.readbyte(0x0717)*10
	marioActive = memory.readbyte(0x00CE) == 0 and memory.readbyte(0x03DE) == 0 --loading and using pipe/door
	local marioWhiteblock = memory.readbyte(0x0570)
	local marioAutoscroll = memory.readbyte(0x7A0C)
	--print(marioScreenY)
	--local marioAutoscrollY = memory.readbyte(0x7A0D)
	marioHold = memory.readbyte(0x06A4)
	marioPower = memory.readbyte(0x00ED)
	marioMusic = memory.readbyte(0x04E5)
	koopalingDefeated = memory.readbyte(0x07BD)
	kingconvo = memory.readbyte(0x0728)
	local whiteblockAdjustment = 0
	if (not marioActive and marioScreenY > 184) or doorflag then
		doorflag = true
		marioOutOfBound = false
		if marioActive and marioScreenY < 184 then
			doorflag = false
		end
	else
		marioOutOfBound = (marioY < 0 or (marioScreenY > 184 and memory.readbyte(0x0544) == 0 and cardDistance > 0.5)) and marioActive -- byte is for above screen
	end
	if marioPrevWhiteblock >100 and marioWhiteblock < -100 then
		whiteblockAdjustment = 256
	else
		whiteblockAdjustment = 0
	end
	marioPrevWhiteblock = marioWhiteblock
	WhiteblockBonus = whiteblockAdjustment + marioWhiteblock*10
	if scrollBonus == 0 and not marioActive then
		-- scrollBonusAdjust = -marioAutoscroll
		memory.writebyte(0x7A0C,0)
		--basemarioA
		local marioAutoscroll = 0
	end
	if marioAutoscroll == 0 and marioPrevAutoscroll ~= 0 and scrollBonus > 0 then
		basescroll = basescroll + marioPrevAutoscroll
	-- elseif marioAutoscroll == marioPrevAutoscroll and scrollBonus > 0 then
		-- scrollBonus = 0
		-- basescroll = 0
	end
	scrollBonus = basescroll + marioAutoscroll + scrollBonusAdjust
	marioPrevAutoscroll = marioAutoscroll
	local numSprites = 6
	sprites = {}
	for s=1,numSprites do
		local sprite = {}
		sprite.x = memory.readbyte(0x0090+s)+256*memory.readbyte(0x0075+s)
		sprite.y = 416-(memory.readbyte(0x00A2+s)+256*memory.readbyte(0x0087+s))
		sprite.state = memory.readbyte(0x0660+s)
		sprite.type = memory.readbyte(0x670+s)
		if sprite.type == 54 then
			table.insert(sprites,{x=sprite.x+16,y=sprite.y,state=256})
			table.insert(sprites,{x=sprite.x+32,y=sprite.y,state=256})
			--print(sprite)
		end
		if sprite.type == 14 then
			marioScore = marioScore + memory.readbyte(0x0083)*1000
		end
		if sprite.type == 74 or sprite.type == 82 then --added this because luigi does not want to pick up the ball once he defeats boomboom
			if sprite.x - marioX > 0 then
				for a=1,30 do
					joypad.set(Player,{right=true})
					
					coroutine.yield()
				end
			else
				for a=1,30 do
					joypad.set(Player,{left=true})
					coroutine.yield()
				end
			end
		end
		table.insert(sprites,sprite)
	end
	for s=1,8 do --special sprites
		local sprite = {}
		local id = memory.readbyte(0x7FC5+s)
		if id ~= 0 then
			sprite.type = id
			sprite.y = 416-memory.readbyte(0x05BE+s)-256*(memory.readbyte(0x7FD4+s))
			local xlow = memory.readbyte(0x05C8+s)
			local xhigh = 0
			local differ = xlow-marioLoX
			if differ > 128 then
				xhigh = marioHiX -1
			elseif differ < -128 then
				xhigh = marioHiX +1
			else
				xhigh = marioHiX
			end
			sprite.x = xlow + 256*xhigh
			sprite.state=256
			table.insert(sprites,sprite)
		end
	end
end

function getTile(dx,dy)
	local x = math.floor((marioX + dx + 8)/16)
	local y = math.floor((432-marioY + dy - 8)/16)
	local page = math.floor(x/16)
	local px = x % 16
	local tile = memory.readbyte(0x6000+px+y*16+page*432)
	--print(x .. " " .. marioScreenX/16)
	local scrollX = (marioX-marioScreenX)/16
	local scrollY = (marioY+marioScreenY-161)/16
	if x < scrollX or x > scrollX + 16 or 26-y < scrollY or 26-y > scrollY + 11 then return 0 end
	return tile
end

CollisionTileSet = {}
-- CollisionTileArrays[1]={air=128,0x25,0x26,0x27,0x2C,0x2D,0x2E,0x2F,0x30,0x31,0x32,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x5F,0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0xA0,0xA1,0xA2,0xAD,0xAE,0xAF,0xB1,0xB2,0xB3,0xB4,0xB5,0xB5,0xB7,0xB8,0xB9,0xBA,0xBB,0xBC,0xE2,0xE3,0xE4,0xF0,0xF1,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9}
-- CollisionTileArrays[3]={air=134,0x2E,0x2F,0x30,0x31,0x32,0x48,0x5F,0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x87,0x99,0x9A,0x9B,0x9C,0x9D,0x9E,0x9F,0xA1,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xAB,0xAC,0xAD,0xAE,0xAF,0xB0,0xB1,0xB2,0xB3,0xB4,0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xBB,0xBC,0xBD,0xBE,0xBF,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xF0,0xF1,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9}
-- CollisionTileArrays[4]={air=128,0x11,0x12,0x13,0x22,0x23,0x24,0x25,0x2C,0x2E,0x2F,0x30,0x31,0x32,0x34,0x35,0x36,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x5B,0x5F,0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x87,0x88,0x89,0x8A,0x8B,0x8C,0x8E,0x8F,0x90,0xAD,0xAE,0xAF,0xB0,0xB1,0xB2,0xB3,0xB4,0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xBB,0xBC,0xFA,0xFB}
CollisionTileArray= {0x80,0x02,0x86,0x80,0x80,0x8C,0x42,0x80,0x80,0x80,0x80,0x80,0xCC,0x86,0x09,0x09,0x09,0x02} 

function getTileset()
	local tileset = memory.readbyte(0x070A)
	local x1a = memory.readbyte(0x7E94)
	local x1b = memory.readbyte(0x7E95)
	local x1c = memory.readbyte(0x7E96)
	local x1d = memory.readbyte(0x7E97)
	card_x = nil
	for j=1,48 do
		local id = memory.readbyte(0x07B3E+(3*j))
		if id == 0x41 then --0x41 is end card
		
			card_x = memory.readbyte(0x07B3E+(3*j)+1)*16
			card_y = memory.readbyte(0x07B3E+(3*j)+2)*16
		end
		if id == 0xFF then --ff indicates last entry
			if card_x == nil then
				card_x = 9999
				card_y = 9999
			end
			break
		end
	end
	CollisionTileSet = {a=x1a,b=x1b,c=x1c,d=x1d}
	CollisionTileSet.air=CollisionTileArray[tileset]
end

function getInputs() --Create the grid around Mario that is the network's vision
    getPositions() --Get all required memory data
    local inputs = {} --Grid around Mario that shows blocks/sprites
	--Loop through each space in the grid
	local BoxRadius = BoxRadius
	local BoxWidth = BoxWidth
	local CollisionTileSet = CollisionTileSet
	local marioX = marioX
	local marioY = marioY
	local sprites = sprites
    for dy=-BoxRadius*16,BoxRadius*16,16 do
        for dx=-BoxRadius*16,BoxRadius*16,16 do
            inputs[#inputs+1] = 0
			--If the tile contains a block, set to 1
            local tile = getTile(dx, dy)
            if tile ~= CollisionTileSet.air and marioY+dy < 0x1B0 then
				if (tile >= CollisionTileSet.a and tile < 0x40) or (tile >= CollisionTileSet.b and tile < 0x80) or (tile >= CollisionTileSet.c and tile < 0xC0) or (tile >= CollisionTileSet.d and tile < 0xFF) then inputs[#inputs] = 1
                else inputs[#inputs] = 0.3
				end
            end
        end
    end
	--for each sprite set it's location to -1
	local spriteNearlocal = false
	for i,sprite in ipairs(sprites) do
		if sprite.state ~= 0 then
			local distx = math.floor((sprite.x - marioX)/16 + 0.5)
			if math.abs(distx) < 3.5 then
				spriteNearlocal = true
			end
			local disty = math.floor((-sprite.y + marioY)/16 + 0.5)
			if math.abs(distx)<=BoxRadius and math.abs(disty)<=BoxRadius then
				inputs[distx+BoxRadius+1+(disty+BoxRadius)*BoxWidth] = -1
			end
		end
	end
	spriteNear = spriteNearlocal
	return inputs
end

--Initialization for the genetic system
function initPool(Boss) --The pool contains all data for the genetics of the AI
    local poolold = pool
	pool = {}
    pool.species = {} --List of species
    pool.generation = 0 --Generation number
    pool.innovation = 1 --Innovation tracks genes that are copies of each other vs unique
    pool.currentGenome = 1 --current genome/species to display on top bar
	pool.currentSpecies = 1
    pool.maxFitness = 0 --Maximum fitness
	pool.bestSpecies = 1 --best species
	pool.secondFitness = 0 --Second best fitness
    pool.maxCounter = 0 --Number of times it has gotten close to max fitness
    pool.gsid = 0 --GSID tracks species so each one gets a unique id
	pool.bottleneck = 0 --Number of gens since last breakthrough
	pool.bottleneckloops = 0 --Number of oscillation loops in the bottleneck
	pool.population = 999 --Number of genomes
	pool.lastMajorBreak = 0 --Last breakthrough of more than majorBreakFitness
	pool.current = 0
	pool.total = 0
	pool.average = 0
	pool.lastbreaktime = 0
	if not Boss then
		pool.attempts = 1 --number of attempts
		pool.deaths = 0 --number of deaths (auto timeouts do not count)
		pool.totalTime = 0 --total time elapsed in-game
		pool.realTime = 0 --total time elapsed out of game
		
		pool.history = "" --breakthrough tracker
		pool.breakthroughX = 0 --indicator stuff
		pool.breakthroughZ = ""
		pool.maphistogram = {}
		pool.breakthroughfiles = {}
	else
		pool.attempts = poolold.attempts
		pool.deaths = poolold.deaths
		pool.totalTime = poolold.totalTime
		pool.realTime = poolold.realTime
		pool.history = poolold.history
		pool.breakthroughX = poolold.breakthroughX
		pool.breakthroughZ = poolold.breakthroughZ
		pool.maphistogram = poolold.maphistogram
		pool.breakthroughfiles = poolold.breakthroughfiles
	end
end

function newSpecies() --Each species is a group of genomes that are similar
    local species = {}
    species.maxFitness = 0 --farthest the species has gotten
    species.maxRightmost = 0 --Farthest the species has gotten, ignoring time
    species.averageFitness = 0 --Average fitness of the species
    species.staleness = 0 --Number of gens since the species improved
    species.genomes = {} --List of genomes
    species.nick = '' --nickname of the species
	species.turbo = true --whether the species will use turbo or not
    species.gsid = pool.gsid --give the species a unique GSID
	pool.gsid = pool.gsid + 1
	species.breakthroughX = 0 --indicator stuff
	species.breakthroughZ = ""
    return species
end

function newGene() --A gene is a link between two neurons
    local gene = {}
    gene.into = 0 --input neuron
    gene.out = 0 --output neuron
    gene.weight = 0.0 --multiplier
    gene.enabled = true --gene is turned on
    gene.innovation = 0 --gene ID to find duplicates
	gene.delay = 0
    return gene
end

function copyGene(gene) --copy a gene
	local newGene = {}
	newGene.into = gene.into
	newGene.out = gene.out
	newGene.weight = gene.weight
	newGene.enabled = gene.enabled
	newGene.innovation = gene.innovation
	newGene.delay = gene.delay
	return newGene
end

function newGenome(numNetworks) --Each genome is an evolved 'player' that attempts the level
    local genome = {}
    genome.genes = {} --List of networks in raw gene form
    genome.networks = {} --List of networks in neuron form
    genome.oscillations = {} --Periods of each of 3 oscillating nodes
    genome.maxNeuron = Inputs --Index of largest neuron
	for n=1,numNetworks do --Initialize these as blank arrays for each network
		genome.genes[n] = {}
		genome.oscillations[n] = {}
		for i=1,#InitialOscillations do --Initialize periods to default values
			genome.oscillations[1][i] = InitialOscillations[i]
		end
	end
    genome.fitstate = {} --information about the genome's final state
    genome.globalRank = 0 --Ranking of the genome (low is worse)
    genome.networkswitch = {} --List of positions where the network switches
	for n=1,numNetworks-1 do
		genome.networkswitch[n] = 0.0
	end
    genome.mutationRates = {} --List of mutation rates
	for name,rate in pairs(InitialMutationRates) do
		genome.mutationRates[name] = rate
	end
    return genome
end

function copyGenome(genome) --copy a genome
	local ngenome = newGenome(#genome.genes) --create basic new genome
	for n=1,#genome.genes do --copy each network over
		for i,gene in pairs(genome.genes[n]) do
			table.insert(ngenome.genes[n],copyGene(gene))
		end
		for i=1,#genome.oscillations[n] do
			ngenome.oscillations[n][i] = genome.oscillations[n][i]
		end
	end
	ngenome.maxNeuron = genome.maxNeuron
	for n=1,#genome.genes-1 do
		ngenome.networkswitch[n] = genome.networkswitch[n]
	end
	for name,rate in pairs(genome.mutationRates) do
		ngenome.mutationRates[name] = rate
	end
	return ngenome
end

function newNeuron() --A neuron is a stored value that is calculated based on inputs and broadcasts to its outputs
    local neuron = {}
    neuron.incoming = {} --list of incoming genes
	neuron.queues = {} -- incoming queues for delay
    neuron.value = 0.0 --current value
	neuron.layer = 0 --What layer the neuron is in (0 means it has not been calculated)
    return neuron
end

--Evaluation of networks
function generateNetwork(genome)
    for n=1,#genome.genes do --For each network
		local neurons = {}
		for i=1,Inputs do --Put in input nodes
			neurons[i] = newNeuron()
		end
		for g=1,#genome.genes[n] do --Loop through each gene
            local gene = genome.genes[n][g]
            if gene.enabled then --Only add enabled genes
                --If either side of gene is not added to neurons yet then add it
                if neurons[gene.into] == nil then
                    neurons[gene.into] = newNeuron()
                end
                if neurons[gene.out] == nil then
                    neurons[gene.out] = newNeuron()
                end
                if gene.into > 0 then
                    table.insert(neurons[gene.out].incoming,gene) --Add gene to the output neuron's incoming
                    queue = {}
                    for i=1,gene.delay do
                        table.insert(queue,0)
                    end
                    table.insert(neurons[gene.out].queues,queue)
                end
            end
        end
		
		local layers = {}
		while true do --loop until all layers found
			local layer = {}
			local finished = true --if all have been sorted
			for i,neuron in pairs(neurons) do --loop through and find all possible for calculation
				if neuron.layer == 0 then --Dont re-check already placed neurons
					local possible = true
					for j,gene in pairs(neuron.incoming) do --see if any incoming genes are not calculated yet
						if neurons[gene.into].layer == 0 then
							possible = false
							break
						end
					end
					if possible then --if has enough information to evaluate
						table.insert(layer,i)
						finished = false --a neuron was placed so it has not been all sorted yet
					end
				end
			end
			if finished then --exit the loop
				break
			end
			for i=1,#layer do --For each neuron in the new layer set it to now be sorted
				neurons[layer[i]].layer = #layers+1
			end
			table.insert(layers,layer)
		end
		local network = {}
		network.neurons = neurons
		network.layers = layers
		network.genes = genome.genes[n]
		genome.networks[n] = network
	end
end


function sigmoid(x)
    return 2/(1+math.exp(-4.9*x))-1
end
		

function evaluateNetwork(network, inputs, oscillating, frame)
    table.insert(inputs,1.0) --Bias node
	local marioXVel = marioXVel
	local marioYVel = marioYVel
	local ScrollWalkPauselocal = ScrollWalkPause
	local marioScreenX = marioScreenX
	local endscroll = endscroll
	local spriteNear = spriteNear
	local ButtonNames = ButtonNames
	local scrollBonus = scrollBonus
	local Inputs = Inputs
	local mmax = math.max
	for i=1,#oscillating do --Oscillating nodes
		if frame % (oscillating[i]*2) < oscillating[i] then
			table.insert(inputs,1.0)
		else
			table.insert(inputs,-1.0)
		end
	end
	--Speed nodes
	if (marioXVel < 100) then
		table.insert(inputs,marioXVel / 56)
	else
		table.insert(inputs,(marioXVel - 256) / 56)
	end
	if (marioYVel < 70) then
		table.insert(inputs,marioYVel / 69)
	else
		table.insert(inputs,mmax((marioYVel - 256) / 69,1))
	end
	
    if #inputs ~= Inputs then
        emu.print("Incorrect number of neural network inputs.")
        return {}
    end
   
    for i=1,Inputs do
        network.neurons[i].value = inputs[i]
    end
   
    -- for _,neuron in pairs(network.neurons) do
        -- local sum = 0
        -- for j = 1,#neuron.incoming do
            -- local incoming = neuron.incoming[j]
            -- local other = network.neurons[incoming.into]
            -- sum = sum + incoming.weight * other.value
        -- end
       
    -- end
	for l=2,#network.layers do
        local layer = network.layers[l]
        for n=1,#layer do
            local neuron = network.neurons[layer[n]]
            local sum = 0.0
            for j = 1,#neuron.incoming do
                local incoming = neuron.incoming[j]
                local other = network.neurons[incoming.into]
                if incoming.delay == 0 then
                    sum = sum + incoming.weight * other.value
                else
                    sum = sum + incoming.weight * neuron.queues[j][1]
                    for i=1,#neuron.queues[j]-1 do
                        neuron.queues[j][i] = neuron.queues[j][i+1]
                    end
                    neuron.queues[j][#neuron.queues[j]] = other.value
                end
            end
            neuron.value = sigmoid(sum)
        end
    end
	local output = {}
	--print("Yvel " .. marioYVel)
	--print("Xvel " .. marioXVel)
	--print("x " .. marioScreenX)
	if (ScrollWalkPauselocal and (marioScreenX < 45 or (marioYVel > 5 and marioYVel < 100) or spriteNear)) or endscroll then
		ScrollWalkPause = false
		ScrollWalkPauselocal = false
		--print("off")
	end
	if ((scrollBonus > 0 and marioScreenX > 200 and (marioYVel >240 or marioYVel < 5)) or ScrollWalkPauselocal) and not endscroll then
		--print("first")
		for o=1,#ButtonNames do
			output[ButtonNames[o]] = false
		end
		if marioXVel > 10 and marioXVel < 128 then
			output["left"] = true
		end
		if marioXVel > 128 and marioXVel < 245 then
			output["right"] = true
		end
		ScrollWalkPause = true
		ScrollWalkPauselocal = true
	elseif (scrollBonus > 0 and marioScreenX > 155 and marioYVel ==0) and not spriteNear and not endscroll then
		--print("second")
		for o=1,#ButtonNames do
			output[ButtonNames[o]] = false
		end
		if marioXVel > 10 and marioXVel < 128 then
			output["left"] = true
		end
		if marioXVel > 128 and marioXVel < 245 then
			output["right"] = true
		end
		ScrollWalkPause = true
		ScrollWalkPauselocal = true
	else
		--print("1")
		for o=1,#ButtonNames do --Find neural network outputs
			output[ButtonNames[o]] = network.neurons[-o] ~= nil and network.neurons[-o].value > 0
		end
	end
	--print(ScrollWalkPause)
	--Disable opposite d-pad presses
	if forcebutton ~= nil then
		for k,v in pairs(forcebutton) do
			output[k]=v
		end
		--print(output)
	end
	if output["up"] and output["down"] then
		output["up"] = false
		output["down"] = false
	end
	if output["left"] and output["right"] then
		output["left"] = false
		output["right"] = false
	end
	return output
end

--Mutation and evolution
function genomeDelta(genes1, genes2) --sees the delta between 2 networks.
    local i2 = {} --i2 maps the innovation of a gene to the gene, for the second genome.
    for i = 1,#genes2 do
        local gene = genes2[i]
        i2[gene.innovation] = gene
    end

    local sum = 0 --total weight difference among matching genes
    local coincident = 0 --number of matching genes
    for i,gene in pairs(genes1) do
        if i2[gene.innovation] ~= nil then
            local gene2 = i2[gene.innovation]
            sum = sum + math.abs(gene.weight - gene2.weight)
            coincident = coincident + 1
        end
    end
    if coincident == 0 then --if there are no matching genes it does not match so return a very large value
        return 100
    end
	local total = #genes1 + #genes2 --number of total genes
	local disjoint = total - (coincident*2) --number of non-matching genes
    return DeltaWeights * sum / coincident + DeltaDisjoint * disjoint / total --return the delta
end

function sameSpecies(genome1,genome2) --sees whether 2 genomes are in the same species or not.
	if #genome1.networkswitch ~= #genome2.networkswitch then
        return false --must have same number of networks
    end
    for n=1,#genome1.networkswitch do
        if math.abs(genome1.networkswitch[n] - genome2.networkswitch[n]) > DeltaSwitch then
            return false --if the network switches are too far apart they are different
        end
    end
    for n=1,#genome1.genes do
        delta = genomeDelta(genome1.genes[n],genome2.genes[n])
        if delta > DeltaThreshold then
            return false --if the delta between corresponding networks is too great they are different
        end
    end
	return true --otherwise, same species
end

function shuffle(num) --shuffles an array from 1 to num.
	local output = {}
	for i=1,num do
		local offset = i - 1
		local randomIndex = offset*math.random()
		local flooredIndex = randomIndex - randomIndex%1
		if flooredIndex == offset then
			output[#output + 1] = i
		else
			output[#output + 1] = output[flooredIndex + 1]
			output[flooredIndex + 1] = i
		end
	end
	return output
end

function addToSpecies(genome)

    local foundSpecies = false
	
	local order = shuffle(#pool.species) --Used to go through in random order so as to avoid feeding patterns.
	
    for i=1,#order do
        local species = pool.species[order[i]]
        if sameSpecies(genome, species.genomes[1]) and not foundSpecies then
            table.insert(species.genomes, genome)
            foundSpecies = true
        end
    end

    if not foundSpecies then --create new species
        local newSpecies = newSpecies()
        table.insert(newSpecies.genomes, genome)
        table.insert(pool.species, newSpecies)
    end
end

function randomNeuron(genes, nonInput, nonOutput) --pick a random neuron number
    local neurons = {}
    if not nonInput then --If inputs are an option add them
        for i=1,Inputs do
            neurons[i] = true
        end
    end
	if not nonOutput then --If outputs are an option add them
		for o=1,#ButtonNames do
			neurons[-o] = true
		end
	end
    for i,gene in pairs(genes) do --Add input and output of each gene
        if not nonInput or gene.into > Inputs then --add input as long as it is valid
            neurons[genes[i].into] = true
        end
        if not nonOutput or gene.out > 0 then --add output as long as it is valid
            neurons[genes[i].out] = true
        end
    end
    local count = 0
    for _,_ in pairs(neurons) do --count number of neuron possibilities
        count = count + 1
    end
	if count == 0 then return 0 end --return 0 means that there were no possibilities
    local n = math.random(1, count) --pick a random possibility
    for k,v in pairs(neurons) do
        n = n-1 --count down until you get to correct #
        if n == 0 then
            return k
        end
    end
end

function linkDirection(genes, link) --Finds a connection's status. 0 means already exists, 1 means >, -1 means < or incomparable
    for i=1,#genes do --check each gene
        local gene = genes[i] --if the new added gene already exists return 0
        if gene.into == link.into and gene.out == link.out then
            return 0
        end
    end
	--Attempt to find a connection opposing the suggested one (that would create a loop)
	local afterNodes = {} --each node that is >= than the link.out
	afterNodes[link.out] = true
	local readAll = false --has seen every gene without adding any to the list of nodes after link.into
	while not readAll do --loop until each gene has been read and used
		readAll = true
		for i,gene in pairs(genes) do --loop through the list of genes
			if afterNodes[gene.into] == true and afterNodes[gene.out] == nil then --if new connection found
				afterNodes[gene.out] = true
				readAll = false
				if gene.out == link.into then --connection found
					return -1
				end
			end
		end
	end
	return 1 --Has not found that link.into >= link.out so it is a fine direction
end

function linkMutate(genome, which, force) --Create a random new gene
	local genes = genome.genes[which]
	--create two random neurons
	local neuronInto
	if force == 0 then --only input box
		neuronInto = math.random(1,BoxSize)
	elseif force == 1 then --only bottom row
		neuronInto = BoxSize + math.random(1,3+#InitialOscillations)
	elseif force == 2 then --non-input
		neuronInto = randomNeuron(genes, true, true)
		if neuronInto == 0 then return end --no valid non-input nodes
	else --anything
		neuronInto = randomNeuron(genes, false, true)
	end
    local neuronOut = randomNeuron(genes, true, false)
	--Create a new link
	local newLink = newGene()
    newLink.into = neuronInto
    newLink.out = neuronOut
	if neuronInto == neuronOut then return end --must not be the same neuron
	connectionStatus = linkDirection(genes,newLink) --find current status of that link
	if connectionStatus == 0 then return end --if link already exists then return
	--opposite direction
	if connectionStatus == -1 then
		newLink.out = neuronInto
		newLink.into = neuronOut
	end
	--create new innovation value and weight
	newLink.innovation = pool.innovation
    pool.innovation = pool.innovation + 1
    newLink.weight = math.random()*4-2
    newLink.delay = 0
    if math.random()>0.85 then
        newLink.delay = math.min(5,math.ceil(math.log(math.random())/math.log(0.5)))
    end
	--add to the genes
	table.insert(genes,newLink)
end

function nodeMutate(genome, which) --Split a random gene and put a neuron in the middle
	local genes = genome.genes[which]
	if #genes == 0 then return end --cannot make a node with no genes
	local gene = genes[math.random(1,#genes)] --pick a random gene
	--create the new genes
	local geneI = newGene()
	local geneO = newGene()
	geneI.into = gene.into
	geneI.out = genome.maxNeuron + 1
	geneO.into = genome.maxNeuron + 1
	geneO.out = gene.out
	--set innovation
	geneI.innovation = pool.innovation
	geneO.innovation = pool.innovation + 1
	pool.innovation = pool.innovation + 2
	--set weights
	geneI.weight = math.sqrt(math.abs(gene.weight))
    if math.random() < 0.5 then
        geneI.weight = -geneI.weight --half the time first one is negative
        geneI.delay = gene.delay
    end
	if geneI.weight == 0 then
		geneI.weight = 0.001
	end
    geneO.weight = gene.weight / geneI.weight --they should multiply to original weight
    geneO.delay = gene.delay - geneI.delay
            
    genome.maxNeuron = genome.maxNeuron + 1
    gene.enabled = false --disable old gene
    --insert the new genes
    table.insert(genes,geneI)
    table.insert(genes,geneO)
end

function enableDisableMutate(genome, which, enable) --changes a random gene to enabled or disabled
    local candidates = {} --list of genes that would be changed by this mutation
    for _,gene in pairs(genome.genes[which]) do
        if gene.enabled == not enable then --only insert if the current enabling is different from what we will set it to
            table.insert(candidates, gene)
        end
    end

    if #candidates == 0 then return end --if no valid genes then do nothing

    local gene = candidates[math.random(1,#candidates)] --pick random from candidates
    gene.enabled = enable --enable that gene
end

function oscillationMutate(genome, which) --change an oscillation node timer
    i = math.random(1,#InitialOscillations) --pick a random oscillation to change
	genome.oscillations[which][i] = genome.oscillations[which][i] + math.random(-10,10) --change by random amount
    if genome.oscillations[which][i]<0 then --no negative oscillation values
        genome.oscillations[which][i] = 0
    end
end

function nswitchMutate(genome) --change the position of a network switch
    which = #genome.networkswitch --most of the time pick the most recent switch
    if math.random() < 0.15 then
        which = math.random(1,#genome.networkswitch) --occasionally pick a random other one
    end
    genome.networkswitch[which] = genome.networkswitch[which] + math.random(-250,250) --change by random amount
	local netlimit = 0
	for i,species in ipairs(pool.species) do
		if species.maxRightmost > netlimit then
			netlimit = species.maxRightmost
		end
	end
    if genome.networkswitch[which] < 0 or genome.networkswitch[which] > netlimit then --if out of range of where genome can reach
		table.remove(genome.networkswitch) --remove the latest network
		table.remove(genome.genes)
	end
    table.sort(genome.networkswitch, function(a,b) --make sure network switches are in order through the level
        return (a < b)
    end)
end

function weightsMutate(genome, which) --change the weights of genes around a node
	local genes = genome.genes[which]
	local node = randomNeuron(genes,false,false) --pick a random neuron to change weights in the area of
	local step = genome.mutationRates["step"]
	for i,gene in pairs(genes) do
		if gene.into == node or gene.out == node then --if either end 
			if math.random() < WeightPerturbChance then --modify the weight slightly
				gene.weight = gene.weight + (math.random()-0.5) * step * 2
			elseif math.random() < WeightResetChance then --reset weight entirely
				gene.weight = math.random()*4 - 2
			end
		end
	end
end

MutationFunctions = {} --each mutation function, sorted by name

MutationFunctions.linkInputBox = function(genome, which) return linkMutate(genome, which, 0) end
MutationFunctions.linkBottomRow = function(genome, which) return linkMutate(genome, which, 1) end
MutationFunctions.linkLayers = function(genome, which) return linkMutate(genome, which, 2) end
MutationFunctions.linkRandom = function(genome, which) return linkMutate(genome, which, 3) end
MutationFunctions.node = nodeMutate
MutationFunctions.enable = function(genome, which) return enableDisableMutate(genome, which, true) end
MutationFunctions.disable = function(genome, which) return enableDisableMutate(genome, which, false) end
MutationFunctions.oscillation = oscillationMutate
MutationFunctions.nswitch = function(genome, which) if which>1 then nswitchMutate(genome,which-1) end end
MutationFunctions.weights = weightsMutate

function mutate(genome, which) --Mutates a genome's network based on all it's mutation rates
	for name,rate in pairs(genome.mutationRates) do --For each mutation type
		local p = rate --Number of times to do that mutation type
		if MutationFunctions[name] ~= nil then --is a mutation and not another rate like STEP
			while p > 0 do --Loop until all mutations are done
				if math.random() < p then --when p > 1 always do it, if it is a fraction then it is random
					if genome.genes[which] ~= nil then --if network exists
						MutationFunctions[name](genome,which) --call that rate
					end
				end
				p = p - 1 --reduce p
			end
		end
	end
end

function crossover(g1,g2)
	if g2.fitstate.fitness > g1.fitstate.fitness then
		g2, g1 = g1, g2 --switch so that g1 is always the greater fitness
	end
	local numnets = math.min(#g1.genes,#g2.genes) --take the smaller # of networks
    local child = newGenome(numnets)
	for n=1,numnets do --for each network to be calculated
		local i2 = {} --map from gene2 innovations to gene innovations
		for i,gene in ipairs(g2.genes[n]) do
			i2[gene.innovation] = gene
		end
		local i1 = {} --map from gene1 innovations to gene innovations
		for i,gene in ipairs(g1.genes[n]) do
			i1[gene.innovation] = gene
		end
		for i=1,#g1.oscillations[n] do
			child.oscillations[n][i] = g1.oscillations[n][i] --set oscillations to g1's oscillations
		end
        for i,gene1 in ipairs(g1.genes[n]) do --some version of every gene from best genome
            local gene2 = i2[gene1.innovation] --use innovations2 to find the copied gene in g1
			if gene2 ~= nil and math.random(1,2) == 1 and gene2.enabled then
				table.insert(child.genes[n], copyGene(gene2)) --if the copied gene exists pick randomly
			else
				table.insert(child.genes[n], copyGene(gene1)) --otherwise take the version from the best genome
			end
        end
		if n > 1 then
			child.networkswitch[n-1] = g1.networkswitch[n-1]
		end
		for i,gene in ipairs(g2.genes[n]) do
			if i1[gene.innovation] == nil and math.random() < 0.01 then --low chance for every gene in g2 only
				table.insert(child.genes[n], copyGene(gene)) --add those genes to the child as well
			end
		end
	end
	child.maxNeuron = math.max(g1.maxNeuron,g2.maxNeuron)
	return child
end

function rankGlobally() --Give each species a global rank, 1 is lowest Population is highest
    local globalRanks = {}
    for s = 1,#pool.species do
        local species = pool.species[s]
        for g = 1,#species.genomes do
            table.insert(globalRanks, species.genomes[g]) --Insert every genome into the table
        end
    end
    table.sort(globalRanks, function (a,b) --Sort based on fitness
        return (a.fitstate.fitness < b.fitstate.fitness)
    end)

    for g=1,#globalRanks do --Put position of each genome into that genome's data
        globalRanks[g].globalRank = g
    end
end

function calculatePoolStats() --Calculate avg and avg deviation of max fitness
	local total = 0 --Average of each species max fitness
    for i,species in ipairs(pool.species) do
        total = total + species.maxFitness
    end
    pool.averagemaxfitness = total / #pool.species
	
    local deviationtotal = 0 --Average distance between max fit and avg max fit
    for i,species in ipairs(pool.species) do
        deviationtotal = deviationtotal + math.abs(species.maxFitness - pool.averagemaxfitness)
    end
    pool.avgDeviation = deviationtotal / #pool.species
end

function calculateFitnessRank(species) --Returns a number for each species showing how well that species did
    local totalRank = 0

    for g=1,#species.genomes do --Total rank is equal to the average of the ranks of each genome
        local genome = species.genomes[g]
        totalRank = totalRank + genome.globalRank
    end
	totalRank = totalRank / #species.genomes 
	
	local multiplier = 1.0 --multiplier based on how many avg deviations from the mean the top fitness is
	if species.maxFitness < pool.averagemaxfitness - (pool.avgDeviation *2) then
		multiplier = 0.25
	elseif species.maxFitness < pool.averagemaxfitness - pool.avgDeviation then
		multiplier = 0.4
	elseif species.maxFitness > pool.averagemaxfitness + (pool.avgDeviation *3) then
		multiplier = 2.0
	elseif species.maxFitness > pool.averagemaxfitness + (pool.avgDeviation *2) then
		multiplier = 1.5
	end
	
	--Penalty for having multiple networks, to cancel out the benefit of consistency that they give
	local netMulti = math.pow(NetworkPenaltyOuter*math.pow(NetworkPenaltyInner,#species.genomes[1].networkswitch),#species.genomes[1].networkswitch)
	
	species.fitnessRank = totalRank * multiplier * netMulti
end

function totalPoolRank() --Sums each species fitness rank
    local total = 0
    for i,species in ipairs(pool.species) do
        total = total + species.fitnessRank
    end
    return total
end

function cullSpecies(cutToOne) --Cuts down each species, either to a percent based on bottleneck, or only to it's top genome.
	for i,species in ipairs(pool.species) do
		table.sort(species.genomes, function (a,b) --sorts the genomes by how well they did
            return (a.fitstate.fitness > b.fitstate.fitness)
        end)

        local percent = 0.5 --calculate percent
		local minpercent = math.max(0.15,0.5-0.1*pool.bottleneckloops) --min and max of oscillation
		local maxpercent = math.min(0.85,0.5+0.1*pool.bottleneckloops)
		
		local length = math.min(10,(5 + 2*pool.bottleneckloops)) --length used in pop oscillation

		local totallength = length*3 + TimeBeforePopOscil --total length of oscillation
		
		if pool.bottleneck < totallength/2 then --if in first half go up to max
			percent = minpercent + (0.1+maxpercent-minpercent)*(pool.bottleneck*2/totallength)
		else --if in second half go down to min
			percent = 0.1+maxpercent - (0.2+maxpercent-minpercent)*(pool.bottleneck*2/totallength-1)
		end
		
        local remaining = math.ceil(#species.genomes*percent) --number that remain
        if cutToOne or remaining < 1 then --always keep at least 1
            remaining = 1
        end
        while #species.genomes > remaining do --remove all that do not survive
            table.remove(species.genomes)
        end
    end
end

function breedChild(species) --makes an offspring from a species
	local child = {}
	if math.random() < CrossoverChance then --chance to cross over two genomes or just copy one
        g1 = species.genomes[math.random(1, #species.genomes)]
        g2 = species.genomes[math.random(1, #species.genomes)]
        child = crossover(g1, g2)
	else
        g = species.genomes[math.random(1, #species.genomes)]
        child = copyGenome(g)
    end
	
	local which = #child.genes -- mutate usually at the latest network
    if which > 1 and species.maxRightmost > 0 then --if there are multiple networks possibly modify one before most recent based on distance past that
        local mutatePrevNetworkChance = 0.5 + (child.networkswitch[#child.networkswitch]-species.maxRightmost)/500
        if math.random() < mutatePrevNetworkChance then
            which = #child.genes - 1
        end
    end
    mutate(child,which) --mutate the child in that network

    return child
end

function removeStaleSpecies() --update staleness and remove stale species
	local survived = {} --species that survive
	for i,species in ipairs(pool.species) do
		species.staleness = species.staleness + 1
		if species.staleness < MaxStaleness or species.maxFitness >= pool.secondFitness then --non stale species and top 2 species survive
			table.insert(survived,species)
		end
	end
	pool.species = survived
end

function removeWeakSpecies() 
	local survived = {} --species that survive
    local sum = totalPoolRank()
    for s = 1,#pool.species do
        local species = pool.species[s]
        local breed = math.floor(species.fitnessRank / sum * pool.population)
		
        if breed+1 >= 999/pool.population or species.fitnessRank > sum / #pool.species then
            table.insert(survived, species)
        end
    end
    pool.species = survived
end

function replaceNetwork(g1,g2) --replaces the most recent network of g1 with a random network of g2
	local child = copyGenome(g1) --mostly a copy of genome 1
	child.genes[#child.genes] = {} --clear out the most recent network
    which = math.random(1,#g2.genes) --pick a random network to copy from which
	for i,gene in ipairs(g2.genes[which]) do --copy each gene
		table.insert(child.genes[#child.genes], copyGene(gene))
	end
    return child
end	

function writescene(scene)
	local f = io.open('currentscene.txt','w')
	if scene == 1 then
		f:write("1")
	elseif scene == 2 then
		f:write("2")
	else
		f:write("3")
	end
	f:close()
end

function writetable(file,tbl) --writes a string of a table to a file
	function tablestring(a)
		if type(a)=='number' then
			local s = string.gsub(tostring(a),",",".")
			file:write(s)
		elseif type(a)=='boolean' then
			file:write(tostring(a))
		elseif type(a)=='string' then
			file:write('"')
			for i=1,string.len(a) do
				local c = string.sub(a,i,i)
				if c=="\n" then
					file:write("\\n")
				else
					local s = string.gsub(c,'\\','\\\\')
					file:write(s)
				end
			end
			file:write('"')
		else
			file:write('{')
			for key,value in pairs(a) do
				file:write('[')
				tablestring(key)
				file:write(']=')
				tablestring(value)
				file:write(',')
			end
			file:write('}')
		end
	end
	tablestring(tbl)
end
savgx={0}
function searchstaff()
	getPositions()
	local marioScreenX = marioScreenX
	local koopalingDefeated = koopalingDefeated
	local cont = {}
	cont['B'] = true
	cont['down'] = false
	if marioScreenX < 122 then
		cont['right'] = true
		
	else
		cont['left'] = true
	end
	if marioScreenX - savgx[1] < 5 then
		cont['A'] = true
		table.insert(savgx,0)
	else
		cont['A'] = false
	end
	table.insert(savgx,marioScreenX)
	if #savgx > 120 then
		table.remove(savgx,1)
	end
	joypad.set(Player,cont)
	coroutine.yield()
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function saveGenome(name,winner) --saves a species containing the winning genome to a file
	local lvlf=io.open("level.txt","r")
	local lvl = lvlf:read("*line")
	lvlf:close()
	local levelname = lvl --name of level in the file name
	local file = io.open("backups"..dirsep..levelname..dirsep..name..".lua","w")
	spec = pool.species[pool.currentSpecies]
	genome = spec.genomes[pool.currentGenome]
	genome.nick = spec.nick
	genome.gen = pool.generation
	genome.s = pool.currentSpecies
	genome.g = pool.currentGenome
	print("backups"..dirsep..levelname..dirsep..name..".lua")
	if not winner then
		if boss then
			file:write("boss=true\nloadedgenome=")
		else
			file:write("boss=false\nloadedgenome=")
		end
	else
		file:write("loadedgenome=")
	end
	writetable(file,genome)
	file:close()
	if winner then
		file = io.open("backups"..dirsep.."winners.txt","a")
		file:write("backups"..dirsep..levelname..dirsep..name..".lua\n")
		file:close()
	else
		table.insert(pool.breakthroughfiles,"backups"..dirsep..levelname..dirsep..name..".lua")
	end
end

function savePool(filename) --saves the pool into a file
	local file = io.open(filename,"w")
	file:write("pool=")
	writetable(file,pool)
	file:close()
end

function loadPool(filename) --loads the pool from a file
	dofile(filename)
	ProgramStartTime = ProgramStartTime - pool.realTime
end

maxNewGenProgress = -1
function newgenProgress(progress) --draws a progress bar for new gen calculation
	if math.floor(progress)>maxNewGenProgress then
		maxNewGenProgress=math.floor(progress)
		text = "Calculating Generation"
		white = toRGBA(0xFFFFFFFF)
		blue = toRGBA(0xFF003FFF)
		black = toRGBA(0xFF000000)
		gui.drawbox(38,98,218,122,black,blue)
		drawtext.draw(text,40,100,white,black)
		prog = "["
		for i=1,progress do prog=prog.."#" end
		for i=progress,19 do prog=prog.." " end
		prog=prog.."]"
		drawtext.draw(prog,40,112,blue,black)
		coroutine.yield()
	end
end

function newGeneration() --runs the evolutionary algorithms to advance a generation
	local mfloor = math.floor
	maxNewGenProgress = -1
	newgenProgress(0)
	autoturbo()
	generationTime = pool.realTime
	
	os.remove("backups"..dirsep..levelname..dirsep.."gen"..(pool.generation+1)..".lua")
	savePool("backups"..dirsep..levelname..dirsep.."gen"..pool.generation..".lua")
	
    local length = math.min(10,(5 + 2*pool.bottleneckloops)) --Length used for the population oscillation
	local targetPop = math.min(900,500 + 100*pool.bottleneckloops) --population to rise to
    local targetPopLower = math.min(300,600 - targetPop/2) --population to fall back down to
    local currentPopLower = math.min(300,targetPopLower+50) --population starting at
	
	if pool.bottleneck <= TimeBeforePopOscil and pool.bottleneckloops == 0 then --decrease very rapidly after a bottleneck reset
		pool.population = math.max(math.floor(pool.population * 0.8),300)
	end
	
	if pool.bottleneck > TimeBeforePopOscil then --perform the oscillation
        if pool.bottleneck < TimeBeforePopOscil + length then --increase up
            pool.population = currentPopLower + math.floor((targetPop - currentPopLower)/length*(pool.bottleneck-TimeBeforePopOscil))
        elseif pool.bottleneck == TimeBeforePopOscil + length then --peak
            pool.population = targetPop
        elseif pool.bottleneck <= TimeBeforePopOscil + length*3 then --go back down
            pool.population = targetPopLower + math.floor((targetPop - targetPopLower)/length/2*(TimeBeforePopOscil+length*3-pool.bottleneck))
        end
        if pool.bottleneck == TimeBeforePopOscil + length*3 then --go to next loop
            pool.bottleneck = 0
            pool.bottleneckloops = pool.bottleneckloops + 1
        end
    end
	newgenProgress(1)
	cullSpecies(false) --cut down each species
	newgenProgress(2)
	rankGlobally() --rank all genomes
	newgenProgress(3)
	removeStaleSpecies() --remove stale species
	newgenProgress(4)
	calculatePoolStats() --find pool maxes avg/deviation
	newgenProgress(5)
	for i,species in ipairs(pool.species) do --find the fitness rank for each species
        calculateFitnessRank(species)
    end
	newgenProgress(6)
	removeWeakSpecies() --remove species without a good fitness rank
	newgenProgress(7)
	local rankSum = totalPoolRank() --used to see how good a fitness rank is in comparison to everything
	
	local children = {} --new genomes that will be added this generation
	
	for i,species in ipairs(pool.species) do --generate children for each species
        local breed = mfloor(species.fitnessRank / rankSum * pool.population) - 1 --num of children to generate
        for j=1,breed do
			table.insert(children, breedChild(species))
        end
		newgenProgress(7+3*i/#pool.species)
    end
	newgenProgress(10)
	local interbreedchance = BaseInterbreedChance --base interbreed chance
    if pool.generation > 5 then --do not reduce interbreed at very beginning, we want lots of it in first 5 gens
		--reduce interbreed when there are lots of species with low average size
		interbreedchance = interbreedchance * math.pow(1/InterbreedCutoff-math.min(1/InterbreedCutoff,#pool.species/pool.population),InterbreedDegree)
	end
	
	local replacechance = interbreedchance/3 --replacements rarer than interbreeds
	
	local minnetwork = 10000 --minimum number of networks a species eligible for a NS has
	local netspecies = {} --list of species eligible for a NS with min networks
	
	for i,species in ipairs(pool.species) do --apply interbreed chance to each species
		if math.random() < interbreedchance then
			--pick which species to breed with, proportional to fitness rank
			local ibcheck = math.random() * rankSum
			for j,species2 in ipairs(pool.species) do
				ibcheck = ibcheck - species2.fitnessRank --reduce by the fitness rank
				if ibcheck < 0 then --the higher it is reduced by greater chance it goes below 0 this time
					table.insert(children, crossover(species.genomes[1],species2.genomes[1])) --interbreed
					break
				end
			end
		end
		
		if math.random() < replacechance then
			--pick which species to get network from
			local species2 = pool.species[math.random(1,#pool.species)]
			table.insert(children, replaceNetwork(species.genomes[1],species2.genomes[1])) --replace network
		end
		
		local numnet = #species.genomes[1].genes --number of networks
		if math.min(numnet,3) <= pool.bottleneckloops and numnet <= minnetwork and species.maxFitness + 150 > pool.maxFitness then
			if numnet < minnetwork then --even smaller network found, clear old array
				minnetwork = numnet
				netspecies = {}
			end
			table.insert(netspecies,species)
		end
		newgenProgress(10+3*i/#pool.species)
	end
	
	if #netspecies > 0 then --at least one species eligible for a network switch
		local species = netspecies[math.random(1,#netspecies)] --pick random eligible species
		local child = copyGenome(species.genomes[1]) --make a copy of best genome
		local switchloc = species.maxRightmost - 150 - 150*math.random() --pick a switch location
		table.insert(child.networkswitch,switchloc)
		table.insert(child.oscillations,{})
		for i=1,#InitialOscillations do
			child.oscillations[#child.oscillations][i] = InitialOscillations[i]
		end
		table.insert(child.genes,{})
		
		table.insert(children,child) --add child
		
		mutate(child,#child.genes)
		mutate(child,#child.genes)
		
		table.sort(child.networkswitch, function(a,b) --make sure network splits are in order
			return (a < b)
		end)
	end
	newgenProgress(13)
	while #children+#pool.species < pool.population do --fill from random species
		table.insert(children, breedChild(pool.species[math.random(1, #pool.species)]))
	end
	newgenProgress(14)
	cullSpecies(true) --remove all but the best of each species
	newgenProgress(15)
	for i,child in ipairs(children) do --add all children to species
		addToSpecies(child)
		newgenProgress(15+3*i/#children)
	end
	newgenProgress(18)
	for i,species in ipairs(pool.species) do --limit size of species
		local limit = pool.population/12 --cap on the species size
		if species.maxFitness >= pool.secondFitness then --if top two then larger cap
			limit = pool.population/7
		end
		while #species.genomes > limit do --remove
			table.remove(species.genomes)
		end
	end
	
	pool.generation = pool.generation + 1
	pool.bottleneck = pool.bottleneck + 1
	newgenProgress(19)
	savePool("backups"..dirsep.."current.lua")
	newgenProgress(20)
end

Ranges = {
['0-3-3-1']= {{yrange={}, xrange={min=360, max=480}, timeout=900, forcebutton={A=false}}},
["1-2-3-0"]= {{yrange={}, xrange={min=1173, max=1300}, coeffs={x=1,y=2,c=0}}, {yrange={}, xrange={min=1300, max=1303}, resetoffset=true}, {yrange={min=10, max=95}, xrange={min=1281, max=1450}, coeffs={x=0,y=0,c=0}, P=0},{yrange={min=10, max=36}, xrange={min=1181, max=1290}, coeffs={x=0,y=0,c=0}, P=0}},
["1-6-2-0"]= {{yrange={}, xrange={min=2167, max=2300}, timeout=900}, {yrange={min=80,max=96}, xrange={min=2230, max=2249}, coeffs={x=1,y=-1,c=700}},{yrange={min=96,max=112}, xrange={min=2220, max=2279}, coeffs={x=1,y=-1,c=600}},{yrange={min=112,max=128}, xrange={min=2230, max=2249}, coeffs={x=1,y=-1,c=500}},{yrange={min=128,max=144}, xrange={min=2230, max=2249}, coeffs={x=1,y=-1,c=400}}, {yrange={min=144,max=160}, xrange={min=2256,max=2272},coeffs={x=1,y=-1,c=250}},{yrange={}, xrange={min=2272,max=2300},coeffs={x=0,y=0,c=0}},{yrange={min=170}, xrange={min=2200,max=2300},coeffs={x=0,y=0,c=0}},{yrange={min=80,max=90}, xrange={min=2274, max=2300}, area="pipe"}},
["1-6-2-pipe"]= {{yrange={}, xrange={min=2167, max=2300}, timeout=900}, {yrange={min=80,max=96}, xrange={min=2230, max=2249}, coeffs={x=1,y=-1,c=700}},{yrange={min=80,max=96}, xrange={min=2230, max=2240},forcebutton={down=true,left=true,right=false}},{yrange={min=80,max=96}, xrange={min=2240, max=2300},forcebutton={left=true,right=false}}},
}

function fitness(fitstate) --Returns the distance into the level - the non-time component of fitness
	local coeffs={x=1,y=1,c=0} --position base coefficients
	local marioX = marioX
	local marioY = marioY
	local marioYVel = marioYVel
	local marioScore = marioScore
	local marioScreenX = marioScreenX
	local marioPower = marioPower
	local boss = boss
	local battle = battle
	local marioActive = marioActive
	local scrollBonus = scrollBonus
	local mmax = math.max
	local mfloor = math.floor
	local mabs = math.abs
	local card_x = card_x
	local card_y = card_y
	local lspecialBonus = specialBonus
	local CardDistance = cardDistance
	local levelname = levelname
	local pStatus = math.sqrt(memory.readbyte(0x03DD))

	local ranges = Ranges[levelname .. "-" .. fitstate.area]
	--[[local levelstring = "" --string to represent the level and subworld, to index Ranges
	if LostLevels == 1 then levelstring = "LL" end
	levelstring = levelstring .. currentWorld .. "-" .. currentLevel .. " " .. fitstate.area
	local ranges = Ranges[levelstring] ]]
	if boss then
		basetimeout = roottimeoutboss
	else
		basetimeout = roottimeout
	end
	forcebutton = nil
	if ranges ~= nil then
		for r=1,#ranges do --for each special fitness range
			local range = ranges[r]
			if (range.xrange.min == nil or marioX > range.xrange.min) and (range.xrange.max == nil or marioX <= range.xrange.max) then --in x range
				if (range.yrange.min == nil or marioY >= range.yrange.min) and (range.yrange.max == nil or marioY < range.yrange.max) then --in y range
					if range.coeffs ~= nil then
						coeffs = range.coeffs --replace default coefficients
					end
					if range.P ~= nil then
						pStatus = pStatus * range.P
					end
					if range.area ~= nil then
						fitstate.area = range.area
					end
					if range.timeout ~= nil then
						basetimeout = range.timeout
					else
						basetimeout = 120
					end
					if range.turbo ~= nil then
						if range.turbo then
							currentTurbo = true
							emu.speedmode("turbo")
						else
							currentTurbo = false
							emu.speedmode("normal")
						end
					end
					if range.forcebutton ~= nil then
						forcebutton = range.forcebutton
					else
						forcebutton = nil
					end
					if range.resetoffset ~= nil then
						fitstate.offset = fitstate.rightmost - fitstate.position
					end
				end
			end
		end
	end
	if marioXVel ~= 0 and not (marioYVel > 0 and marioYVel < 70) then
		pBonus = pBonus + pStatus/5
	end
	local distance
	if boss or battle then
		for i,sprite in ipairs(sprites) do
			if sprite.state ~= 0 then
				local distx = math.floor((sprite.x - marioX)/16 + 0.5)
				distance = 16 - mabs(distx)
			end
			if distance == nil then
				distance = 0
			end
		end
	end
	local currentCardDistance = math.sqrt(mabs(card_x-marioX)*mabs(card_y-marioY))/50
	if currentCardDistance < CardDistance and not battle and not boss then
		CardDistance = currentCardDistance
		cardDistance = CardDistance
		if CardDistance < 0.4 then
			--roottimeout = 600
			basetimeout = 600
		end
		
	end
	if CardDistance == 0 then
		CardDistance = 0.1
	end
	fitstate.position = coeffs.x*marioX + coeffs.y*marioY + coeffs.c --set the position value
	if marioActive then
		prevPower = marioPower
		if not fitstate.lastActive then --update offset
			fitstate.area = memory.readbyte(0x03DF)
			--print(500/CardDistance)
			fitstate.offset = fitstate.rightmost - fitstate.position
			--print(fitstate.offset)
			--print("adjusted offset: " .. fitstate.offset)
			if battle then fitstate.offset = - (marioScore * 3 + distance * 10) end
			getTileset()
		end
		fitstate.lastright = fitstate.position --update lastright when in control of mario
		if scrollBonus > 0 and scrollBonus == prevScrollBonus then
			fitstate.timeout = fitstate.timeout + 1
			--endscroll = true
			--print(scrollBonus)
			--print(prevScrollBonus)
		elseif boss then
			if marioScore == prevscore then
				fitstate.timeout = fitstate.timeout + 1 --increase timeout
			else
				fitstate.timeout = 0
			end
			prevscore = marioScore
		elseif scrollBonus > 0 then
			fitstate.timeout = 0
			endscroll = false
		elseif battle then
			if marioScore == prevscore then
				fitstate.timeout = fitstate.timeout + 1 --increase timeout
			else
				fitstate.timeout = 0
			end
			if distance > 9 then
				basetimeout = 600
			else
				basetimeout = 120
			end
			prevscore = marioScore
			prevscreenx = marioScreenX
		else
			fitstate.timeout = fitstate.timeout + 1 --increase timeout
		end
		if fitstate.timeout > basetimeout then --if has been idle for a second, start penalizing
			fitstate.timepenalty = fitstate.timepenalty + 1
			endscroll = true
		end		
		if pipe then
			pipe = false
		end
		--print("scrollBonus: " .. scrollBonus)
		--print("prev: " .. prevScrollBonus)
		prevScrollBonus = scrollBonus
	else
		fitstate.position = fitstate.lastright --freeze position when not in control of mario
		if prevPower == marioPower then
			if scrollBonus >0 and not pipe then
				specialBonus = specialBonus + 200
				lspecialBonus = specialBonus
				--fitstate.fitness = scrollBonus + fitstate.rightmost*0.6 + 150
				fitstate.rightmost = fitstate.fitness
				scrollBonus = 0
				basescroll = 0
				memory.writebyte(0x7A0C,0)
				
				--fitstate.rightmost = fitstate.rightmost + fitstate.offset
				pipe = true
				--pipeflip = true
				--print("pipe")
				--fitstate.rightmost = fitstate.offset + 0.6*fitstate.rightmost
			
			elseif scrollBonus >0 and pipe then
				scrollBonus = 0
				basescroll = 0
				memory.writebyte(0x7A0C,0)
			end
			
		else
			marioActive = true
		end
	end
	fitstate.lastActive = marioActive
	if not (marioYVel > 0 and marioYVel < 70) and fitstate.position + fitstate.offset > fitstate.rightmost then
		fitstate.timeout = mmax(0,fitstate.timeout + (fitstate.rightmost - fitstate.position - fitstate.offset)*2) --decrease timeout
		fitstate.rightmost = fitstate.position + fitstate.offset --rightmost is maximum that the position+offset has ever been
		--fitstate.savedtimepenalty = fitstate.timepenalty DISABLED FOR AUTOSCROLLER TEST
	end
	if boss then
		fitstate.fitness = marioScore + fitstate.frame + distance
	elseif battle then
		fitstate.fitness = marioScore * 3 + distance * 10 + fitstate.offset
	elseif scrollBonus > 0 then
		fitstate.fitness = scrollBonus + fitstate.rightmost*0.6 + pBonus/10
		--print("scrollBonus")
		-- if lspecialBonus > 0 then
			-- print("scrollBonus: " .. scrollBonus)
			-- print("marioX: " .. marioX)
		-- end
	else
		fitstate.fitness = fitstate.rightmost - mfloor(fitstate.savedtimepenalty / 2) + WhiteblockBonus + lspecialBonus + 100/CardDistance +pBonus/10 + powerupFitness * math.min(marioPower, 2)  --+ marioScore --return fitness
		-- if fitstate.offset ~= -104 then
			-- print("after pipe fitness: " .. fitstate.fitness)
		-- end
		--print("right: " .. fitstate.rightmost .. " penalty: " .. mfloor(fitstate.savedtimepenalty / 2) .. " whiteblock: " .. WhiteblockBonus .. " special: " .. lspecialBonus .. " card: " .. 500/CardDistance .. " pBonus: " .. pBonus/10)
	end
end



function autoturbo() --Determines the automatic turbo 
	local pool = pool
	if (pool.realTime - pool.lastbreaktime) > 14400 then
		if (pool.realTime - generationTime) > 5400 then
			TurboMax = TurboMax + 30
			autoTurbo = TurboMax
		elseif (pool.realTime - generationTime) < 3600 and autoTurbo == TurboMax and autoTurboCounter > 1 then
			TurboMax = TurboMax - 50
			if TurboMax < 0 then
				TurboMax = 0
			end
			autoTurbo = TurboMax
		elseif (pool.realTime - generationTime) < 3600 and autoTurbo == TurboMax then
			autoTurboCounter = autoTurboCounter + 1
		else
			autoTurboCounter = 0
		end
	end
	if (pool.realTime - pool.lastbreaktime) < 43200 then
		automaticturboswitch = 0
	elseif (pool.realTime - pool.lastbreaktime) > 43200 and automaticturboswitch == 0 then
		local increase = math.ceil(pool.maxFitness / 10)
		if TurboMax < increase then
			TurboMax = increase
			autoTurbo = increase
		end
		automaticturboswitch = 1
	elseif (pool.realTime - pool.lastbreaktime) > 86400 and automaticturboswitch == 1  then
		local increase = math.ceil(pool.maxFitness / 5)
		if TurboMax < increase then
			TurboMax = increase
			autoTurbo = increase
		end
		automaticturboswitch = 2
	elseif (pool.realTime - pool.lastbreaktime) > 172800 and automaticturboswitch == 2 then
		local increase = math.ceil(pool.maxFitness / 3)
		if TurboMax < increase then
			TurboMax = increase
			autoTurbo = increase
		end
		automaticturboswitch = 3
	end
end

function playGenome(genome) --Run a genome through an attempt at the level
	local mmax = math.max
	local boss = boss
	local Replay = Replay
	local FramesPerEval = FramesPerEval
	if boss then
		savestate.load(bosssavestateObj) --load boss savestate
	else
		savestate.load(savestateObj) --load savestate
	end
	--local falseload = false
	--[[while memory.readbyte(0x0787) == 0 do --wait until the game has fully loaded in mario
		coroutine.yield()
		falseload = true
	end
	if falseload then --move a savestate forward so that it doesn't have any load frames
		local groundtime = 0 --must not be falling for a certain time to be on ground
		while groundtime < 10 do --wait for mario to hit the ground
			coroutine.yield()
			if memory.readbyte(0x009F) == 0 then
				groundtime = groundtime + 1
			else
				groundtime = 0
			end
		end
		savestate.save(savestateObj)
	end]]--
	
	local fitstate = genome.fitstate
	fitstate.frame = 0 --frame counter for the run
	fitstate.position = 0 --current position
	fitstate.rightmost = 0 --max it has gotten to the right
	fitstate.offset = 0 --offset to make sure fitness doesn't jump upon room change
	fitstate.lastright = 0 --last position before a transition.cancel()
	fitstate.lastActive = false --mario's state the previous frame (to check state transitions)
	fitstate.fitness = 0 --current fitness score
	fitstate.timeout = 0 --time increasing when mario is idle, kills him if it is too much
	fitstate.timepenalty = 0 --number of frames mario was too idle, to subtract from his fitness
	--fitstate.area = "Level"
	--fitstate.lastarea = ""
	fitstate.savedtimepenalty = 0 --does not save time penalty until mario moves forward
	basescroll = 0
	prevScrollBonus = scrollBonus
	marioPrevAutoscroll = 0
	specialBonus = 0
	cardDistance = 9999
	pBonus = 0
	lockBound = false
	getPositions()
	
	specialBonus = - scrollBonus - 500/cardDistance - powerupFitness * math.min(marioPower, 2)
	local nsw = 1 --network switch
	generateNetwork(genome) --generate the network
	local controller = {} --inputs to the controller
	getTileset()
	fitstate.area = memory.readbyte(0x03DF)
	while true do --main game loop
		local koopalingDefeated = koopalingDefeated
		local marioMusic = marioMusic
		local manualControl = keyboardInput()
		local ManualInput = ManualInput
		local marioX = marioX
		local card_x = card_x
		local marioScreenY = marioScreenY
		local marioYVel = marioYVel
		--Get inputs to the network
		
		if fitstate.frame % FPS == 0 and not Replay then
			timerOutput()
		end
		
		if fitstate.frame % FramesPerEval == 0 then
			local inputs = getInputs()
			--Find the current network to be using
			local nscompare = fitstate.rightmost
			nsw = 1
			for n=1,#genome.networkswitch do
				if nscompare > genome.networkswitch[n] then
					nsw = n+1
				end
			end
			--Put outputs to the controller
			if marioX > card_x -74 and marioX < card_x -64 then
				forcebutton = {right=true,A=false,B=true}
			elseif marioX <= card_x-8 and marioX >= card_x -64 then
				forcebutton = {right=true,A=true,B=true}
			elseif marioX > card_x+8 then
				forcebutton = {left=true,right=false}
			end
			controller = evaluateNetwork(genome.networks[nsw], inputs, genome.oscillations[nsw], fitstate.frame)
		else
			getPositions()
		end
		
		if ManualInput then
			joypad.set(Player,manualControl)
		else
			if fitstate.frame % (FramesPerEval*2) == 0 then
				if (marioPower == 3 or marioPower == 5) and controller['A'] then
					if memory.readbyte(0x03DD) == 127 then
						controller['A'] = false --allows mario to fly with tanooki suit. this type of network would otherwise not be capable of switching that fast
					end
				end
			end
			joypad.set(Player,controller)
		end
		
		fitness(fitstate) --update the fitness
		if pool.generation == 0 and not Replay then
			TurboMax = 1
		elseif TurboMax == 1 then
			TurboMax = 0
		end
		local turbocompare = mmax(0,fitstate.rightmost)
		if CompleteAutoTurbo or (turbocompare >= TurboMin and turbocompare < TurboMax and pool.species[pool.currentSpecies].turbo) then
			if not currentTurbo then
				currentTurbo = true
				emu.speedmode("turbo")
			end
		else
			if currentTurbo then
				currentTurbo = false
				emu.speedmode("normal")
			end
		end
			
		--Display the GUI
		displayGUI(genome.networks[nsw], fitstate)
		--Advance a frame
		coroutine.yield() --coroutine.yield()
		fitstate.frame = fitstate.frame + 1
		
		--exit if dead or won
		if memory.readbyte(0x00EE) == 75 or marioOutOfBound then --if he dies to an enemy or a pit
			if Replay then
				genome.networks = {}
				return false
			end
			pool.attempts = pool.attempts + 1
			pool.deaths = pool.deaths + 1
			addToHistogram()
			deathCounterOutput()
			for frame=1,FramesOfDeathAnimation do
				displayGUI(genome.networks[nsw], fitstate)
				coroutine.yield() --coroutine.yield()
			end
			genome.networks = {} --reset networks to save on RAM
			pool.totalTime = pool.totalTime + fitstate.frame
			turboOutput()
			timerOutput()
			return false
		end
		if fitstate.timeout > fitstate.rightmost/3+basetimeout and not ManualInput then --timeout threshold increases throughout level. kill if timeout is enabled and timer is not frozen
			genome.networks = {} --reset networks to save on RAM
			if Replay then return false end
			pool.attempts = pool.attempts + 1
			addToHistogram()
			deathCounterOutput()
			turboOutput()
			timerOutput()
			pool.totalTime = pool.totalTime + fitstate.frame
			return false
		end
		if memory.readbyte(0x0014) == 1 then --if he beats the level
			print("beat level")
			genome.fitstate.fitness = genome.fitstate.fitness + 1000
			genome.networks = {} --reset networks to save on RAM
			if Replay then return true end
			pool.totalTime = pool.totalTime + fitstate.frame
			addToHistogram()
			TurboMin = 0
			TurboMax = 0
			turboOutput()
			battle = false
			return true
		end
		if (marioMusic == 0x50 or marioMusic == 0xB0) and not boss then
			print('activate final state')
			genome.fitstate.fitness = genome.fitstate.fitness + 1000
			genome.networks = {} --reset networks to save on RAM
			if Replay then return true end
			pool.totalTime = pool.totalTime + fitstate.frame
			addToHistogram()
			TurboMin = 0
			TurboMax = 0
			turboOutput()
			--print('playboss')
			memory.writebyte(0x0715,0) --set score to 0
			memory.writebyte(0x0716,0)
			memory.writebyte(0x0717,0)
			bosssavestateObj = savestate.object(savestateSlotBOSS)
			savestate.save(bosssavestateObj)
			savestate.persist(bosssavestateObj)
			startboss = true
			return false
		end
		if (marioMusic ~= 0x50 and marioMusic ~= 0xB0 and koopalingDefeated == 0) and boss then
			genome.fitstate.fitness = genome.fitstate.fitness + 1000
			genome.networks = {} --reset networks to save on RAM
			for x=1,800 do
				coroutine.yield()
			end
			
			if Replay then return true end
			pool.totalTime = pool.totalTime + fitstate.frame
			addToHistogram()
			TurboMin = 0
			TurboMax = 0
			turboOutput()
			return true
		end
		if koopalingDefeated > 0 and boss then
			print("second")
			-- print(marioMusic)
			-- print(koopalingDefeated)
			genome.fitstate.fitness = genome.fitstate.fitness + 1000
			genome.networks = {} --reset networks to save on RAM
			while koopalingDefeated == 1 do
				koopalingDefeated = memory.readbyte(0x07BD)
				coroutine.yield()
			end
			while koopalingDefeated == 2 do
				koopalingDefeated = memory.readbyte(0x07BD)
				searchstaff()
			end
			while koopalingDefeated > 1 do
				koopalingDefeated = memory.readbyte(0x07BD)
				coroutine.yield()
			end
			while kingconvo < 4 do
				getPositions()
				coroutine.yield()
			end
			if kingconvo == 4 then
				for a=1,60 do
					coroutine.yield()
				end
				joypad.set(Player,{A = true})
				coroutine.yield()
				joypad.set(Player,{A = false})
			end
			if Replay then return true end
			pool.totalTime = pool.totalTime + fitstate.frame
			addToHistogram()
			TurboMin = 0
			TurboMax = 0
			turboOutput()
			return true
		end
	end
end

function playSpecies(species,showBest) --Plays through all members of a species
	spindicatorOutput(species)
	local startGenome = 2 --which genome to start showing from
	local oldBest = 0
	if showBest or not species.genomes[1].fitstate.fitness then
		startGenome = 1
		oldBest = species.maxFitness --used to make sure staleness does not reset every run if showBest is toggled on always
		species.maxFitness = 0
		species.maxRightmost = 0
	end
	speciesDataOutput()
	for g=startGenome,#species.genomes do --loop through each genome
		local genome = species.genomes[g]
		pool.currentGenome = g
		local won = playGenome(genome) --test the genome
		if genome.fitstate.fitness + 30 > pool.maxFitness then --if it has gotten very close to the max
			pool.maxCounter = pool.maxCounter + 1
		end
		if genome.fitstate.fitness > pool.maxFitness then --if the fitness is the new best
			if species.gsid ~= pool.bestSpecies then --change the second best if the current best is a different species
				pool.secondFitness = pool.maxFitness
			end
			if genome.fitstate.fitness > pool.maxFitness + MajorBreakFitness or genome.fitstate.fitness > pool.lastMajorBreak + MajorBreakFitness*4 then
				--Counts as a major breakthrough
				pool.lastMajorBreak = genome.fitstate.fitness
				pool.bottleneck = 0
				pool.bottleneckloops = 0
				pool.lastbreaktime = pool.realTime
			end
			pool.bestSpecies = species.gsid --update the best species number
			pool.maxFitness = genome.fitstate.fitness --update the best fitness
			writeBreakthroughOutput()
		elseif genome.fitstate.fitness > pool.secondFitness then --if the fitness is the new second best
			if species.gsid ~= pool.bestSpecies then --change the second best if this is not the current best species
				pool.secondFitness = genome.fitstate.fitness
			end
		end
		--print("end calculation fitness: " .. genome.fitstate.fitness)
		if genome.fitstate.fitness > species.maxFitness then --update the species max fitness
			species.maxFitness = genome.fitstate.fitness
			species.breakthroughX = marioX
			species.breakthroughZ = genome.fitstate.area
			spindicatorOutput(species)
			if genome.fitstate.fitness > oldBest then
				species.staleness = 0 --reset the staleness
			end
		end
		if genome.fitstate.rightmost > species.maxRightmost then --update the species max right
			species.maxRightmost = genome.fitstate.rightmost
		end
		if startboss then
			saveGenome("winner",true)
			startboss = false
			PlayBoss()
			won = true
		end
		pool.current = pool.current +1
		pool.total = pool.total + genome.fitstate.fitness
		pool.average = math.ceil(pool.total/pool.current)
		if won then return true end --return true if we won
	end
	return false --return false otherwise
end

function playGeneration(showBest) --Plays through the entire generation
	local NumberWinner = numberWinner
	pool.maxCounter = 0
	pool.current = 0
	pool.total = 0
	for s=1,#pool.species do
		local species = pool.species[s]
		
		pool.currentSpecies = s
		if s > NumberWinner and NumberWinner ~= -1 then
			if not currentTurbo then
				currentTurbo = true
				emu.speedmode("turbo")
			end
			numberWinner = -1
		end
		if playSpecies(species,showBest) then
			return true
		end
	end
	return false
end

--File Outputs
function deathCounterOutput()
	fileDeaths = io.open("deaths.txt","w")
	fileDeaths:write(pool.deaths)
	fileDeaths:close()
	fileAttempts = io.open("attempts.txt","w")
	fileAttempts:write(pool.attempts)
	fileAttempts:close()
end

function speciesDataOutput()
	local species = pool.species[pool.currentSpecies]
	speciesdata = "GSID: "..species.gsid.." SMax: "..math.floor(species.maxFitness).." Stale: "..species.staleness
	if species.nick ~= "" then
		speciesdata = speciesdata.." Nick: "..species.nick
	end
	fileSData = io.open("speciesdata.txt","w")
	fileSData:write(speciesdata)
	fileSData:close()
end

function mapupdate()
	io.open("../mapupdate.txt","w"):close()
end

function mapupdateHist()
	local f = io.open("../mapupdate.txt","w")
	f:write("hist")
	f:close()
end

function spindicatorOutput(species)
	fileIPos = io.open("spindicatorpos.txt","w")
	fileIPos:write(species.breakthroughX.." "..species.breakthroughZ)
	fileIPos:close()
	pcall(mapupdate)
end

function indicatorOutput()
	fileIPos = io.open("indicatorpos.txt","w")
	fileIPos:write(pool.breakthroughX.." "..pool.breakthroughZ)
	fileIPos:close()
	pcall(mapupdate)
end

function addToHistogram()
	local i = math.floor(marioX/32)
	key = i.." "..pool.species[pool.currentSpecies].genomes[pool.currentGenome].fitstate.area
	if not pool.maphistogram[key] then
		pool.maphistogram[key] = 0
	end
	pool.maphistogram[key] = pool.maphistogram[key] + 1
end

function histogramOutput()
	fileHistogram = io.open("histogram.txt","w")
	for key,count in pairs(pool.maphistogram) do
		fileHistogram:write(key.." "..count.."\n")
	end
	fileHistogram:close()
end

function writeBreakthroughOutput()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	info = tostring(pool.generation)
	for i=1 ,4-string.len(info) do info=info.." " end
	info = info..tostring(pool.currentSpecies)
	for i=1,9-string.len(info) do info=info.." " end
	info = info..tostring(pool.currentGenome)
	for i=1,13-string.len(info) do info=info.." " end
	info = info..tostring(species.gsid)
	for i=1,18-string.len(info) do info=info.." " end
	info = info..tostring(math.floor(genome.fitstate.fitness))
	for i=1,23-string.len(info) do info=info.." " end
	local seconds = pool.realTime
	local minutes = math.floor(seconds/60)
	seconds = seconds - minutes*60
	local hours = math.floor(minutes/60)
	minutes = minutes - hours*60
	local days = math.floor(hours/24)
	hours = hours - days*24
	if pool.realTime < 3600 then
		info=info..minutes.."m"..seconds.."s"
	elseif pool.realTime < 86400 then
		info=info..hours.."h"..minutes.."m"
	else
		info=info..days.."d"..hours.."h"
	end
	pool.history=pool.history..info.."\n"
	fileFTracker = io.open("fitnesstracker.txt","w")
	fileFTracker:write(pool.history)
	fileFTracker:close()
	
	pool.breakthroughX = marioX
	pool.breakthroughZ = genome.fitstate.area
	if boss then
		saveGenome("Boss-G"..pool.generation.."s"..pool.currentSpecies.."g"..pool.currentGenome,false)
	else
		saveGenome("G"..pool.generation.."s"..pool.currentSpecies.."g"..pool.currentGenome,false)
	end
	
	indicatorOutput()
end

function levelNameOutput()
	getPositions()
	fileLevel = io.open("level.txt","w")
	
	fileLevel:write(levelname)
	fileLevel:close()
end

function turboOutput()
	fileTurbo = io.open("turbo.txt","w")
	if TurboMin == 0 then
		fileTurbo:write("T="..TurboMax)
	else
		fileTurbo:write("T="..TurboMin.."\nto "..TurboMax)
	end
	fileTurbo:close()
end

function twoDigit(num)
	str = tostring(num)
	if string.len(str) == 1 then
		str = "0"..str
	end
	return str
end

function numToTime(seconds)
	local minutes = math.floor(seconds/60)
	seconds = seconds - minutes*60
	local hours = math.floor(minutes/60)
	minutes = minutes - hours*60
	local days = math.floor(hours/24)
	hours = hours - days*24
	return days.."d "..twoDigit(hours)..":"..twoDigit(minutes)..":"..twoDigit(seconds)
end

function timerOutput()
	fileRealTime = io.open("realtime.txt","w")
	fileGameTime = io.open("gametime.txt","w")
	pool.realTime = os.difftime(os.time(), ProgramStartTime)
	fileRealTime:write(numToTime(pool.realTime))
	fileGameTime:write(numToTime(math.floor(pool.totalTime/FPS)))
	fileRealTime:close()
	fileGameTime:close()
end

function fitnessDataOutput()
	rankGlobally()
	local fitnesses = {}
	local genAvg = 0
	local smaxAvg = 0
	local minGsid = 1000000
	local maxGsid = 0
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			fitnesses[genome.globalRank] = genome.fitstate.fitness
			genAvg = genAvg + genome.fitstate.fitness
		end
		smaxAvg = smaxAvg + species.maxFitness
		if species.gsid > maxGsid then maxGsid = species.gsid end
		if species.gsid < minGsid then minGsid = species.gsid end
	end
	local genMin = fitnesses[1]
	local genBqt = fitnesses[math.floor(#fitnesses/4)]
	local genMed = fitnesses[math.floor(#fitnesses/2)]
	local genTqt = fitnesses[math.floor(3*#fitnesses/4)]
	local genMax = fitnesses[#fitnesses]
	local genAvg = genAvg / #fitnesses
	local smaxAvg = smaxAvg / #pool.species
	local smaxSdv = 0
	for s,species in pairs(pool.species) do
		smaxSdv = smaxSdv + (species.maxFitness - smaxAvg)*(species.maxFitness - smaxAvg)
	end
	smaxSdv = math.sqrt(smaxSdv / #pool.species)
	local avgSdv = 0
	for f,fitness in pairs(fitnesses) do
		avgSdv = avgSdv + (fitness-genAvg)*(fitness-genAvg)
	end
	avgSdv = math.sqrt(avgSdv / #fitnesses)
	os.remove("data"..dirsep..levelname..dirsep.."data"..(pool.generation+1)..".drd")
	fileDRD = io.open("data"..dirsep..levelname..dirsep.."data"..pool.generation..".drd","w")
	fileDOut = io.open("discorddataout.txt","w")
	fileDRD:write(#fitnesses.." "..pool.population.." "..#pool.species.." ")
	fileDOut:write("**Generation: `"..pool.generation.."`** Target Pop: `"..pool.population.."` Actual Pop: `"..#fitnesses.."` Number of Species: `"..#pool.species.."` ")
	fileDRD:write(genMin.." "..genBqt.." "..genMed.." "..genTqt.." "..genMax.." ")
	fileDOut:write("Minimum: `"..genMin.."` Median: `"..genMed.."` Maximum: `"..genMax.."` ")
	fileDRD:write(genAvg.." "..avgSdv.." "..smaxAvg.." "..smaxSdv.."\n")
	fileDOut:write("Average: `"..genAvg.."` Standard Deviation: `"..avgSdv.."` Average Max: `"..smaxAvg.."`\n")
	for gsid=minGsid,maxGsid do
		for s,species in pairs(pool.species) do
			if species.gsid == gsid then
				local speciesRanks = {}
				for g,genome in pairs(species.genomes) do
					table.insert(speciesRanks, genome) --Insert every genome into the table
				end
				table.sort(speciesRanks, function (a,b) --Sort based on fitness
					return (a.fitstate.fitness < b.fitstate.fitness)
				end)
				local specAvg = 0
				local sfitnesses = {}
				for g=1,#speciesRanks do --Put position of each genome into that genome's data
					sfitnesses[g] = speciesRanks[g].fitstate.fitness
					specAvg = specAvg + speciesRanks[g].fitstate.fitness 
				end
				local specMin = sfitnesses[1]
				local specBqt = sfitnesses[math.ceil(#sfitnesses/4)]
				local specMed = sfitnesses[math.ceil(#sfitnesses/2)]
				local specTqt = sfitnesses[math.ceil(3*#sfitnesses/4)]
				local specMax = sfitnesses[#sfitnesses]
				specAvg = specAvg / #sfitnesses
				local specSdv = 0
				for f,fitness in pairs(sfitnesses) do
					specSdv = specSdv + (fitness-specAvg)*(fitness-specAvg)
				end
				specSdv = math.sqrt(specSdv / #sfitnesses)
				fileDRD:write(species.gsid.." "..#species.genomes.." "..#species.genomes[1].genes.." ")
				fileDRD:write(specMin.." "..specBqt.." "..specMed.." "..specTqt.." "..specMax.." "..specAvg.." "..specSdv)
				for f,fitness in pairs(sfitnesses) do
					fileDRD:write(" "..fitness)
				end
				fileDRD:write("\n")
				if species.nick ~= "" then
					fileDOut:write("Nickname: `"..species.nick.."` Maximum: `"..specMax.."` ")
					fileDOut:write("Staleness: `"..species.staleness.."` Average: `"..specAvg.."` ")
					fileDOut:write("Number of Genomes: `"..#sfitnesses.."` Num Networks: `"..#species.genomes[1].genes.."`\n")					
				end
			end
		end
	end
	fileDRD:close()
	fileDOut:close()
end

keyFlag = false
function keyboardInput()
	local keyboard = input.get()
	if keyboard['N'] and keyFlag == false then --N toggles the network display
        DisplayNetwork = not DisplayNetwork
    end
	if keyboard['R'] and keyFlag == false then --R toggles the sprite hitboxes
        DisplaySprites = not DisplaySprites
    end
	if keyboard['G'] and keyFlag == false then --G toggles the large grid display
        DisplayGrid = (DisplayGrid + 1) % 3
    end
	if keyboard['O'] and keyFlag == false then --O toggles the sprite slots
		DisplaySlots = not DisplaySlots
	end
	if keyboard['A'] and keyFlag == false then --A toggles the top stats bar
		DisplayStats = not DisplayStats
	end
	if keyboard['M'] and keyFlag == false then --M toggles manual vs network input
		ManualInput = not ManualInput
	end
	if keyboard['E'] and keyFlag == false then --E toggles 
		DisplayRanges = not DisplayRanges
	end
	if keyboard['C'] and keyFlag == false then --E toggles 
		DisplayCounters = not DisplayCounters
	end
	if keyboard['L'] and keyFlag == false then --L loads
		--to load put an interrupt that will restart the program and initialize with the previous pool
		local interrupt = io.open("interrupt.lua","w")
		interrupt:write("restartprog = luigiofilename")
		interrupt:close()
		local initialize = io.open("initialize.lua","w")
		initialize:write("loadPool('backups"..dirsep.."current.lua')")
		initialize:close()
	end
	local controller = {}
	controller['A'] = keyboard['F']
	controller['B'] = keyboard['D']
	controller['up'] = keyboard['up']
	controller['down'] = keyboard['down']
	controller['left'] = keyboard['left']
	controller['right'] = keyboard['right']
	if controller["up"] and controller["down"] then
		controller["up"] = false
		controller["down"] = false
	end
	if controller["left"] and controller["right"] then
		controller["left"] = false
		controller["right"] = false
	end
	local allkeys = {'N','R','G','O','A','M','E','C','L'}
	keyFlag = false --Set keyflag to true if any keys were pressed otherwise it is false
	for k=1,#allkeys do
		if keyboard[allkeys[k]] then
			keyFlag = true
		end
	end
	return controller
end

function drawStatsBox(fitstate)
	local genimage = {' ####  #### ##  ## ','##---##----#--##--#','#--####--###---#--#','#--#--#----#------#','#--#--#--###--#---#','##----#----#--##--#','  #### #### ##  ## '}
	local specimage = {' ##### ##### ####  ### ## ####  #### ','##----#----##----##---#--#----##----#','#--####--#--#--###--###--#--###--### ','##---##----##----#--###--#----##---##','####--#--## #--###--###--#--######--#','#----##--#  #----##---#--#----#----# ',' ##### ##    ####  ### ## #### ####  '}
	local gnmimage = {' ##### #### ##  ## #####  ######  #### ','##---##----#--##--##---####--#--##----#','#--####--###---#--#--#--#--------#--###','#--#--#----#------#--#--#--#--#--#----#','#--#--#--###--#---#--#--#--#--#--#--###','##----#----#--##--##---##--#--#--#----#','  #### #### ##  ## ##### ## ## ## #### '}
	local popimage = {' ##### ##### ##### ','#----###---##----##','#--#--#--#--#--#--#','#----##--#--#----##','#--####--#--#--##  ','#--#  ##---##--#   ',' ##    ##### ##    '}
	local fitimage = {' #### ## ###### ##  ## ####  #### #### ','#----#--#------#--##--#----##----#----#','#--###--###--###---#--#--###--###--### ','#----#--# #--# #------#----##---##---##','#--###--# #--# #--#---#--######--###--#','#--###--# #--# #--##--#----#----#----# ',' ##   ##   ##  #### ####### #### ##### '}
	local firstimage = {' ###   #### ###### ','#---###----#------#','##--##--### ##--## ','##--###---#  #--#  ','##--#####--# #--#  ','#----#----#  #--#  ',' #### ####    ##   '}
	local secondimage = {'  ####  ##   ## ####   ','##----##--###--#----## ','#--##--#---##--#--#--# ','###--###----#--#--##--#','##--####--#----#--#--# ','#-----##--##---#----## ',' #####  ##  ### ####   '}
	local maxnumimage = {' #####  #####    ####  ##  ## ','##-#-###--#--####----##--##--#','#-----#--------#--##--#--##--#','##-#-##--#--#--#------##----##','#-----#--#--#--#--##--#--##--#','##-#-##--#--#--#--##--#--##--#',' ##### #######################'}
	local avgxbar = {' #######                 ','#-------#                ',' #######                 ','#--# #--# #### ## ###### ','#--###--##----#--#------#',' #--#--# #--###--###--## ','  #---#  #----#--# #--#  ',' #--#--# #--###--# #--#  ','#--###--##--###--# #--#  ','#--###--##--###--# #--#  ',' ### ###  ##   ##   ##   '}
	local draw = draw
	local pool = pool 
	local fl = math.floor
	if currentTurbo then
		gui.drawrect(8,194,254,230,draw.CYAN,draw.WHITE)
		gui.text(10, 197, "GEN "..pool.generation .. " Species "..pool.currentSpecies.." Genome "..pool.currentGenome, draw.GRAYSCALE, draw.CYAN)
		gui.text(10, 210, "Fitness "..math.max(0,fl(fitstate.fitness)) .. " 1ST "..fl(pool.maxFitness).." 2ND "..fl(pool.secondFitness), draw.GRAYSCALE, draw.CYAN)
		gui.text(10, 222, "#Max "..pool.maxCounter .. " XFit "..pool.average, draw.GRAYSCALE, draw.CYAN)
	else
		-- draw.rect(8,194,32,1,draw.BLACK)
		-- draw.rect(9,195,246,36,draw.WHITE)
		-- draw.rect(10,196,244,34,draw.CYAN)
		gui.drawrect(8,194,254,230,draw.CYAN,draw.WHITE)
		gui.drawrect(230,204,251,207,draw.GRAYSCALE,draw.CYAN)
		--draw.rect(230,205,21,2,draw.BLACK)
		draw.image(10,197,genimage,draw.GRAYSCALE)
		draw.number(31,197,pool.generation,3)
		draw.image(65,197,specimage,draw.GRAYSCALE)
		draw.number(104,197,pool.currentSpecies,3)
		draw.image(138,197,gnmimage,draw.GRAYSCALE)
		draw.number(179,197,pool.currentGenome,3)
		--draw.image(176,198,brackets,draw.GRAYSCALE)
		--draw.number(182,198,19,2)
		draw.image(207,202,popimage,draw.GRAYSCALE)
		draw.number(229,197,pool.current,3)
		draw.number(229,208,pool.population,3)
		draw.image(10,210,fitimage,draw.GRAYSCALE)
		draw.number(50,210,math.max(0,fitstate.fitness),4)
		draw.image(88,210,firstimage,draw.GRAYSCALE)
		draw.number(108,210,pool.maxFitness,4)
		draw.image(147,210,secondimage,draw.GRAYSCALE)
		draw.number(171,210,pool.secondFitness,4)
		draw.image(10,222,maxnumimage,draw.GRAYSCALE)
		draw.number(43,222,pool.maxCounter,3)
		draw.image(81,218,avgxbar,draw.GRAYSCALE)
		draw.number(109,222,pool.average,4)
	end
end

arrowimage = {'###     ','#--##   ','#----## ','#------#','#----## ','#--##   ','###     '}
pmeterimage = {' ############# ','##-----------##','#----#####----#','#----#---#----#','#----####-----#','##---#-------##',' ############# '}
reversePalette = {[' ']=0,['#']=draw.WHITE,['-']=draw.BLACK}
function drawPMeter(x,y)
	local pStatus = memory.readbyte(0x03DD)
	local currentPalette = draw.GRAYSCALE
	for i=1,6 do
		if pStatus < math.pow(2,i)-1 then
			currentPalette = reversePalette
		end
		draw.image(x-8+i*12,y,arrowimage,currentPalette)
	end
	if pStatus < 127 then currentPalette = reversePalette end
	draw.image(x+75,y,pmeterimage,currentPalette)
end

clockimage = {'  ####  ',' #-#--# ','#--#---#','#--###-#','#------#',' #----# ','  ####  '}
function drawClock(x,y)
	local timeLeft = memory.readbyte(0x05EE)*100+memory.readbyte(0x05EF)*10+memory.readbyte(0x05F0)
	draw.image(x,y,clockimage,draw.GRAYSCALE)
	draw.number(x+8,y,timeLeft,3)
end

function drawNeuron(network,neuron)
	if neuron.x then
		inside = draw.tcolor(0x01010100*math.floor(127*(neuron.value+1))+0xE6)
		border = draw.tcolor(0x01010100*math.floor(127*(1-neuron.value))+0xE6)
		if neuron.blocked then inside = draw.tcolor(0xFF3F00E6) end
		if neuron.value ~= 0 then
			draw.rect(neuron.x,neuron.y,5,5,border)
			draw.rect(neuron.x+1,neuron.y+1,3,3,inside)
		else
			draw.rect(neuron.x,neuron.y,5,5,draw.tcolor(0x7F7FCFC7))
		end
		if neuron.incoming then
			for g,gene in pairs(neuron.incoming) do
				if gene.enabled then
					local n1 = network.neurons[gene.into]
					local layerdiff = neuron.layer - n1.layer
					--Green or red for positive or negative weight
					local color = 0x3FFF00
					if gene.weight < 0 then
						color = 0xFF3F00
					end
					local opacity = 0xCF
					if gene.into > BoxSize and gene.into <= Inputs then --fade or remove if bottom-row neuron
						if #network.genes > 100 then
							opacity = 0x00
						elseif #network.genes > 50 then
							opacity = 0x5F
						end
					end
					if n1.value == 0 then --fade or remove if not transmitting a value
						if #network.genes > 50 then
							opacity = 0x00
						else
							opacity = 0x5F
						end
					end
					--draw the genome
					if n1.x and n1.layer > 0 then
						gui.drawline(n1.x+4,n1.y+2,neuron.x,neuron.y+2, draw.tcolor(256*color+opacity))
					end
				end
			end
		end
	end
end

charAimage = {' #### ','##--##','#-##-#','#----#','#-##-#','#-##-#',' #### '}
charBimage = {' #### ','#---##','#-##-#','#---##','#-##-#','#---##',' #### '}
charUimage = {' #### ','#-##-#','#-##-#','#-##-#','#-##-#','##--##',' #### '}
charDimage = {' #### ','#---##','#-##-#','#-##-#','#-##-#','#---##',' #### '}
charLimage = {' #### ','#-####','#-####','#-####','#-####','#----#',' #### '}
charRimage = {' #### ','#---##','#-##-#','#---##','#-#-##','#-##-#',' #### '}
buttonImages = {charAimage,charBimage,charUimage,charDimage,charLimage,charRimage}
function drawNetwork(network)
	local neurons = {} --Array that will contain the position and value of each displayed neuron
	local i = 1
	local ButtonNumbers = ButtonNumbers
	local buttonImages = buttonImages
	for dy=-BoxRadius,BoxRadius do --Add the input box neurons
		for dx=-BoxRadius,BoxRadius do
			network.neurons[i].x = 8+5*(dx+BoxRadius)
			network.neurons[i].y = 20+5*(dy+BoxRadius)
			i = i + 1
		end
	end
	
	local botRowSpacing = 10 --Number of pixels between oscillating nodes
		
	local botRowSize = (3 + #InitialOscillations)*2 - 1
	if botRowSize > BoxWidth then
		botRowSpacing = 5 --If bottom row can't fit then have no spacing
	end
	
	for j=0,#InitialOscillations do --Add the bias and oscillation neurons
		network.neurons[i].x = 3+BoxWidth*5-botRowSpacing*j
		network.neurons[i].y = 25+BoxWidth*5
		i = i + 1
	end
	
	for j=0,1 do --Add the bias and oscillation neurons
		network.neurons[i].x = 8+botRowSpacing*j
		network.neurons[i].y = 25+BoxWidth*5
		i = i + 1
	end
	
	for l=1,#network.layers do --Draw each layer in the NN
		local layer = network.layers[l]
		for n=1,#layer do
			if l > 1 or layer[n] > Inputs then --display only non-inputs in layer 1
				network.neurons[layer[n]].x = math.ceil(13+BoxWidth*5+(220-BoxWidth*5)*((l-1) / (#network.layers)))
				network.neurons[layer[n]].y = math.ceil(20+(BoxWidth+1)*5*(n / (#layer+1)))
			end
		end
	end
	
	--When to block opposite directional inputs
	local blockUD = network.neurons[-3] ~= nil and network.neurons[-4] ~= nil and network.neurons[-3].value>0 and network.neurons[-4].value>0
	local blockLR = network.neurons[-5] ~= nil and network.neurons[-6] ~= nil and network.neurons[-5].value>0 and network.neurons[-6].value>0
	local fb = {}
	if forcebutton ~= nil then
		for k,v in pairs(forcebutton) do
			fb[ButtonNumbers[k]] = v
		end
	end
	local neuron = {}
	for o=1,6 do --outputs
		neuron = {}
		neuron.x = 238
		neuron.y = 25+(BoxWidth-1)*(o-1)
		neuron.value = -1
		local onode = network.neurons[-o]
		if onode and onode.value > 0 then neuron.value = 1 end
		if blockUD and (o == 3 or o == 4) then neuron.blocked = true end
		if blockLR and (o == 5 or o == 6) then neuron.blocked = true end
		if fb[o] ~= nil then
			if fb[0] then
				neuron.value = 1
			else
				neuron.value = -1
			end
		end
		drawNeuron(network,neuron)
		draw.image(246,24+(BoxWidth-1)*(o-1),buttonImages[o],draw.GRAYSCALE)
		if onode ~= nil and network.neurons[o].layer ~= 0 and onode.x then
			if neuron.value == 0 then --draw line between output and ouput box.
				gui.drawline(onode.x+4,onode.y+2,neuron.x,neuron.y+2,draw.tcolor(0x3FFF005F)) --fade if not sending anything
			else	
				gui.drawline(onode.x+4,onode.y+2,neuron.x,neuron.y+2,draw.tcolor(0x3FFF00CF))
			end
		end
	end
	
	for n,neuron in pairs(network.neurons) do
		drawNeuron(network,neuron)
	end
end

function drawRanges()
	local levelstring = levelname
	local ranges = Ranges[levelstring.."-"..fitstate.area]
	local marioX = marioX
	local marioScreenX = marioScreenX
	local marioY = marioY
	local marioScreenY = marioScreenY
	if ranges ~= nil then
		for r=1,#ranges do
			--default values for parts without ranges
			local minx = 0
			local maxx = 65536
			local miny = 0
			local maxy = 240
			local disp = true
			local range = ranges[r]
			--if range limits exist set the limits to those
			if range.xrange.min ~= nil then minx = range.xrange.min end
			if range.xrange.max ~= nil then maxx = range.xrange.max end
			if range.yrange.min ~= nil then miny = range.yrange.min end
			if range.yrange.max ~= nil then maxy = range.yrange.max end
			
			--set color based on the direction of fitness increase
			local rgb = 0x003FFF
			textcolor = toRGBA(0xFFFFFFFF)
			if range.area ~= nil then
				rgb=0xFF00FF
			elseif range.coeffs ~= nil then
				if range.coeffs.x == 1 and range.coeffs.y == 1 and range.coeffs.c ~=0 then
					rgb=0xE5FF00
					textcolor = toRGBA(0xFF000000)
				end
				if range.coeffs.x >0 and range.coeffs.y==0 then
					rgb=0X0FFF1B
				end
				if range.coeffs.y > 0 and range.coeffs.x <1 then
					rgb=0x0F37FF
				end
				if range.coeffs.x == 0 and range.coeffs.y == 0 then
					rgb=0xFF3F00
				end
				if range.coeffs.y <0 then
					rgb=0xFFBF00
				end
				if range.coeffs.x < 0 then
					rgb=0xBF7F00
				end
			elseif range.timeout ~= nil then
				rgb=0x42AAFF
			end
			if rgb~=0x003FFF then
				color = toRGBA(0xFF000000 + rgb)
				--draw the box
				if marioY + marioScreenY == 161 and memory.readbyte(0x0544) == 0 then
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny,maxx-marioX+marioScreenX-2,193-maxy-1,toRGBA(0x7F000000 + rgb),toRGBA(0x7F000000 + rgb))
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny,minx-marioX+marioScreenX-1,193-maxy-1,color,color)
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny,maxx-marioX+marioScreenX-2,193-miny,color,color)
					gui.drawbox(minx-marioX+marioScreenX-1,193-maxy-1,maxx-marioX+marioScreenX-2,193-maxy-1,color,color)
					gui.drawbox(maxx-marioX+marioScreenX-2,193-miny,maxx-marioX+marioScreenX-2,193-maxy-1,color,color)
					--draw the numbers in the corners that show the fitness values
					--local TLcorner = minx*range.coeffs.x+(208-miny)*range.coeffs.y+range.coeffs.c
					--local TRcorner = maxx*range.coeffs.x+(208-miny)*range.coeffs.y+range.coeffs.c
					--local BLcorner = minx*range.coeffs.x+(192-maxy)*range.coeffs.y+range.coeffs.c
					--local BRcorner = maxx*range.coeffs.x+(192-maxy)*range.coeffs.y+range.coeffs.c
					-- gui.drawtext(minx-marioX+marioScreenX,miny+1,TLcorner,textcolor,color)
					-- gui.drawtext(maxx-marioX+marioScreenX-6*string.len(TRcorner)-1,miny+1,TRcorner,textcolor,color)
					-- gui.drawtext(minx-marioX+marioScreenX,maxy-8,BLcorner,textcolor,color)
					-- gui.drawtext(maxx-marioX+marioScreenX-6*string.len(TRcorner)-1,maxy-8,BRcorner,textcolor,color)
				else
					local offset = 161 - (marioY + marioScreenY)
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny-offset,maxx-marioX+marioScreenX-2,193-maxy-1-offset,toRGBA(0x7F000000 + rgb),toRGBA(0x7F000000 + rgb))
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny-offset,minx-marioX+marioScreenX-1,193-maxy-1-offset,color,color)
					gui.drawbox(minx-marioX+marioScreenX-1,193-miny-offset,maxx-marioX+marioScreenX-2,193-miny-offset,color,color)
					gui.drawbox(minx-marioX+marioScreenX-1,193-maxy+1-offset,maxx-marioX+marioScreenX-2,193-maxy-1-offset,color,color)
					gui.drawbox(maxx-marioX+marioScreenX-2,193-miny-offset,maxx-marioX+marioScreenX-2,193-maxy-1-offset,color,color)
				end
			end
		end
	end
end

function displayGUI(network,fitstate)
	if DisplayRanges then
		drawRanges()
	end
	if DisplayStats then
		drawStatsBox(fitstate)
		if not currentTurbo then
			drawPMeter(159,222)
			--drawClock(222,10)
		end
	end

	if DisplayNetwork and not currentTurbo then
		drawNetwork(network)
	end
end

function worldselection()
	local selecting = true
	local selection = 1
	local color = draw.BLACK
	local z = 0
	local c = 0
	for i=1,70 do
		draw.rect(8,204-i,248,22+i,draw.BLACK)
		draw.rect(9,205-i,246,20+i,draw.WHITE)
		draw.rect(10,206-i,244,18+i,draw.CYAN)
		gui.text(12, 208-i, "Please select a world. Use !press up/down to \nnavigate and !press A to select and B to cancel", draw.BLACK, draw.CYAN)
		color = draw.BLACK
		for x=1,8 do
			if file_exists("fcs"..dirsep.."world-" .. x .. ".fcs") then
				color = draw.BLACK
			else
				color = draw.RED
			end
			if x < 5 then
				z = x
				c = 0
			else
				z = x -4
				c = 80
			end
			if x == selection then
				gui.text(12+c, 216+16*z-i, "> World: ".. x, color, draw.CYAN)
			else
				gui.text(12+c, 216+16*z-i, "World: ".. x, color, draw.CYAN)
			end
		end
		coroutine.yield()
	end
	while selecting do
		draw.rect(8,134,248,94,draw.BLACK)
		draw.rect(9,135,246,92,draw.WHITE)
		draw.rect(10,136,244,90,draw.CYAN)
		gui.text(12, 138, "Please select a world. Use !press up/down to \nnavigate and !press A to select and B to cancel", draw.BLACK, draw.CYAN)
		color = draw.BLACK
		for x=1,8 do
			if file_exists("fcs"..dirsep.."world-" .. x .. ".fcs") then
				color = draw.BLACK
			else
				color = draw.RED
			end
			if x < 5 then
				z = x
				c = 0
			else
				z = x -4
				c = 80
			end
			if x == selection then
				gui.text(12+c, 146+16*z, "> World: ".. x, color, draw.CYAN)
			else
				gui.text(12+c, 146+16*z, "World: ".. x, color, draw.CYAN)
			end
		end
		if file_exists("userinput.lua") then
			userinput=loadfile("userinput.lua")
			if userinput then
				os.remove('userinput.lua')
				uinput = {}
				pcall(userinput)
				if uinput.down then
					selection = selection + 1
					if selection > 8 then
						selection = 1
					end
				elseif uinput.up then
					selection = selection - 1
					if selection <1 then
						selection = 8
					end
				elseif uinput.left then
					selection = selection -4
					if selection <1 then
						selection = selection + 8
					end
				elseif uinput.right then
					selection = selection +4
					if selection >8 then
						selection = selection - 8
					end
				elseif uinput.A and file_exists("fcs"..dirsep.."world-" .. selection .. ".fcs") then
					local interrupt = io.open("interrupt.lua","w")
					interrupt:write("savestateObj = savestate.object('fcs"..dirsep.."world-" .. selection ..".fcs')\nprint('one point five')\nsavestate.load(savestateObj)\nprint('two')")
					interrupt:close()
					for i=1,90 do
						draw.rect(8,134+i,248,94-i,draw.BLACK)
						draw.rect(9,135+i,246,92-i,draw.WHITE)
						draw.rect(10,136+i,244,90-i,draw.CYAN)
						gui.text(12, 138+i, "Please select a world. Use !press up/down to \nnavigate and !press A to select and B to cancel", draw.BLACK, draw.CYAN)
						color = draw.BLACK
						for x=1,8 do
							if file_exists("fcs"..dirsep.."world-" .. x .. ".fcs") then
								color = draw.BLACK
							else
								color = draw.RED
							end
							if x < 5 then
								z = x
								c = 0
							else
								z = x -4
								c = 80
							end
							if x == selection then
								gui.text(12+c, 146+16*z+i, "> World: ".. x, color, draw.CYAN)
							else
								gui.text(12+c, 146+16*z+i, "World: ".. x, color, draw.CYAN)
							end
						end
						coroutine.yield()
					end
					return
				elseif uinput.B then
					for i=1,90 do
						draw.rect(8,134+i,248,94-i,draw.BLACK)
						draw.rect(9,135+i,246,92-i,draw.WHITE)
						draw.rect(10,136+i,244,90-i,draw.CYAN)
						gui.text(12, 138+i, "Please select a world. Use !press up/down to \nnavigate and !press A to select and B to cancel", draw.BLACK, draw.CYAN)
						color = draw.BLACK
						for x=1,8 do
							if file_exists("fcs"..dirsep.."world-" .. x .. ".fcs") then
								color = draw.BLACK
							else
								color = draw.RED
							end
							if x < 5 then
								z = x
								c = 0
							else
								z = x -4
								c = 80
							end
							if x == selection then
								gui.text(12+c, 146+16*z+i, "> World: ".. x, color, draw.CYAN)
							else
								gui.text(12+c, 146+16*z+i, "World: ".. x, color, draw.CYAN)
							end
						end
						coroutine.yield()
					end
					return
				end
			end
		end
		coroutine.yield()
	end
end

function SolveMemory()
	local Tset = memory.readbyte(0x070A)
	for a=1,60 do
		coroutine.yield()
	end
	while Tset == 17 do
		local index = memory.readbyte(0x428)
		local card = {}
		local selected = 0
		local selectedindex = 0
		for x=1,18 do
			card[x] = memory.readbyte(0x7E81+x)
		end
		if card[index+1] < 0x10 then
			joypad.set(Player,{A=true})
			for a=1,90 do
				coroutine.yield()
			end
			selected = card[index+1]
			selectedindex = index+1
			local desired = 0
			for i=1,#card do
				if card[i] == selected and i ~= selectedindex then
					desired = i-1
				end
			end
			while index ~= desired do
				if desired <6 then
					if index >=6 then
						joypad.set(Player,{up=true})
					elseif desired > index then
						joypad.set(Player,{right=true})
					else
						joypad.set(Player,{left=true})
					end
				elseif desired >= 12 then
					if index <12 then
						joypad.set(Player,{down=true})
					elseif desired > index then
						joypad.set(Player,{right=true})
					else
						joypad.set(Player,{left=true})
					end
				else
					if index >= 12 then
						joypad.set(Player,{up=true})
					elseif index < 6 then
						joypad.set(Player,{down=true})
					elseif desired > index then
						joypad.set(Player,{right=true})
					else
						joypad.set(Player,{left=true})
					end
				end
				for a=1,20 do
					coroutine.yield()
				end
				index = memory.readbyte(0x428)
			end
			joypad.set(Player,{A=true})
			for a=1,90 do
				coroutine.yield()
			end
		else
			joypad.set(Player,{right=true})
			for a=1,20 do
				coroutine.yield()
			end
		end
		Tset = memory.readbyte(0x070A)
	end
end

function writehumanlevel()
	local file = io.open("HumanLevelName.txt","w")
	local world = memory.readbyte(0x0727)+1
	file:write(world.."-" .. HumanLevelName)
	file:close()
end

function PlayBoss()
	boss = true
	roottimeout = roottimeoutboss
	local prevhistory
	if pool then prevhistory = pool.history end
	initPool(true)
	local file = io.open("backups"..dirsep.."winners.txt","r")
	i = 1
	if file then
		while true do
			winnername = file:read("*line")
			if not winnername then break end
			dofile(winnername)
			addToSpecies(loadedgenome)
			if pool.species[#pool.species].nick == '' then
				pool.species[#pool.species].nick = loadedgenome.nick
			else
				pool.species[#pool.species].nick = pool.species[#pool.species].nick .. "/" .. loadedgenome.nick
			end
			i=i +1
		end
	end
	for g=i,999 do
		local genome = newGenome(1)
		mutate(genome,1)
		addToSpecies(genome)
	end
	getPositions()
	local score = {memory.readbyte(0x0715),memory.readbyte(0x0716),memory.readbyte(0x0717)}
	memory.writebyte(0x0715,0) --set score to 0
	memory.writebyte(0x0716,0)
	memory.writebyte(0x0717,0)
	getTileset()
	indicatorOutput()
	if prevhistory then pool.history = prevhistory end
	redospectop = pool.generation % 10 == 0
	while not playGeneration(redospectop) do
		fitnessDataOutput()
		newGeneration()
		redospectop = pool.generation % 10 == 0
	end
	local score2 = {memory.readbyte(0x0715),memory.readbyte(0x0716),memory.readbyte(0x0717)}
	memory.writebyte(0x0715,score[1]+score2[1]) --restore score
	memory.writebyte(0x0716,score[2]+score2[2])
	memory.writebyte(0x0717,score[3]+score2[3])
	savestateBackup = savestate.object(savestateSlotMap)
	savestate.save(savestateBackup)
	savestate.persist(savestateBackup)
	histogramOutput()
	saveGenome("bosswinner",true)
end


function playLevel()
	roottimeout = 120
	boss = false
	battle = false
	writehumanlevel()
	writescene(1)
	local warppipe = false
	while memory.readbyte(0x0020) == 1 do
		coroutine.yield()
	end
	if memory.readbyte(0x05FD) == 2 then
		while memory.readbyte(0x05FD) == 2 do
			joypad.set(Player,{A = true})
			coroutine.yield()
			joypad.set(Player,{A = false})
			coroutine.yield()
		end
		for x=1,480 do
			coroutine.yield()
		end
	end
	local Tset = memory.readbyte(0x070A)
	if Tset == 7 then
		local TASTime = {0,25,50}
		if memory.readbyte(0x7971) == 1 then
			TASTime = {25}
		end
		for i=1,300 do
			coroutine.yield()
		end
		for i=1,50+TASTime[math.random(#TASTime)] do
			joypad.set(Player,{right = true})
			coroutine.yield()
		end
		joypad.set(Player,{right = false})
		joypad.set(Player,{B = true})
		coroutine.yield()
		for i=1,300 do
			joypad.set(Player,{B = false})
			coroutine.yield()
		end
		savestateBackup = savestate.object(savestateSlotMap)
		savestate.save(savestateBackup)
		savestate.persist(savestateBackup)
		return
	end

	local prevhistory
	if pool then prevhistory = pool.history end
	initPool(false)
	local file = io.open("backups"..dirsep.."winners.txt","r")
	local i = 1
	if file then
		while true do
			winnername = file:read("*line")
			if not winnername then break end
			dofile(winnername)
			addToSpecies(loadedgenome)
			if pool.species[#pool.species].nick == '' then
				pool.species[#pool.species].nick = loadedgenome.nick
			else
				pool.species[#pool.species].nick = pool.species[#pool.species].nick .. "/" .. loadedgenome.nick
			end
			i=i +1
		end
	end
	numberWinner = i
	for g=i,999 do
		local genome = newGenome(1)
		mutate(genome,1)
		addToSpecies(genome)
	end
	preloaded = false
	userreplay = false
	init = loadfile("initialize.lua")
	initializeclear = io.open("initialize.lua","w")
	if initializeclear then initializeclear:close() end
	if init then init() end
	fileFTracker = io.open("fitnesstracker.txt","w")
	fileFTracker:write(pool.history)
	fileFTracker:close()
	coroutine.yield()
	getPositions()
	local startx = marioX
	local starty = marioY
	for i,sprite in ipairs(sprites) do
		if sprite.type == 0x25 then
			warppipe = true
			userreplay = true
			preloaded = true
		end
	end
	--memory.writebyte(0x0715,0) --set score to 0
	--memory.writebyte(0x0716,0)
	--memory.writebyte(0x0717,0)
	getTileset()
	local toad = false
	if memory.readbyte(0x7965) == 1 then
		toad = true
	end
	local score = {memory.readbyte(0x0715),memory.readbyte(0x0716),memory.readbyte(0x0717)}
	if marioMusic == 0x70 then
		battle = true
		roottimeout = 900
		memory.writebyte(0x0715,0) --set score to 0
		memory.writebyte(0x0716,0)
		memory.writebyte(0x0717,0)
	end
	savestateObj = savestate.object(savestateSlotLevel)
	if not preloaded then
		savestate.save(savestateObj)
		savestate.persist(savestateObj)
		levelNameOutput()
		os.execute("mkdir backups"..dirsep..levelname)
		os.execute("mkdir data"..dirsep..levelname)
		indicatorOutput()
	end
	if prevhistory then pool.history = prevhistory end
	if warppipe then
		local cont = {}
		local avgx = {0}
		local goal = 0
		if startx < 60 then
			goal = 218
		elseif startx > 180 then
			goal = 24
		else
			goal = 122
		end
		while memory.readbyte(0x0014) ~= 1 do
			getPositions()
			if marioScreenX > goal+2 then
				cont['left'] = true
				cont['right'] = false
			elseif marioScreenX < goal-2 then
				cont['left'] = false
				cont['right'] = true
			elseif marioScreenX >= goal-2 and marioScreenX <= goal+2 then
				cont['left'] = false
				cont['right'] = false
				cont['down'] = true
			end
			
			if marioScreenX - avgx[1] < 5 then
				cont['A'] = true
				cont['up'] = true
				cont['down']=false
				table.insert(avgx,0)
			else
				cont['A'] = false
			end
			table.insert(avgx,marioScreenX)
			if #avgx > 150 then
				table.remove(avgx,1)
			end
			joypad.set(Player,cont)
			coroutine.yield()
		end
		for i=1,60 do
			coroutine.yield()
		end
	end
	if not userreplay then
		redospectop = pool.generation == 0
		while not playGeneration(redospectop) do
			fitnessDataOutput()
			newGeneration()
			redospectop = false
		end
		if battle then
			local score2 = {memory.readbyte(0x0715),memory.readbyte(0x0716),memory.readbyte(0x0717)}
			memory.writebyte(0x0715,score[1]+score2[1]) --restore score
			memory.writebyte(0x0716,score[2]+score2[2])
			memory.writebyte(0x0717,score[3]+score2[3])
		end
		for i=1,60 do
			if toad then
				memory.writebyte(0x7966,8) --coins required
			end
			coroutine.yield()
		end
		if boss then
			for i=1,600 do
				joypad.set(Player,{A = true, left = false, right = false, up = false, down = false, B = false})
				coroutine.yield()
				joypad.set(Player,{A = false, left = false, right = false, up = false, down = false, B = false})
				coroutine.yield()
			end
		end
		savestateBackup = savestate.object(savestateSlotMap)
		savestate.save(savestateBackup)
		savestate.persist(savestateBackup)
		histogramOutput()
		saveGenome("winner",true)
		mapupdateHist()
		savePool("backups".. dirsep .. levelname .. dirsep .. "winpool.lua")
	end
	if not warppipe then
		Replay = true
		for i=1,#pool.breakthroughfiles do
			print(pool.breakthroughfiles[i])
			dofile(pool.breakthroughfiles[i])
			pool.generation = loadedgenome.gen
			pool.currentSpecies = loadedgenome.s
			pool.currentGenome = loadedgenome.g
			playGenome(loadedgenome)
		end
		if preloaded then
			savestateObj = savestate.object(savestateSlotMap)
		else
			savestateObj = savestateBackup
		end
		local f = io.open("../mapupdate.txt","w")
		f:write("")
		f:close()
		savestate.load(savestateObj)
		Replay = false
		os.rename("2", 'fcs'..dirsep..levelname ..'.fcs')
		if boss then
			os.rename("3", 'fcs'..dirsep..levelname ..'BOSS.fcs')
		end
		local file = io.open("savegamebackup.txt","w")
		file:write(memory.readbyte(0x0727))
		file:close()
	end
	writescene(3)
	os.remove('userinput.lua')
end
prevLN = ''
local leveldict = {[3]="1",[4]="2",[5]="3",[6]="4",[7]="5",[8]="6",[9]="7",[10]="8",[11]="9",[12]="10",[13]="1",[14]="2",[15]="3",[16]="4",[17]="5",[18]="6",[19]="7",[20]="8",[21]="9",[95]="Tower",[103]="Fortress",[104]="Quicksand",[105]="Piramid",[201]="Castle",[204]="Bowser's castle",[223]="Tower",[229]="Start",[235]="Fortress"}
HumanLevelName = ''
while true do
	if memory.readbyte(0x00EE) ~= 0 then
		if Player == 1 then
			levelname = memory.readbyte(0x0727).."-"..(memory.readbyte(0x7978)*8+memory.readbyte(0x797A)/32).."-"..memory.readbyte(0x7976)/32
		else
			levelname = memory.readbyte(0x0727).."-"..(memory.readbyte(0x7979)*8+memory.readbyte(0x797B)/32).."-"..memory.readbyte(0x7977)/32
		end
		if levelname ~= prevLN then
			local LocFile = io.open("OPosition.txt",'w')
			LocFile:write(levelname)
			LocFile:close()
			prevLN = levelname
		end
		playLevel()
	elseif memory.readbyte(0x070A) == 17 then
		SolveMemory()
	else
		if Player == 1 then
			levelname = memory.readbyte(0x0727).."-"..(memory.readbyte(0x77)*8+memory.readbyte(0x79)/32).."-"..memory.readbyte(0x75)/32
		else
			levelname = memory.readbyte(0x0727).."-"..(memory.readbyte(0x78)*8+memory.readbyte(0x7A)/32).."-"..memory.readbyte(0x76)/32
		end
		if levelname ~= prevLN then
			local LocFile = io.open("OPosition.txt",'w')
			LocFile:write(levelname)
			LocFile:close()
			prevLN = levelname
		end
		if file_exists("userinput.lua") then
			userinput=loadfile("userinput.lua")
			if userinput then
				os.remove('userinput.lua')
				uinput = {}
				pcall(userinput)
				if leveldict[memory.readbyte(0xE5)] ~= nil then
					HumanLevelName = leveldict[memory.readbyte(0xE5)]
				end
				if uinput.A and file_exists("fcs" .. dirsep .. levelname .. ".fcs") and memory.readbyte(0x05F2) == 0 then --0x5F2 1 = item folder. 0 = map
					local interrupt = io.open("interrupt.lua","w")
					interrupt:write("os.rename('fcs"..dirsep .. levelname ..".fcs', "..savestateSlotLevel..")\nsavestateObj = savestate.object(" .. savestateSlotLevel .. ")\nprint('one point five')\nsavestate.load(savestateObj)\nprint('two')")
					
					
					if file_exists('fcs' .. dirsep .. levelname .. 'BOSS.fcs') then
						interrupt:write("os.rename('fcs"..dirsep .. levelname .."BOSS.fcs', "..savestateSlotBOSS..")\nbosssavestateObj = savestate.object(" .. savestateSlotBOSS ..")")
					end
					interrupt:close()
					local initialize = io.open("initialize.lua","w")
					initialize:write("loadPool('backups"..dirsep.. levelname .. dirsep.."winpool.lua')\n")
					initialize:write("preloaded = true\nuserreplay = true\nwritescene(2)")
					initialize:close()
				elseif uinput.A and Startlocations[levelname] then
					worldselection()
				else
					joypad.set(Player,uinput)
				end
			end
		end
	end
	coroutine.yield()
end

return true