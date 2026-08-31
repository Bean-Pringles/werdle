import std/[strutils, times, os, json]

# Get most recent date in file
proc lastPlayedDate*(filename: string): string =
    if not fileExists(filename):
        return ""

    var lastLine: string
    for line in lines(filename):
        let stripped = line.strip()
        if stripped.len > 0:
            lastLine = stripped

    return lastLine

# Calculate consecutive-day streak
proc calculateStreak*(filename: string): int =
    if not fileExists(filename):
        return 0

    var dates: seq[DateTime] = @[]

    for line in lines(filename):
        let stripped = line.strip()
        if stripped.len == 0:
            continue
        try:
            dates.add(parse(stripped, "yyyy-M-d").utc())
        except:
            discard

    if dates.len == 0:
        return 0

    var streak = 1
    var expected = dates[^1] - 1.days

    for i in countdown(dates.high - 1, 0):
        if dates[i] == expected:
            streak += 1
            expected = dates[i] - 1.days
        else:
            break

    return streak

# Record that today was played (only once per day)
proc recordPlay*(filename: string) =
    let today = now().utc().format("yyyy-M-d")

    if lastPlayedDate(filename) == today:
        return  # already recorded today

    let f = open(filename, fmAppend)
    defer: f.close()
    f.writeLine(today)

proc loadStats(filename: string): JsonNode =
    if not fileExists(filename):
        return %*{
            "played": 0,
            "win_percentage": 0.0,
            "wins": 0,
            "losses": 0,
            "current_streak": 0,
            "best_streak": 0,
            "guess_distribution": {
                "1": 0,
                "2": 0,
                "3": 0,
                "4": 0,
                "5": 0,
                "6": 0
            },
            "avg_guess": 0.0
        }

    let j = parseFile(filename)

    # Safety fallback if file is corrupted or missing fields
    if not j.hasKey("guess_distribution"):
        j["guess_distribution"] = %*{
            "1": 0,
            "2": 0,
            "3": 0,
            "4": 0,
            "5": 0,
            "6": 0
        }

    return j

proc saveStats(filename: string, j: JsonNode) =
    writeFile(filename, pretty(j))

proc recordStats*(filename: string, won: bool, streak: int, row: int) =
    var j = loadStats(filename)

    # Ensure guess distribution exists
    if not j.hasKey("guess_distribution"):
        j["guess_distribution"] = newJObject()

    # Update Games Played
    j["played"] = % (j["played"].getInt() + 1)

    # Update Win/Loss
    if won:
        j["wins"] = % (j["wins"].getInt() + 1)
    else:
        j["losses"] = % (j["losses"].getInt() + 1)

    # Update Win Percentage (float-safe)
    j["win_percentage"] = % (
        (j["wins"].getInt().float / j["played"].getInt().float) * 100.0
    )

    # Update Streak Stats
    j["current_streak"] = % streak
    let best = j["best_streak"].getInt()
    if streak > best:
        j["best_streak"] = % streak

    # Update Guess Distribution
    let dist = j["guess_distribution"]
    let key = $row

    if dist.hasKey(key):
        dist[key] = % (dist[key].getInt() + 1)
    else:
        dist[key] = % 1

    # Compute Average Guess
    var totalGames = 0
    var weightedSum = 0

    for k, v in dist:
        let guessNum = parseInt(k)
        let count = v.getInt()

        totalGames += count
        weightedSum += guessNum * count

    var avgGuess: float = 0.0
    if totalGames > 0:
        avgGuess = weightedSum.float / totalGames.float

    j["avg_guess"] = % avgGuess

    saveStats(filename, j)

proc printBar(label: string, value: int, maxValue: int, width = 20) =
    let barLen =
        if maxValue == 0:
            0
        else:
            (value.float / maxValue.float * width.float).int

    let bar = repeat("█", barLen)
    echo label.alignLeft(2), " | ", bar, " ", value

proc printStats*(filename: string) =
    var j = loadStats(filename)

    echo "Games Played: ", $(j["played"].getInt())
    echo "Win %: ", $(j["win_percentage"].getFloat())
    echo "\nCurrent Streak: ", $(j["current_streak"].getInt())
    echo "Best Streak: ", $(j["best_streak"].getInt())

    echo "\nGuess Distribution:"

    # extract distribution
    let dist = j["guess_distribution"]

    var maxVal = 0
    for i in 1..6:
        let v = dist[$i].getInt()
        if v > maxVal:
            maxVal = v

    for i in 1..6:
        let v = dist[$i].getInt()
        printBar($i, v, maxVal)
    
    echo "\nAvg. Guess: ", $(j["avg_guess"].getFloat())