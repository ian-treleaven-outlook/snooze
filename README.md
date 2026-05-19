# snooze

A tiny Windows sleep utility written in **x86-64 assembly**. No C runtime, no dependencies beyond `kernel32.dll`.

```
> snooze 5
```

Sleeps for 5 seconds. That's it.

## Why?

Because `timeout /t 5 /nobreak >nul` is ugly, `Start-Sleep` requires PowerShell, and the real question is: *how small can a useful Windows binary get?*

**Answer: ~2 KB.**

## Building

### Prerequisites

You need two tools — both are single portable executables, no install required:

| Tool | What it does | Download |
|------|-------------|----------|
| **NASM** | Netwide Assembler — assembles `.asm` → `.obj` | [nasm.us/pub/nasm/releasebuilds/](https://www.nasm.us/pub/nasm/releasebuilds/) |
| **GoLink** | Tiny linker — links `.obj` → `.exe` (no MSVC needed) | [godevtool.com/#GoLink](http://www.godevtool.com/#GoLink) |

**Quick setup:**

1. Download NASM (grab the latest `win64` zip from the releases page)
2. Download GoLink (single zip)
3. Extract both, put `nasm.exe` and `golink.exe` somewhere on your `PATH` (or just drop them in this directory)

### Build

```cmd
build.bat
```

Or manually:

```cmd
nasm -f win64 snooze.asm -o snooze.obj
golink /entry:Start /console snooze.obj kernel32.dll
```

That's it. Two commands, ~2 KB output.

## How it works

The entire program:

1. `GetCommandLineA` — gets the raw command line string
2. Parses the first argument as a decimal integer (hand-rolled, no `atoi`)
3. Multiplies by 1000 (seconds → milliseconds)
4. `Sleep(ms)` — the one API call that matters
5. `ExitProcess(0)`

No C runtime startup, no `mainCRTStartup`, no exception handlers, no TLS callbacks, no import tables beyond what's needed. Just raw entry point → Win32 → done.

## Size comparison

| Implementation | Typical size |
|---------------|-------------|
| This (NASM + GoLink) | ~2 KB |
| C with MSVC `/O1` + CRT | ~8–10 KB |
| C with `#pragma comment(linker, "/NODEFAULTLIB")` | ~3–4 KB |
| Go | ~2 MB |
| Rust (stripped) | ~150 KB |
| Python (frozen) | ~7 MB |

## Usage

```cmd
snooze 30        REM sleep 30 seconds
snooze 1         REM sleep 1 second
snooze 3600      REM sleep 1 hour
```

Exit codes:
- `0` — slept successfully
- `1` — bad arguments (prints usage to stderr)

## License

Public domain. Do whatever you want with it.
