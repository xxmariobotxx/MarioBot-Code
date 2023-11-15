MarioBot v0.1

FIRST AND FOREMOST: This script is not complete yet as evidenced by 'test' on the file Mariobot-V1-test.lua, but the program should work as it stands now. This repo is available for anyone to dowload and run on their machines, systems, computers, or
(my favorite), boxes. Credit where credit is due: This program was first written by Sethbling with MarI/O, updated by Akisame with LuigI/O, and it is my quest to revive this bot that was online and ended in 2020. I stream this bot on https://twitch.tv/xxmariobot where I have it complete rom hacks.


An AI to play Super Mario Bros and Lost Levels

To run, first set up a savestate in slot 1 (or in any other slot, the used slot is set in the variable savestateSlot)

Make sure to set LostLevels to 1 if playing lost levels, and 0 otherwise.
Set Player to 2 if playing as Luigi in SMB1, and 1 otherwise.

Open the Lua script "mariobot-launcher.lua" to start.

Buttons:
A - activates the generation stats bar at the top
C - activates the death and time counter display
E - activates special fitness region display
G - activates large vision grid
N - activates the neural network display
O - activates sprite slot display
R - activates sprite hitbox display

L - loads the latest completed generation

M - switches to manual control

Interrupts:
A new feature in version 4 is interrupts. This will allow you to run Lua commands to change variables and even make updates without restarting the program.
To make an interrupt just put a lua command or commands into "interrupt.lua" and save.
To restart the program in an interrupt, set "restartprog" to the filename of the LuigI/O program. This can also be done after a crash.

DAISIO:
To view graphs of the AI's progress, run "daisio.jar"
Set the world you are viewing using the settings button on the left. (Lost levels worlds start with LL)
To open a graph press the + button and then the graph button.
The settings button in the top right corner lets you set what is displayed on the graph.
Top row:
MIN BQT MED TQT MAX - the min/max, median, and quartiles of the population
AVG - the average of the population (red = avg only, yellow = stdev as well)
AVM - the average of the species maximums (red = avg only, yellow = stdev as well)
Bottom row:
MIN BQT MED TQT MAX - the min/max, median, and quartiles of each selected species
AVG - the average of each species (red = avg only, yellow = stdev as well)
NTS - color codes the species by network switch count rather than GSID.
Species select:
ALL - displays all species
Generation - displays all species that existed in whatever gen # you type in
Individuals - displays a specific species with whatever GSID you type in
Note: When running a level you have previously run again, you must delete the previous files for that level in both "backups" and "data", or else the graph will be corrupted using data from the previous run.

Lua Console Discord Bot:
To make it easier to perform interrupts on the program we have a way to connect the interrupts to discord. Put your bot's token and the channel id on the server you want to use into the lua console python program and run it, and anything in that channel said using consolas font (`) or in block code text (```) will be run as an interrupt if it contains no errors.

Minimap:
To automatically change the minimap, the minimap.py program is included. Running this while the AI runs will set the 5 minimap files to display in map/current to the correct levels, and put the 2 indicators on them. This can be switched between 2 and 3 sections of the map using mapnum.txt. Only the lost levels minimaps up to 8-4 are included.

Stream Outputs:
There are a few files that the program will generate that can be used in stream displays.
attempts.txt - which attempt the ai is on
deaths.txt - number of deaths (does not include timeouts)
fitnesstracker.txt - list of the breakthroughs in the level
gametime.txt - time elapsed in-game
spindicatorpos.txt - x position and stage of current species top, used for the map indicator
indicatorpos.txt - x position and stage of best genome, used for the map indicator
level.txt - which level is being played
realtime.txt - time elapsed in real time
speciesdata.txt - data for current species with gsid, smax, stale, and nick
turbo.txt - the current set turbo range
