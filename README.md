# Werdle

A simple terminal-based (TUI) Wordle clone.

## Setup

From the root directory, run 

```shell 
nim c -d:release --opt:speed ./src/werdle.nim
```

This compiles the program. Next, to add it to path, run

Windows:

```shell
python ./setup/setup.py
```

Linux/MacOS:

```shell
python3 ./setup/setup.py
```

After this, you can run the command `werdle` and it will launch the program

## Algorithm

Werdle does not fetch the daily word from a server. In fact, it can be played completely offline.

Instead, Werdle takes the current UTC date and generates a hash from it. That hash is then transformed into a seed for a pseudorandom function, which selects the word of the day from the word list.

This ensures:
- A new word every day
- The same word for every player worldwide
- Fully offline gameplay

## Features

Werdle includes a variety of features, such as:

- Guess highlighting (correct / present / absent)
- Variety of gameplay statistics
- Completely offline gameplay
- Same word list as the original Wordle
- New word every day at UTC midnight

## Stats

The stats screen (accessible with the `--stats` flag) displays a variety of tracked metrics:

- Games Played
- Win Percentage
- Current Streak
- Best Streak
- Guess Distribution
- Average Guess Count