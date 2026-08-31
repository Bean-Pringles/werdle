import std/times
import std/os

# Base directory where this source file lives
const baseDir = currentSourcePath().parentDir()

# Helper to resolve relative paths against the source directory
proc resolvePath(path: string): string =
  if isAbsolute(path): path
  else: baseDir / path

# Get Nth line of the file
proc getNthLine(filename: string, targetLine: int): string =
    let path = resolvePath(filename)
    if not fileExists(path):
        raise newException(IOError, "File not found: " & path)

    var currentLine = 1
    for line in lines(path):
        if currentLine == targetLine:
            return line
        inc(currentLine)

    raise newException(IndexDefect, "Line " & $targetLine & " exceeds file length.")

# Count total lines in file
proc countLines(filename: string): int =
    let path = resolvePath(filename)
    if not fileExists(path):
        raise newException(IOError, "File not found: " & path)

    var count = 0
    for _ in lines(path):
        inc(count)
    return count

# Random Num from Seed
proc randInt(min, max: int, seed: int): int =
    var x = uint64(seed)

    x = x xor (x shr 12)
    x = x xor (x shl 25)
    x = x xor (x shr 27)
    x = x * 2685821657736338717'u64

    let range = uint64(max - min + 1)
    return min + int(x mod range)

# Seed Generator
proc genSeed(s: string): int =
    var hash: uint32 = 2166136261'u32
    for c in s:
        hash = hash xor uint32(ord(c))
        hash = hash * 16777619'u32
    return int(hash)

# === PUBLIC FUNCTION ===
proc getWord*(filename: string = "config/words.txt"): string =
    let utcTime = now().utc()
    let date = utcTime.format("yyyy-M-d")

    let seed = genSeed(date)
    let numWords = countLines(filename)
    let randNum = randInt(1, numWords, seed)

    return getNthLine(filename, randNum)