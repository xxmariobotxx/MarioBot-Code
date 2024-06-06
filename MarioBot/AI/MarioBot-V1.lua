LostLevels = 0
Player = 1

savestateSlot = 1
savestateObj = savestate.object(savestateSlot)

BoxRadius = 6 --The radius of the vision box around Mario
InitialOscillations = {50,60,90} --Initial set of oscillation timers
BoxWidth = BoxRadius*2+1 --Full width of the box
BoxSize = BoxWidth*BoxWidth --Number of neurons in the box
Inputs = BoxSize + 3 + #InitialOscillations

--MarioBot's global variables go here
particles = {}
sparksPending = false
maxFitnessPerArea = {}

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

DeltaDisjoint = 4.0 --multiplier for disjoint in same species function
DeltaWeights = 0.4 --multiplier for weights in same species function
DeltaThreshold = 1.0 --threshold for delta to be in the same species
DeltaSwitch = 0.6 --threshold for delta of the network switch location
turboUpdatedForNetwork = {} --table to store what networks have had TurboMax adjusted to

DisplaySlots = false --Display the sprite slots?
DisplaySprites = false --Display the sprite hitboxes?
DisplayGrid = 0 --Display a large network inputs grid?
DisplayNetwork = true --Display the neural network state?
DisplayStats = true --Display top stats bar?
DisplayRanges = true --Display special fitness ranges?
DisplayCounters = false --Display death/time counter?

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

FPS = 50+10*LostLevels

TurboMin = 0
TurboMax = 1
CompleteAutoTurbo = false
currentTurbo = false

dirsep = "\\" --forward or backward slash for file separation? depends on OS

ProgramStartTime = os.time()

--Stuff for getting inputs to the AI
function platformSize() --Finds whether the platforms are large or small in the current level
	local platsize = true --platsize is true for large platforms
	if LostLevels == 0 and hardMode == 1 then --hard mode always has small platforms
		platsize = false
	end
	if currentWorld > 4 or currentLevel == 4 then --castles and past world 4 always have small platforms
		platsize = false
	end
	return platsize
end

function getPositions() --Returns all needed game state information from the game's RAM
	--Gets necessary info for Mario and the game state
	marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86) --Mario's X position
	marioY = memory.readbyte(0x03B8)+16 + memory.readbyte(0xB5)*256 - 256 --Mario's Y position
	
	if marioX > 60000 then marioX = 0 end --to prevent maze overflow bug
	if marioY > 60000 or marioY < 0 then marioY = 0 end --above screen due to spring
	
	marioScreenX = (marioX - memory.readbyte(0x071D)) % 256 --Mario's X position relative to the screen
	marioScreenY = memory.readbyte(0x03B8)+16 --Mario's Y position not counting high vertical pos (mod 256)
	
	marioState = memory.readbyte(0x0E) --Mario's current state (loading, in pipe, dying, normal, etc)
	
	marioXVel = memory.readbyte(0x0057) --Mario's current X velocity
	marioYVel = memory.readbyte(0x009F) --Mario's current Y velocity
	
	currentScreen = memory.readbyte(0x071A) --Currently loaded in screen
	nextScreen = memory.readbyte(0x071B) --Next loaded in screen
	
	currentWorld = memory.readbyte(0x075F)+1 --Current world
	currentLevel = memory.readbyte(0x075C)+1 --Current level
	
	notInDemo = memory.readbyte(0x0770) --0 if demo, 1 if in gameplay
	prelevel = memory.readbyte(0x0757) --if on the prelevel loading screen
	
	mazeCP = memory.readbyte(0x06D9) --number of checkpoints it has passed
	mazeCPGoal = memory.readbyte(0x06DA) --number of checkpoints it should have passed
	
	timerCounter = memory.readbyte(0x0787) --counter uesd for the timer. if stays at 0 means timer is frozen

	areaType = memory.readbyte(0x074E)
	
	screenX = memory.readbyte(0x03AD) --X of current screen
	screenY = memory.readbyte(0x03B8) --Y of current screen
	
	hardMode = memory.readbyte(0x07FC) --For SMB, 0 if normal quest 1 if second quest
	
	--Gets necesary info for each loaded sprite
	spriteSlots = {} --From 0 to 5, each sprite currently loaded
	spriteHitboxes = {} --Locations of each sprite, larger spriteHitboxes have multiples to cover a larger hitbox
	local platsize = platformSize()
	for slot=0,5 do
		local isLoaded = memory.readbyte(0xF+slot) --Is the sprite being rendered
		if isLoaded ~= 0 then
			local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot) --Sprite X position
			local ey = memory.readbyte(0xCF + slot)+36 --Sprite Y position
			local typ = memory.readbyte(0x16 + slot) --Sprite ID (what it is)
			local state = memory.readbyte(0xA0 + slot) --Sprite state (animation state, rotation of firebars, etc)
			--Correct for off-center sprite locations and spriteHitboxes sized larger than one block
			if typ == 21 then --bowser fire
				ex = ex + 4
				ey = ey - 10
			elseif typ >= 27 and typ <= 30 then --short firebar
				ex = ex - 4
				ey = ey - 11
				cycle = state / 16 * math.pi
				ymul = math.cos(cycle)
				xmul = math.sin(cycle)
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*16,["y"]=ey-ymul*16}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*32,["y"]=ey-ymul*32}
			elseif typ == 31 or typ == 32 then --long firebar
				ex = ex - 4
				ey = ey - 12
				cycle = state / 16 * math.pi
				ymul = math.cos(cycle)
				xmul = math.sin(cycle)
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*16,["y"]=ey-ymul*16}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*32,["y"]=ey-ymul*32}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*48,["y"]=ey-ymul*48}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*64,["y"]=ey-ymul*64}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+xmul*80,["y"]=ey-ymul*80}
			elseif typ >= 36 and typ <= 42 then --platform
				ey = ey - 7
				ex = ex - 1
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+16,["y"]=ey}
				if platsize then
					spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+32,["y"]=ey}
				end
			elseif typ == 43 or typ == 44 then --elevator
				ey = ey - typ + 36
				ex = ex - 1
				local eyalt = (ey+128) % 256
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+8,["y"]=ey}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex,["y"]=eyalt}
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex+8,["y"]=eyalt}
			elseif typ == 45 then --bowser
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex,["y"]=ey-8}
			end
			if state ~= 4-LostLevels or typ ~= 12 then --If the podoboo's state is 4 don't draw it, it is not tangible, otherwise add the sprite
				spriteHitboxes[#spriteHitboxes+1] = {["x"]=ex,["y"]=ey,["t"]=typ,["d"]=slot}
			end
			spriteSlots[slot] = typ
		end
	end
end

hiddenblocks = {} --List of hidden blocks Mario has been near
hitblocks = 0 --Number of hidden blocks Mario has revealed

function getTile(dx, dy) --Finds the tile ID of a particular block
	--Find the memory address
	local x = marioX + dx + 8
	local y = marioY + dy - 8
	local page = math.floor(x/256)%2
	local subx = math.floor((x%256)/16)
	local suby = math.floor((y - 32)/16)
	local addr = 0x500 + page*13*16+suby*16+subx
	--Find tile coordinates stored to keep track of hidden blocks
	local tilex = math.floor(x/16)
	local tiley = math.floor(y/16)
	--Find the block ID of the block
	local tile = memory.readbyte(addr)
	
	local hbid = 95 - LostLevels --hidden block
	local vbid = 284 - 200*LostLevels --vine block
	--If the block is offscreen it is empty
	if suby >= 13 or suby < 0 then
		tile = 0
	end
	--If the block is a hidden block
	if (tile == hbid or tile == vbid) then
		--If that block has not already been recorded add it to the list of hidden blocks
		local dupe = false
		for b=1,#hiddenblocks do
			if hiddenblocks[b][1] == tilex and hiddenblocks[b][2] == tiley then
				dupe = true
				break
			end
		end
		if not dupe then
			table.insert(hiddenblocks,{tilex,tiley,tile})
		end
	end
	--If this block was previously a hidden block and now is not it has been hit.
	for b=1,#hiddenblocks do
		if hiddenblocks[b][1] == tilex and hiddenblocks[b][2] == tiley then
			if tile ~= hiddenblocks[b][3] then
				hitblocks = hitblocks + 1
				if hiddenblocks[b][3] == vbid then hitblocks = hitblocks + 1 end --vine blocks count as an extra hidden block hit
				table.remove(hiddenblocks,b)
				break
			end
		end
	end
	--Return what the block type is
	return tile
end

function getInputs() --Create the grid around Mario that is the network's vision
    getPositions() --Get all required memory data
    local inputs = {} --Grid around Mario that shows blocks/sprites
	--Loop through each space in the grid
    for dy=-BoxRadius*16,BoxRadius*16,16 do
        for dx=-BoxRadius*16,BoxRadius*16,16 do
            inputs[#inputs+1] = 0
			--If the tile contains a block, set to 1
            tile = getTile(dx, dy)
            if tile ~= 0 and marioY+dy < 0x1B0 then
                inputs[#inputs] = 1
            end
        end
    end
	--for each sprite set it's location to -1
	for i = 1,#spriteHitboxes do
		distx = math.floor((spriteHitboxes[i]["x"] - marioX)/16 + 0.5)
		disty = math.floor((spriteHitboxes[i]["y"] - marioY)/16 - 0.5)
		if math.abs(distx)<=BoxRadius and math.abs(disty)<=BoxRadius then
			inputs[distx+BoxRadius+1+(disty+BoxRadius)*BoxWidth] = -1
		end
	end
	return inputs
end

--Initialization for the genetic system
function initPool() --The pool contains all data for the genetics of the AI
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
	pool.population = 1000 --Number of genomes
	pool.lastMajorBreak = 0 --Last breakthrough of more than majorBreakFitness
	pool.attempts = 1 --number of attempts
	pool.deaths = 0 --number of deaths (auto timeouts do not count)
	pool.totalTime = 0 --total time elapsed in-game
	pool.realTime = 0 --total time elapsed out of game
	pool.history = "" --breakthrough tracker
	pool.breakthroughX = 0 --indicator stuff
	pool.breakthroughZ = ""
	pool.breakthroughfiles = {}
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
    return gene
end

function copyGene(gene) --copy a gene
	local newGene = {}
	newGene.into = gene.into
	newGene.out = gene.out
	newGene.weight = gene.weight
	newGene.enabled = gene.enabled
	newGene.innovation = gene.innovation
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
    neuron.value = 0.0 --current value
	neuron.layer = 0 --What layer the neuron is in (0 means it has not been calculated)
    return neuron
end

--Evaluation of networks
function generateNetwork(genome) --Convert each list of genes into a network that can be evaluated
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
	for i=1,#oscillating do --Oscillating nodes
		if frame % (oscillating[i]*2) < oscillating[i] then
			table.insert(inputs,1.0)
		else
			table.insert(inputs,-1.0)
		end
	end
	--Speed nodes
	if (marioXVel < 100) then
		table.insert(inputs,marioXVel / 48)
	else
		table.insert(inputs,(marioXVel - 256) / 48)
	end
	if (marioYVel < 10) then
		table.insert(inputs,marioYVel / 5)
	else
		table.insert(inputs,(marioYVel - 256) / 5)
	end
	--Add inputs to network
	for i=1,Inputs do
		network.neurons[i].value = inputs[i]
	end
	--Evaluate each layer
	for l=2,#network.layers do
		local layer = network.layers[l]
		for n=1,#layer do
			local neuron = network.neurons[layer[n]]
			local sum = 0.0
			for j = 1,#neuron.incoming do
				local incoming = neuron.incoming[j]
				local other = network.neurons[incoming.into]
				sum = sum + incoming.weight * other.value
			end
			neuron.value = sigmoid(sum)
		end
	end
	local output = {}
	for o=1,#ButtonNames do --Find neural network outputs
		output[ButtonNames[o]] = network.neurons[-o] ~= nil and network.neurons[-o].value > 0
	end
	--Disable opposite d-pad presses
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
	end
	geneO.weight = gene.weight / geneI.weight --they should multiply to original weight
			
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
    if math.random() < 0.25 then
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
		
        if breed+1 >= 1000/pool.population or species.fitnessRank > sum / #pool.species then
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

function writetable(file,tbl) --writes a string of a table to a file
	function tablestring(a)
		if type(a)=='number' or type(a)=='boolean' then
			file:write(tostring(a))
		elseif type(a)=='string' then
			file:write('"')
			for i=1,string.len(a) do
				local c = string.sub(a,i,i)
				if c=="\n" then
					file:write("\\n")
				else
					file:write(c)
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

function saveGenome(name)
  local levelname = currentWorld .. "-" .. currentLevel  -- Name of level in the file name
  if LostLevels == 1 then levelname = "LL" .. currentWorld .. "-" .. currentLevel end
  local filename = "backups" .. dirsep .. levelname .. dirsep .. name .. ".lua"
  local file = io.open(filename, "w")
  local spec = pool.species[pool.currentSpecies]
  local genome = spec.genomes[pool.currentGenome]
  genome.nick = spec.nick
  genome.gen = pool.generation
  genome.s = pool.currentSpecies
  genome.g = pool.currentGenome
  file:write("loadedgenome=")
  writetable(file, genome)
  file:close()
  table.insert(pool.breakthroughfiles, filename)  -- Add filename to breakthroughfiles
  print("Saved breakthrough genome to: " .. filename)
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

function newGeneration() --runs the evolutionary algorithms to advance a generation
	maxNewGenProgress = -1
	newgenProgress(0)
	local levelname = currentWorld.."-"..currentLevel --name of level in the file name
	if LostLevels == 1 then levelname = "LL"..currentWorld.."-"..currentLevel end
	if pool.generation == 0 then --first gen so make the directory
		os.execute("mkdir backups"..dirsep..levelname)
	end
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
        local breed = math.floor(species.fitnessRank / rankSum * pool.population) - 1 --num of children to generate
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
	savePool("backups/current.lua")
	newgenProgress(20)
end

--Running the game
BonusArea = {[0]="WaterBonus",[2]="84WaterSection",[46]="SkyBonusA",[50]="WarpZone",[55]="SkyBonusB",[91]="UndergroundBonus"}
if LostLevels == 1 then
BonusArea = {[66]="CoinBonusA",[194]="CoinBonusB",[179]="SkyBonusA",[60]="SkyBonusB",[2]="WaterBonus",[180]="12VineWarp",[193]="12PipeWarp",[68]="53Pipe",[59]="Stairs"}
end

Ranges = { --special ranges in which there is a fitness function modification
	["4-4 Level"]={
		{xrange={min=1512,max=1680},yrange={max=80},coeffs={x=1,y=0,c=112}},
		{xrange={min=1512,max=1680},yrange={min=80,max=144},coeffs={x=-1,y=0,c=3536}},
		{xrange={min=1512,max=1680},yrange={min=144},coeffs={x=1,y=0,c=576}},
		{xrange={min=1680},yrange={},coeffs={x=1,y=1,c=576}},
		{xrange={min=288,max=1200},yrange={min=80},coeffs={x=0,y=0,c=0}},
		{xrange={min=1680,max=2288},yrange={max=144},coeffs={x=0,y=0,c=0}}},
	["8-4 Level"]={
		{xrange={min=2354,max=2464},yrange={},coeffs={x=0,y=1,c=2370}},
		{xrange={min=2432,max=2464},yrange={min=64,max=80},coeffs={x=1,y=1,c=100}},
		{xrange={min=2464,max=2600},yrange={},coeffs={x=0,y=0,c=0}},
		{xrange={min=3678,max=3900},yrange={},coeffs={x=0,y=0,c=0}}},
	["LL2-2 Level"]={
		{xrange={min=3000,max=3160},yrange={min=64,max=192},coeffs={x=0,y=0,c=0}}},
	["LL3-1 Level"]={
		{xrange={min=3000},yrange={},coeffs={x=0,y=0,c=0}}},
	["LL3-1 LL31Underground"]={
		{xrange={},yrange={},coeffs={x=0,y=0,c=0}}},
	["LL3-4 Level"]={
		{xrange={min=1632,max=2384},yrange={min=96},coeffs={x=0,y=0,c=0}}},
	["LL5-3 Level"]={
		{xrange={min=592,max=630},yrange={min=96},coeffs={x=0,y=0,c=0}},
		{xrange={min=630,max=1300},yrange={},coeffs={x=0,y=0,c=0}}},
	["LL7-2 Level"]={
		{xrange={min=792,max=840},yrange={min=80},coeffs={x=0,y=0,c=0}},
		{xrange={min=840,max=1280},yrange={},coeffs={x=0,y=0,c=0}}},
	["LL7-4 Level"]={
		{xrange={min=1278,max=1340},yrange={min=80,max=144},coeffs={x=-1,y=1,c=2660}},
		{xrange={min=1278,max=1340},yrange={max=80},coeffs={x=1,y=1,c=104}},
		{xrange={min=1340},yrange={},coeffs={x=1,y=1,c=104}},
		{xrange={min=1132},yrange={max=16},coeffs={x=0,y=0,c=0}}}
} --Currently missing Lost Levels World 8

function fitness(fitstate) --Returns the distance into the level - the non-time component of fitness
	local coeffs={x=1,y=1,c=0} --position base coefficients
	local marioX = marioX
	local marioY = marioY
	local levelstring = "" --string to represent the level and subworld, to index Ranges
	if LostLevels == 1 then levelstring = "LL" end
	levelstring = levelstring .. currentWorld .. "-" .. currentLevel .. " " .. fitstate.area
	local ranges = Ranges[levelstring]
	if ranges ~= nil then
		for r=1,#ranges do --for each special fitness range
			local range = ranges[r]
			if (range.xrange.min == nil or marioX > range.xrange.min) and (range.xrange.max == nil or marioX <= range.xrange.max) then --in x range
				if (range.yrange.min == nil or marioY > range.yrange.min) and (range.yrange.max == nil or marioY <= range.yrange.max) then --in y range
					coeffs = range.coeffs --replace default coefficients
				end
			end
		end
	end
	if areaType == 0 then
		coeffs.y = 0
	end
	fitstate.position = coeffs.x*marioX + coeffs.y*(192 - marioY) + coeffs.c --set the position value
	if mazeCPGoal > mazeCP then --missed a maze checkpoint
		fitstate.position = 0
	end
	if marioState == 8 then
		if fitstate.laststate == 7 and fitstate.lastarea ~= fitstate.area then --update offset
			fitstate.offset = fitstate.lastright + fitstate.offset - fitstate.position
		end
		fitstate.lastright = fitstate.position --update lastright when in control of mario
		fitstate.timeout = fitstate.timeout + 1 --increase timeout
		if fitstate.timeout > 60 then --if has been idle for a second, start penalizing
			fitstate.timepenalty = fitstate.timepenalty + 1
		end		
	else
		fitstate.position = fitstate.lastright --freeze position when not in control of mario
		if fitstate.laststate == 8 and marioState < 8 then --going to a new area
			local area = memory.readbyte(0x0750) --bonus area id
			fitstate.lastarea = fitstate.area
			if BonusArea[area] ~= nil then
				fitstate.area = BonusArea[area] --name of bonus room
			else
				fitstate.area = "Level"
			end
		end
	end
    if maxFitnessPerArea[fitstate.area] == nil then
        maxFitnessPerArea[fitstate.area] = {fitness = fitstate.fitness, x = marioX}
    elseif fitstate.fitness > maxFitnessPerArea[fitstate.area].fitness then
        maxFitnessPerArea[fitstate.area] = {fitness = fitstate.fitness, x = marioX}
    end
	fitstate.hitblocks = hitblocks --transfer global hitblocks to local fitstate
	fitstate.laststate = marioState --set laststate
	local secretScore = (hitblocks*LostLevels+mazeCP)*50 --score for finding secret routes like hidden blocks and maze paths
	if not (marioYVel > 0 and marioYVel < 10) and fitstate.position + fitstate.offset + secretScore > fitstate.rightmost then
		fitstate.timeout = math.max(0,fitstate.timeout + (fitstate.rightmost - fitstate.position - fitstate.offset - secretScore)*2) --decrease timeout
		fitstate.rightmost = fitstate.position + fitstate.offset + secretScore --rightmost is maximum that the position+offset has ever been
		fitstate.savedtimepenalty = fitstate.timepenalty
	end
	fitstate.fitness = fitstate.rightmost - math.floor(fitstate.savedtimepenalty / 2) --return fitness
end

function playGenome(genome) --Run a genome through an attempt at the level
	savestate.load(savestateObj) --load savestate
	falseload = false
	while memory.readbyte(0x0787) == 0 do --wait until the game has fully loaded in mario
		coroutine.yield()
		falseload = true
	end
	if falseload then --move a savestate forward so that it doesn't have any load frames
		savestate.save(savestateObj)
	end
	local fitstate = genome.fitstate
	fitstate.frame = 0 --frame counter for the run
	fitstate.position = 0 --current position
	fitstate.rightmost = 0 --max it has gotten to the right
	fitstate.offset = 0 --offset to make sure fitness doesn't jump upon room change
	fitstate.lastright = 0 --last position before a transition.cancel()
	fitstate.laststate = 7 --mario's state the previous frame (to check state transitions)
	fitstate.fitness = 0 --current fitness score
	fitstate.timeout = 0 --time increasing when mario is idle, kills him if it is too much
	fitstate.timepenalty = 0 --number of frames mario was too idle, to subtract from his fitness
	fitstate.area = "Level"
	fitstate.lastarea = ""
	fitstate.savedtimepenalty = 0 --does not save time penalty until mario moves forward
	fitstate.createOffset = true
	
	hitblocks = 0 --number of hidden blocks it has hit
	hiddenblocks = {} --hidden blocks it has gotten near
	
	getPositions()
	local nsw = 1 --network switch
	generateNetwork(genome) --generate the network
	local controller = {} --inputs to the controller

	levelCompleted = false
	timerFrozenAtAxe = false
	
	while true do --main game loop
		local manualControl = keyboardInput()
		--Get inputs to the network
		
		if fitstate.frame % FPS == 0 then
			timerOutput()
		end
		
		if fitstate.frame % FramesPerEval == 0 then
			inputs = getInputs()
			--Find the current network to be using
			local nscompare = fitstate.rightmost
			nsw = 1
			for n=1,#genome.networkswitch do
				if nscompare > genome.networkswitch[n] then
					nsw = n+1
					if not Replay and not turboUpdatedForNetwork[nsw] then
						TurboMax = fitstate.fitness
						turboUpdatedForNetwork[nsw] = true
					end
				end
			end
			--Put outputs to the controller
			controller = evaluateNetwork(genome.networks[nsw], inputs, genome.oscillations[nsw], fitstate.frame)
		else
			getPositions()
		end
		
		if ManualInput then
			joypad.set(Player,manualControl)
		else
			joypad.set(Player,controller)
		end
		
		fitness(fitstate) --update the fitness

		local turbocompare = math.max(0,fitstate.rightmost)
		if CompleteAutoTurbo or (turbocompare >= TurboMin and turbocompare < TurboMax and pool.species[pool.currentSpecies].turbo) then
			if not currentTurbo then
				currentTurbo = true
				emu.speedmode("turbo")
			end
		else
			if currentTurbo then
				currentTurbo = false
				emu.speedmode("normal")
				if sparksPending then
					spawnParticles()
					sparksPending = false
				end
			end
		end
		
		--Display the GUI
		displayGUI(genome.networks[nsw], fitstate)
		--Advance a frame
		coroutine.yield()
		fitstate.frame = fitstate.frame + 1
		
		--exit if dead or won
		if marioState == 11 or marioY > 256 then --if he dies to an enemy or a pit
			pool.attempts = pool.attempts + 1
			pool.deaths = pool.deaths + 1
			deathCounterOutput()
			for frame=1,FramesOfDeathAnimation do
				displayGUI(genome.networks[nsw], fitstate)
				coroutine.yield()
			end
			genome.networks = {} --reset networks to save on RAM
			pool.totalTime = pool.totalTime + fitstate.frame
			turboOutput()
			timerOutput()
			return false
		end
		if fitstate.timeout > fitstate.rightmost/3+120 and not ManualInput and timerCounter > 0 then --timeout threshold increases throughout level. kill if timeout is enabled and timer is not frozen
			genome.networks = {} --reset networks to save on RAM
			pool.attempts = pool.attempts + 1
			deathCounterOutput()
			turboOutput()
			timerOutput()
			pool.totalTime = pool.totalTime + fitstate.frame
			return false
		end
		if memory.readbyte(0x07F8) == 0 and memory.readbyte(0x07F9) == 0 and memory.readbyte(0x07FA) == 0 and not levelCompleted then

			levelCompleted = true

			if genome.fitstate.fitness > pool.maxFitness then
				pool.maxFitness = genome.fitstate.fitness
			end

			if not Replay then
				print("Beat level")
				writeBreakthroughOutput()
				saveGenome("G" .. pool.generation .. "s" .. pool.currentSpecies .. "g" .. pool.currentGenome .."_Winner")
			end
		end

		if fitstate.area == "Level" and marioState == 8 and memory.readbyte(0x001D) == 0 and timerCounter == 0 and not timerFrozenAtAxe then
			timerFrozenAtAxe = true
			
			if genome.fitstate.fitness > pool.maxFitness then
				pool.maxFitness = genome.fitstate.fitness
			end
			
			if not Replay then
				print("Beat castle")
				writeBreakthroughOutput()
				saveGenome("G" .. pool.generation .. "s" .. pool.currentSpecies .. "g" .. pool.currentGenome .. "_CastleWinner")
			end
		end
				
		if prelevel == 1 then --if he beats the level
			levelCompleted = false
			--os.execute("python3 record.py") --Uncomment this line if you want to use this to record the winning genome in OBS
			genome.networks = {} --reset networks to save on RAM
			pool.attempts = pool.attempts + 1
			pool.totalTime = pool.totalTime + fitstate.frame
			ProgramStartTime = os.time()
			timerOutput()
			if TurboMax > 0 then --rerun with no turbo
				TurboMin = 0
				TurboMax = 0
				turboOutput()
      			Replay = true
      			for i = 1, #pool.breakthroughfiles do
      			  print("Replaying breakthrough: " .. pool.breakthroughfiles[i])
      			  dofile(pool.breakthroughfiles[i]) -- Load the breakthrough genome
      			  pool.generation = loadedgenome.gen
      			  pool.currentSpecies = loadedgenome.s
      			  pool.currentGenome = loadedgenome.g
      			  playGenome(loadedgenome) -- Replay the loaded genome
      			end
      			pool.breakthroughfiles = {} --Reset table for breakthroughs in the next level
      			turboUpdatedForNetwork = {} --Reset table for next level for network switches & turbo updates
			end
			timerFrozenAtAxe = false
			return true
		end
	end
end

function spawnParticles()
    local numParticles = 20 -- Adjust as needed
    local angleIncrement = (2 * math.pi) / numParticles -- Evenly distribute angles

    for i = 1, numParticles do
        local hue = math.random()
        local saturation = 1
        local lightness = 0.5
        local alpha = 1

        local r, g, b, a = hslToRgb(hue, saturation, lightness, alpha)

        local angle = angleIncrement * i -- Calculate angle for each particle
        local radius = math.random(10, 50) -- Randomize radius for a burst effect

        local particle = {
            x = 128 + radius * math.cos(angle), -- Position based on angle and radius
            y = 128 + radius * math.sin(angle), -- CORRECTED: Centered vertically at 128
            vx = math.random(-3, 3),
            vy = math.random(-5, -1),
            life = math.random(120, 180),
            gravity = 0.2,
            color = toRGBA(math.floor(a * 255) * 0x1000000 + math.floor(r * 255) * 0x10000 + math.floor(g * 255) * 0x100 + math.floor(b * 255))
        }
        table.insert(particles, particle)

        gui.drawbox(particle.x, particle.y, particle.x + 3, particle.y + 3, particle.color, particle.color)
    end
end

function hslToRgb(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h*6, s, l
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return r+m, g+m, b+m, a
end

function updateParticles()
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vy = p.vy + p.gravity -- Apply gravity to vertical velocity
        p.life = p.life - 1
        if p.life <= 0 then 
            table.remove(particles, i) 
        else
            local alpha = math.floor((p.life / 120) * 255) -- Fade out over time
            gui.drawbox(p.x, p.y, p.x + 3, p.y + 3, p.color + (alpha * 0x1000000), p.color + (alpha * 0x1000000))
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
			end
			pool.bestSpecies = species.gsid --update the best species number
			pool.maxFitness = genome.fitstate.fitness --update the best fitness
			pool.maxFitnessX = marioX --store the x-coordinate
			sparksPending = true
			writeBreakthroughOutput()
			if (memory.readbyte(0x07F8) ~= 0 or memory.readbyte(0x07F9) ~= 0 or memory.readbyte(0x07FA) ~= 0) and not (timerCounter == 0) then
				saveGenome("G" .. pool.generation .. "s" .. pool.currentSpecies .. "g" .. pool.currentGenome)
			end
		elseif genome.fitstate.fitness > pool.secondFitness then --if the fitness is the new second best
			if species.gsid ~= pool.bestSpecies then --change the second best if this is not the current best species
				pool.secondFitness = genome.fitstate.fitness
			end
		end
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
		if won then return true end --return true if we won
	end
	return false --return false otherwise
end

function playGeneration(showBest) --Plays through the entire generation
	pool.maxCounter = 0
	for s=1,#pool.species do
		local species = pool.species[s]
		pool.currentSpecies = s
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

function mapupdate()
	io.open("../mapupdate.txt","w"):close()
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

local base64chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function toBase64(num)
    local result = ''
    repeat
        local remainder = num % 64
        result = string.sub(base64chars, remainder + 1, remainder + 1) .. result
        num = math.floor(num / 64)
    until num == 0
    return result
end

function speciesDataOutput()
	local species = pool.species[pool.currentSpecies]
	local gsid_base64 = toBase64(tostring(species.gsid))
	speciesdata = "GSID: "..gsid_base64.." SMax: "..species.maxFitness.." Stale: "..species.staleness
	if species.nick ~= "" then
		speciesdata = speciesdata.." Nick: "..species.nick
	end
	fileSData = io.open("speciesdata.txt","w")
	fileSData:write(speciesdata)
	fileSData:close()
end

function writeBreakthroughOutput()
    local species = pool.species[pool.currentSpecies]
    local genome = species.genomes[pool.currentGenome]

    local gsid_base64 = toBase64(tostring(species.gsid)) --convert GSID numbers to a base64 number
    local gsid_width = 5

    -- Format the information
    local fitness = math.floor(genome.fitstate.fitness)
    local info = string.format("Gen:%d Spec:%d Gnm:%d GSID:%s Fit:%d Time:",
    	pool.generation, pool.currentSpecies, pool.currentGenome, gsid_base64, fitness)

    -- Format and append the time information
    local seconds = pool.realTime
    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60
    local hours = math.floor(minutes / 60)
    minutes = minutes - hours * 60
    local days = math.floor(hours / 24)
    hours = hours - days * 24

    if pool.realTime < 3600 then
        info = info .. string.format("%02dm%02ds", minutes, seconds)
    elseif pool.realTime < 86400 then
        info = info .. string.format("%02dh%02dm", hours, minutes)
    else
        info = info .. string.format("%dd%02dh", days, hours)
    end

    -- Append a newline to the history
    pool.history = pool.history .. info .. "\n"

    -- Write the history to the file
    local fileFTracker = io.open("fitnesstracker.txt", "w")
    fileFTracker:write(pool.history)
    fileFTracker:close()

    -- Set breakthrough coordinates
    pool.breakthroughX = marioX
    pool.breakthroughZ = genome.fitstate.area

    -- Call the indicatorOutput function
    indicatorOutput()
end

function levelNameOutput()
	getPositions()
	fileLevel = io.open("level.txt","w")
	
	fileLevel:write(currentWorld.."-"..currentLevel)
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
	pool.realTime = os.time()-ProgramStartTime
	fileRealTime:write(numToTime(pool.realTime))
	fileGameTime:write(numToTime(math.floor(pool.totalTime/FPS)))
	fileRealTime:close()
	fileGameTime:close()
end

--Drawing/GUI functions
function toRGBA(ARGB) --Converts to a color
    return bit.lshift(ARGB, 8) + bit.rshift(ARGB, 24)
end

function drawbox(x,y,color) --Draws a hollow 16x16 box
	gui.drawbox(x,y,x+15,y,color,color)
	gui.drawbox(x,y,x,y+15,color,color)
	gui.drawbox(x+15,y,x+15,y+15,color,color)
	gui.drawbox(x,y+15,x+15,y+15,color,color)
end

function fillbox(x,y,color,colorF) --Fills in a 16x16 box
	gui.drawbox(x,y,x+15,y+15,colorF,colorF)
	drawbox(x,y,text,color)
end

require "drawtext"
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
		interrupt:write("restartprog = mariobotfilename")
		interrupt:close()
		local initialize = io.open("initialize.lua","w")
		initialize:write("loadPool('backups/current.lua')")
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

function displayGUI(network, fitstate) --Displays various toggleable components of the GUI
	updateParticles()
	if DisplayGrid > 0 then --Display a large input grid around Mario's actual position
		--Loop through each position
		for x=-BoxRadius,BoxRadius do
			for y=-BoxRadius,BoxRadius do
				i = network.neurons[1+x+BoxRadius+(y+BoxRadius)*BoxWidth].value --Find the correct neuron of the inputs
				color = toRGBA(0x00000000) --Transparent color scheme
				if i == 1 then
					color = toRGBA(0xCF7F7F7F)
				end
				if i == -1 then
					color = toRGBA(0x7FFF3F00)
				end
				if DisplayGrid == 2 then --Solid color scheme
					color = toRGBA(0xFF000000)
					if i == 1 then
						color = toRGBA(0xFF7F7F7F)
					end
					if i == -1 then
						color = toRGBA(0xFFFF3F00)
					end
				end
				--Draw that box
				fillbox(marioScreenX+x*16,marioY+y*16 - 16,toRGBA(0xFFFFFFFF),color)
			end
		end
	end
	if DisplayRanges then --Display special fitness ranges
		local levelstring = "" --string to represent the level and subworld, to index Ranges
		if LostLevels == 1 then levelstring = "LL" end
		levelstring = levelstring .. currentWorld .. "-" .. currentLevel .. " " .. fitstate.area
		local ranges = Ranges[levelstring]
		if ranges ~= nil then
			for r=1,#ranges do
				--default values for parts without ranges
				local minx = 0
				local maxx = 65536
				local miny = 0
				local maxy = 240
				local range = ranges[r]
				--if range limits exist set the limits to those
				if range.xrange.min ~= nil then minx = range.xrange.min end
				if range.xrange.max ~= nil then maxx = range.xrange.max end
				if range.yrange.min ~= nil then miny = range.yrange.min+16 end
				if range.yrange.max ~= nil then maxy = range.yrange.max+16 end
				
				--set color based on the direction of fitness increase
				local rgb = 0x003FFF
				textcolor = toRGBA(0xFFFFFFFF)
				if range.coeffs.x == 1 and range.coeffs.y == 1 then
					rgb=0x3FFF00
					textcolor = toRGBA(0xFF000000)
				end
				if range.coeffs.x == 0 and range.coeffs.y == 0 then
					rgb=0xFF3F00
				end
				if range.coeffs.y == -1 then
					rgb=0xFFBF00
				end
				if range.coeffs.x == -1 then
					rgb=0xBF7F00
				end
				
				color = toRGBA(0xFF000000 + rgb)
				--draw the box
				gui.drawbox(minx-marioX+marioScreenX-1,miny,maxx-marioX+marioScreenX-2,maxy-1,toRGBA(0x7F000000 + rgb),toRGBA(0x7F000000 + rgb))
				gui.drawbox(minx-marioX+marioScreenX-1,miny,minx-marioX+marioScreenX-1,maxy-1,color,color)
				gui.drawbox(minx-marioX+marioScreenX-1,miny,maxx-marioX+marioScreenX-2,miny,color,color)
				gui.drawbox(minx-marioX+marioScreenX-1,maxy-1,maxx-marioX+marioScreenX-2,maxy-1,color,color)
				gui.drawbox(maxx-marioX+marioScreenX-2,miny,maxx-marioX+marioScreenX-2,maxy-1,color,color)
				--draw the numbers in the corners that show the fitness values
				local TLcorner = minx*range.coeffs.x+(208-miny)*range.coeffs.y+range.coeffs.c
				local TRcorner = maxx*range.coeffs.x+(208-miny)*range.coeffs.y+range.coeffs.c
				local BLcorner = minx*range.coeffs.x+(192-maxy)*range.coeffs.y+range.coeffs.c
				local BRcorner = maxx*range.coeffs.x+(192-maxy)*range.coeffs.y+range.coeffs.c
				gui.drawtext(minx-marioX+marioScreenX,miny+1,TLcorner,textcolor,color)
				gui.drawtext(maxx-marioX+marioScreenX-6*string.len(TRcorner)-1,miny+1,TRcorner,textcolor,color)
				gui.drawtext(minx-marioX+marioScreenX,maxy-8,BLcorner,textcolor,color)
				gui.drawtext(maxx-marioX+marioScreenX-6*string.len(TRcorner)-1,maxy-8,BRcorner,textcolor,color)
			end
		end
	end
		
	if DisplaySprites then --Display a hitbox around each sprite
		for s=1,#spriteHitboxes do
			local ex = spriteHitboxes[s]["x"]
			local ey = spriteHitboxes[s]["y"]
			local typ = spriteHitboxes[s]["t"]
			local data = spriteHitboxes[s]["d"]
			--Draw hitbox
			drawbox(ex-marioX+marioScreenX,ey-28,toRGBA(0xFF7F3F00))
			if typ ~= nil then --If original sprite and not an enlarged box, also put sprite data
				gui.drawtext(ex-marioX+marioScreenX,ey-28,data,-1)
				gui.drawtext(ex-marioX+marioScreenX,ey-20,typ,-1)
			end
		end
		--Draw a box around Mario
		drawbox(marioScreenX,marioY,toRGBA(0xFF00FF00))
	end
	
	if DisplaySlots then --Display what type of sprite is in each slot
		for slot=0,5 do
			gui.drawtext(230,159+slot*12,slot,-1) --Draw the slot number
			local typ = spriteSlots[slot]
			if typ ~= nil then --If the slot is full put the sprite ID
				local typstr = tostring(typ)
				if typ < 10 then --If single digit put a 0 in front
					typstr = "0" .. typstr
				end
				gui.drawtext(240,159+slot*12,typstr,-1)
			else --If the slot is empty put XX
				gui.drawtext(240,159+slot*12,"XX",-1)
			end
		end
		gui.drawtext(230,219,"*",-1) --Slot 5 is a special slot so put a *
	end
	if DisplayNetwork then --Display the neural network state
		local neurons = {} --Array that will contain the position and value of each displayed neuron
		local i = 1
		for dy=-BoxRadius,BoxRadius do --Add the input box neurons
			for dx=-BoxRadius,BoxRadius do
				network.neurons[i].x = 20+5*(dx+BoxRadius)
				network.neurons[i].y = 40+5*(dy+BoxRadius)
				i = i + 1
			end
		end
		
		local botRowSpacing = 10 --Number of pixels between oscillating nodes
		
		local botRowSize = (3 + #InitialOscillations)*2 - 1
		if botRowSize > BoxWidth then
			botRowSpacing = 5 --If bottom row can't fit then have no spacing
		end
		
		for j=0,#InitialOscillations do --Add the bias and oscillation neurons
			network.neurons[i].x = 15+BoxWidth*5-botRowSpacing*j
			network.neurons[i].y = 45+BoxWidth*5
			i = i + 1
		end
		
		for j=0,1 do --Add the bias and oscillation neurons
			network.neurons[i].x = 20+botRowSpacing*j
			network.neurons[i].y = 45+BoxWidth*5
			i = i + 1
		end
		
		for l=1,#network.layers do --Draw each layer in the NN
			local layer = network.layers[l]
			for n=1,#layer do
				if l > 1 or layer[n] > Inputs then --display only non-inputs in layer 1
					network.neurons[layer[n]].x = math.ceil(15+BoxWidth*5+(216-BoxWidth*5)*((l-1) / (#network.layers))-0.5)
					network.neurons[layer[n]].y = math.ceil(35+(BoxWidth+3)*5*(n / (#layer+1))-0.5)
				end
			end
		end
		
		--Orange box to surround the input box area
		gui.drawbox(17,37,18+BoxWidth*5,37,toRGBA(0xFF000000),toRGBA(0xFF000000))
		gui.drawbox(17,37,17,38+BoxWidth*5,toRGBA(0xFF000000),toRGBA(0xFF000000))
		gui.drawbox(18+BoxWidth*5,37,18+BoxWidth*5,38+BoxWidth*5,toRGBA(0xFF000000),toRGBA(0xFF000000))
		gui.drawbox(17,38+BoxWidth*5,18+BoxWidth*5,38+BoxWidth*5,toRGBA(0xFF000000),toRGBA(0xFF000000))
		gui.drawbox(17,37,18+BoxWidth*5,38+BoxWidth*5,toRGBA(0x7FFF7F00),toRGBA(0x7FFF7F00))
		for n,neuron in pairs(network.neurons) do --Draw each neuron
			color = math.floor((neuron.value+1)/2*256) --Color from white to black to represent -1 to 1
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0x1000000*math.floor(math.abs(neuron.value)*255) --More transparent closer to 0
			inversecolor = (color - 255) * (-1) --Opposite color for the border
			bordercolor = 0xAF000000 + inversecolor*0x10000 + inversecolor*0x100 + inversecolor
			color = opacity + color*0x10101
			if neuron.x == nil then
				neuron.x = 0
				neuron.y = 0
			end
			if n < 0 or n > BoxSize or neuron.value ~= 0 then --Don't draw an unfilled border for input box
				gui.drawbox(neuron.x-2,neuron.y-2,neuron.x+2,neuron.y+2,toRGBA(bordercolor),toRGBA(bordercolor)) --Draw border
			end
			gui.drawbox(neuron.x-1,neuron.y-1,neuron.x+1,neuron.y+1,toRGBA(color),toRGBA(color)) --Draw interior
			--Draw each gene coming into that neuron
			for g,gene in pairs(neuron.incoming) do
				if gene.enabled then
					local n1 = network.neurons[gene.into]
					local layerdiff = neuron.layer - n1.layer
					--Green or red for positive or negative weight
					local color = 0x3FFF00
					if gene.weight < 0 then
						color = 0xFF3F00
					end
					local opacity = 0xFF000000
					if gene.into > BoxSize and gene.into <= Inputs then --fade or remove if bottom-row neuron
						if #network.genes > 100 then
							opacity = 0x00000000
						elseif #network.genes > 50 then
							opacity = 0x7F000000
						end
					end
					if n1.value == 0 then --fade or remove if not transmitting a value
						if #network.genes > 50 then
							opacity = 0x00000000
						else
							opacity = 0x7F000000
						end
					end
					--draw the genome
					color = opacity + color
					if n1 and neuron then
						if n1.x and neuron.x then
							gui.drawline(n1.x+2,n1.y,neuron.x-2,neuron.y, toRGBA(color))
						else
							--Handle the case where either n1.x or neuron.x is nil
							print("Warning: 'x' field is nil in either n1 or neuron. Skipping line drawing.")
						end
					else
						--Handle the case where either n1 or neuron is nil
						print("Warning: n1 or neuron is nil. Skipping line drawing.") --This should let the program keep running even when it can't draw the network. Seems to work
					end
				end
			end
		end
		--When to block opposite directional inputs
		local blockUD = network.neurons[-3] ~= nil and network.neurons[-4] ~= nil and network.neurons[-3].value>0 and network.neurons[-4].value>0
		local blockLR = network.neurons[-5] ~= nil and network.neurons[-6] ~= nil and network.neurons[-5].value>0 and network.neurons[-6].value>0
		for o = 1,6 do
			local x = 230
			local y = math.ceil(35+(BoxWidth+3)*5*(o / 7)-0.5)
			local neuron = network.neurons[-o]
			local blocked = false --if the input was blocked because of an opposite directional input
			if blockUD and (o == 3 or o == 4) then blocked = true end
			if blockLR and (o == 5 or o == 6) then blocked = true end
			--pick the colors
			if neuron == nil or neuron.value <= 0 then
				color = 0xFF000000
				bordercolor = 0xAFFFFFFF
				tcolor = 0xFF777777
			elseif blocked then
				color = 0xFFFF3F00
				bordercolor = 0xAF000000
				tcolor = 0xFF777777
			else
				color = 0xFFFFFFFF
				bordercolor = 0xAF000000
				tcolor = 0xFF0000FF
			end
			gui.drawbox(x-2,y-2,x+2,y+2,toRGBA(bordercolor),toRGBA(bordercolor)) --Draw border
			gui.drawbox(x-1,y-1,x+1,y+1,toRGBA(color),toRGBA(color)) --Draw interior
			gui.drawtext(x+5, y-4, string.sub(ButtonNames[o],1,1), toRGBA(tcolor), 0x0) --Draw the first letter of the button name
			if neuron ~= nil then
				if neuron.value == 0 then --draw line between output and ouput box.
					gui.drawline(neuron.x+2,neuron.y,x-2,y,toRGBA(0x7F3FFF00)) --fade if not sending anything
				else	
					gui.drawline(neuron.x+2,neuron.y,x-2,y,toRGBA(0xFF3FFF00))
				end
			end
		end
	end
	if DisplayStats then
		if maxFitnessPerArea[fitstate.area] ~= nil then
			local areaMaxFitness = maxFitnessPerArea[fitstate.area].fitness
			local areaMaxFitnessX = maxFitnessPerArea[fitstate.area].x
			if areaMaxFitness ~= nil and areaMaxFitnessX ~= nil and fitstate.area == "Level" then
				local flagX = areaMaxFitnessX - marioX + marioScreenX
				local flagY = 192

				gui.drawbox(flagX + 9, flagY, flagX + 17, flagY + 6, toRGBA(0xFFFF0000), toRGBA(0xFFFF0000))
				gui.drawbox(flagX + 7, flagY, flagX + 8, flagY + 16, toRGBA(0xFFFFFFFF), toRGBA(0xFFFFFFFF))
			end
		end
		local completed = pool.currentGenome
		local total = 0
		for s=1,#pool.species do
			total = total + #pool.species[s].genomes
			if s < pool.currentSpecies then
				completed = completed + #pool.species[s].genomes
			end
		end
		local backgroundColor = toRGBA(0xFFFFFFFF)
        gui.drawbox(0, 0, 260, 31, backgroundColor, backgroundColor)
        gui.drawtext(5, 11, "Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " (" .. math.floor(completed/total*100) .. "%) ".. "Pop: ".. total, toRGBA(0xFF000000), 0x0)
        gui.drawtext(5, 21, "Fitness: " .. fitstate.fitness , toRGBA(0xFF000000), 0x0) --the (timeout + timeoutBonus)*2/3 makes sure that the displayed fitness remains stable for the viewers pleasure
        gui.drawtext(80, 21, "Max Fitness: " .. pool.maxFitness .. " (".. pool.secondFitness .. ") (" .. pool.maxCounter .. "x)", toRGBA(0xFF000000), 0x0)
	end
	if DisplayCounters then
		local days = math.floor(pool.totalTime/86400/FPS)
		local hours = math.floor((pool.totalTime-days*86400*50)/3600/FPS)
		local minutes = math.floor((pool.totalTime-(days*24+hours)*3600*50)/60/FPS)
		gui.drawtext(5,210,"Time: "..days.."d "..hours.."h "..minutes.."m",-1)
		gui.drawtext(5,220,"Deaths: "..pool.deaths,-1)
		gui.drawtext(5,230,"Attempts: "..pool.attempts,-1)
	end
	if Replay then
		local text = "Replay"
		local textColor = toRGBA(0xFFFFFFFF)
		local backgroundColor = toRGBA(0xFF003FFF)
		local charWidth = 8
		local textWidth = charWidth * string.len(text)
		local textHeight = 10

		local textX = (256 - textWidth) / 2 + 95
		local textY = 220
		
		gui.drawbox(textX - 4, textY - 4, textX + textWidth + 4, textY + textHeight + 4, backgroundColor, backgroundColor)

		drawtext.draw(text, textX, textY, textColor, 0x0)
	end
end

function initializeBackupDirectory()
    local directory = "backups"..dirsep..currentWorld.."-"..currentLevel
    local command = ""

    -- Check the operating system
    if os.getenv("OS") and os.getenv("OS"):match("Windows") then
        command = 'mkdir "' .. directory .. '" > NUL 2>&1'  -- Command for Windows
    else
        command = 'mkdir -p "' .. directory .. '"'  -- Command for Unix/Linux
    end

    -- Execute the command to create the directory if it doesn't exist
    os.execute(command)
end

function initLevel()
	initPool()
	local file = io.open("backups"..dirsep.."winners.txt","r")
	i = 1
	if file then
		while true do
			winnername = file:read("*line")
			if not winnername then break end
			dofile(winnername)
			addToSpecies(loadedgenome)
			pool.species[i].nick = loadedgenome.nick
			i=i+1
		end
	end
	for g=i,1000 do
		local genome = newGenome(1)
		mutate(genome,1)
		addToSpecies(genome)
	end
	init = loadfile("initialize.lua")
	initializeclear = io.open("initialize.lua","w")
	if initializeclear then initializeclear:close() end
	if init then init() end
	fileFTracker = io.open("fitnesstracker.txt","w")
	fileFTracker:write(pool.history)
	fileFTracker:close()
	levelNameOutput()
	indicatorOutput()
end

initLevel()
initializeBackupDirectory()
while true do
	redospectop = pool.generation == 0
	while not playGeneration(redospectop) do
		newGeneration()
		redospectop = false
	end
	savestateSlot=savestateSlot+1
	if savestateSlot==10 then savestateSlot=1 end
	savestateObj = savestate.object(savestateSlot)
	savestate.save(savestateObj)
	initLevel()
	initializeBackupDirectory()
	if Replay and #pool.breakthroughfiles == 0 then --This is useful for getting through the generations where Mario does a lot of standing around
		TurboMax = 1
		turboOutput()
		Replay = false
		print("TurboMax set to "..TurboMax)
	end
end

return true
