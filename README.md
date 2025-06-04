# MarioBot

## Transparency
This project has been refined almost entirely with the help of AI tools such as Google's Gemini and OpenAI's ChatGPT and Codex.

## What
MarioBot is a NEAT-based program that learns to play **Super Mario Bros.** (1985). An additional version, **LuigI/O**, targets **Super Mario Bros. 3**. These programs began as community projects from Akisame and Electra, building upon SethBling's original *MarI/O* implementation.

The code runs as a Lua plug-in for the FCEUX emulator. While the SMB3 version remains mostly untouched, this repository focuses on continuing the development of MarioBot for the 1985 game.

## Why
I found this project fascinating after watching the [LuigI/O YouTube channel](https://www.youtube.com/@LuigIO) several years ago. I preferred exploring ROM hacks of the original game rather than moving entirely to Super Mario Bros. 3, so this repository concentrates on that direction.

## Goal
The long-term goal is to advance MarioBot to the point where it can tackle challenging ROM hacks—ideally even kaizo-level hacks—as consistently as possible. Although I am unsure of the ultimate limits of the NEAT approach, I aim to push the program as far as it can go.

## Current Limitations
- **Non-linear stages**: Levels that require backtracking or complex navigation are difficult without substantial hardcoding, which would defeat the purpose of the project.
- **Extreme difficulty**: Very hard or "kaizo" levels—for example, the *Super Mario Forever* (aka *Super Mario Frustration*) hack—are currently beyond the AI's abilities.
