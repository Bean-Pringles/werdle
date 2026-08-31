import std/[strutils, tables, times, sets, os, cmdline]
import ui
import wordgen
import after

# Base directory where this source file lives
const baseDir = currentSourcePath().parentDir()

# Helper to resolve relative paths against the source directory
proc resolvePath(path: string): string =
  if isAbsolute(path): path
  else: baseDir / path

const WordsFile = resolvePath("config/words.txt")
const LogFile = resolvePath("config/days.txt")

proc scoreGuess(guess: string, secret: string): tuple[correctPos,
        presentPos: seq[int]] =
    var remaining = initCountTable[char]()
    for ch in secret:
        remaining.inc(ch)

    var correctPos, presentPos: seq[int]

    for i in 0..4:
        if guess[i] == secret[i]:
            correctPos.add(i)
            remaining.inc(guess[i], -1)

    for i in 0..4:
        if guess[i] != secret[i] and remaining[guess[i]] > 0:
            presentPos.add(i)
            remaining.inc(guess[i], -1)

    (correctPos, presentPos)

proc isValidGuess(guess: string, dict: HashSet[string]): bool =
    guess in dict

proc loadWordSet(filename: string): HashSet[string] =
    let path = resolvePath(filename)
    var s = initHashSet[string]()
    for line in readFile(path).splitLines():
        let w = line.strip().toUpperAscii()
        if w.len == 5:
            s.incl(w)
    s

proc main() =
    let args = commandLineParams()

    # Display args if there is
    if len(args) > 0:
        if "--stats" in args:
            printStats(resolvePath("config/stats.json"))
        else:
            echo "Unknown args passed" 
    
    else:

        let secret = getWord(WordsFile).strip().toUpperAscii()

        let validWords = loadWordSet(WordsFile)

        let utcTime = now().utc()
        let today = utcTime.format("yyyy-M-d")

        if lastPlayedDate(LogFile) == today:
            let streak = calculateStreak(LogFile)
            echo "You have already done the Werdle for today. The word was ", secret, "."
            echo "Current streak: ", streak, " days."
            return

        var board: Board
        for r in board.mitems:
            for c in r.mitems:
                c = Cell(letter: '\0', state: lsEmpty)

        var keyStates: array['A'..'Z', LetterState]
        for k in keyStates.mitems: k = lsEmpty

        var row = 0
        var col = 0
        var won = false
        var quit = false

        enableRawMode()

        while row < 6:
            render(board, keyStates, row + 1)
            let key = readKey()
            case key.kind
            of kQuit:
                quit = true
                break
            of kLetter:
                if col < 5:
                    board[row][col] = Cell(letter: key.ch, state: lsEmpty)
                    col.inc
            of kBackspace:
                if col > 0:
                    col.dec
                    board[row][col] = Cell(letter: '\0', state: lsEmpty)
            of kEnter:
                if col == 5:
                    var guess = ""
                    for cell in board[row]:
                        guess.add(cell.letter)

                    if not isValidGuess(guess, validWords):
                        echo "\nNot in word list."
                        sleep(1000)
                        continue

                    let (correctPos, presentPos) = scoreGuess(guess, secret)
                    for p in correctPos:
                        board[row][p].state = lsCorrect

                    for p in presentPos:
                        board[row][p].state = lsPresent

                    board[row].finalize()
                    syncKeyboard(board[row], keyStates)

                    if guess == secret:
                        won = true
                        row.inc
                        break

                    row.inc
                    col = 0
            of kOther:
                discard

        disableRawMode()
        render(board, keyStates, min(row, 6))

        if quit:
            echo "\nQuit — come back and finish today's word later."
            return

        recordPlay(LogFile)

        if won:
            echo "\nYou got it! The word was ", secret, "."
        else:
            echo "\nOut of guesses. The word was ", secret, "."

        let streak = calculateStreak(LogFile)
        echo "Current streak: ", streak, " days."

        recordStats(resolvePath("config/stats.json"), won, streak, row)

main()