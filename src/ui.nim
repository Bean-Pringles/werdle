import std/[terminal, strutils, posix, times]
import posix/termios

## Minimal Werdle TUI frontend. This file only draws things.
## You own the game logic - call `render()` whenever your state changes.

type
    LetterState* = enum
        lsEmpty, lsAbsent, lsPresent, lsCorrect

    Cell* = object
        letter*: char # ' ' if empty
        state*: LetterState

    Board* = array[6, array[5, Cell]]

const
    KeyboardRows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

proc colorFor(s: LetterState): tuple[fg: ForegroundColor, bg: BackgroundColor] =
    case s
    of lsCorrect: (fgBlack, bgGreen)
    of lsPresent: (fgBlack, bgYellow)
    of lsAbsent: (fgWhite, bgBlack)
    of lsEmpty: (fgWhite, bgDefault)

proc writeCell(c: Cell) =
    let (fg, bg) = colorFor(c.state)
    stdout.setBackgroundColor(bg)
    stdout.setForegroundColor(fg)
    let ch = if c.letter == '\0': ' ' else: c.letter
    stdout.write(" " & $ch & " ")
    stdout.resetAttributes()

proc drawBoard(board: Board) =
    let border = "  +---+---+---+---+---+"
    for row in board:
        echo border
        stdout.write("  |")
        for cell in row:
            writeCell(cell)
            stdout.write("|")
        stdout.write("\n")
    echo border

proc drawKeyboard(keyStates: array['A'..'Z', LetterState]) =
    echo ""
    for i, rowStr in KeyboardRows:
        stdout.write(" ".repeat(i * 2 + 2)) # simple stagger, tweak as you like
        for ch in rowStr:
            let (fg, bg) = colorFor(keyStates[ch])
            stdout.setBackgroundColor(bg)
            stdout.setForegroundColor(fg)
            stdout.write(" " & $ch & " ")
            stdout.resetAttributes()
            stdout.write(" ")
        stdout.write("\n")

proc render*(board: Board, keyStates: array['A'..'Z', LetterState],
             attempt: int, maxAttempts: int = 6) =
    eraseScreen()
    setCursorPos(0, 0)

    # Get days since August 30th, 2026
    let pastDate = parse("2026-08-30", "yyyy-MM-dd")
    let today = now()
    let daysPassed = ((today - pastDate).inDays) + 1

    echo "    Werdle Puzzle #", $daysPassed
    drawBoard(board)
    drawKeyboard(keyStates)

# --- raw keypress input (POSIX terminals only) ---

type
    KeyKind* = enum
        kLetter, kEnter, kBackspace, kQuit, kOther

    Key* = object
        kind*: KeyKind
        ch*: char # valid when kind == kLetter

var origTermios: Termios

proc enableRawMode*() =
    discard tcGetAttr(STDIN_FILENO, addr origTermios)
    var raw = origTermios
    raw.c_lflag = raw.c_lflag and not Cflag(ICANON or ECHO)
    discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr raw)

proc disableRawMode*() =
    discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr origTermios)

proc readKey*(): Key =
    var c: char
    if read(STDIN_FILENO, addr c, 1) != 1:
        return Key(kind: kOther)
    case c
    of '\r', '\n':
        Key(kind: kEnter)
    of '\x7f', '\b':
        Key(kind: kBackspace)
    of '\x03', '\x1b': # Ctrl-C or Esc
        Key(kind: kQuit)
    of 'a'..'z':
        Key(kind: kLetter, ch: char(ord(c) - 32)) # uppercase it
    of 'A'..'Z':
        Key(kind: kLetter, ch: c)
    else:
        Key(kind: kOther)

# --- guess-scoring helpers ---
# Call these on a single row (board[row]), 0-indexed positions (0..4).
# Any position you don't mark correct/present is assumed absent once
# you call finalize().

proc correct*(row: var array[5, Cell], positions: varargs[int]) =
    for p in positions:
        row[p].state = lsCorrect

proc present*(row: var array[5, Cell], positions: varargs[int]) =
    for p in positions:
        row[p].state = lsPresent

proc finalize*(row: var array[5, Cell]) =
    for cell in row.mitems:
        if cell.state == lsEmpty:
            cell.state = lsAbsent

proc syncKeyboard*(row: array[5, Cell], keyStates: var array['A'..'Z',
        LetterState]) =
    # Upgrades a key's color, never downgrades it (correct beats present beats absent),
    # since a letter might be gray in one guess and yellow/green in a later one.
    for cell in row:
        if cell.letter == '\0': continue
        if ord(cell.state) > ord(keyStates[cell.letter]):
            keyStates[cell.letter] = cell.state

# --- demo loop, delete once you wire up your own state/logic ---
when isMainModule:
    var board: Board
    for r in board.mitems:
        for c in r.mitems:
            c = Cell(letter: '\0', state: lsEmpty)

    var keyStates: array['A'..'Z', LetterState]
    for k in keyStates.mitems: k = lsEmpty

    var row = 0
    var col = 0

    enableRawMode()

    while row < 6:
        render(board, keyStates, row + 1)
        let key = readKey()
        case key.kind
        of kQuit:
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
                # Wire your backend here, e.g.:
                #   board[row].correct(0, 2)      # positions 0 and 2 are green
                #   board[row].present(4)         # position 4 is yellow
                #   board[row].finalize()         # everything else -> gray
                #   syncKeyboard(board[row], keyStates)
                row.inc
                col = 0
        of kOther:
            discard

    disableRawMode()
