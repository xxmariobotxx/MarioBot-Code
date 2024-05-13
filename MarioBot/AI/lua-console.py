import discord
import asyncio
import re

TOKEN = "" #Insert discord bot token here

CHANNELID = "" #Insert channel ID here

client = discord.Client()

@client.event
async def on_message(message):
    if message.author == client.user:
        return
    if str(message.channel.id) == CHANNELID:
        code = ""
        for i in re.findall("`(``(?=(lua\n|))|)\\2?((`(?!\\1)|[^`])*)`\\1",message.content):
            code += i[2]+"\n"
        with open("interrupt.lua",mode="w") as f:
            f.write(code)

async def main_loop():
    output = None
    for channel in client.get_all_channels():
        if str(channel.id) == CHANNELID:
            output = channel
    while True:
        await asyncio.sleep(5)
        with open("discord.txt") as f:
            message = f.read()
            if len(message) > 0:
                await client.send_message(output, message)
                with open("discord.txt",mode="w") as overwrite:
                    overwrite.write("")
    
@client.event
async def on_ready():
    print('Logged in as')
    print(client.user.name)
    print(client.user.id)
    print('------')
    client.loop.create_task(main_loop())

client.run(TOKEN)
