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

#### About NASM

[NASM](https://www.nasm.us/) (Netwide Assembler) is an open-source x86/x64 assembler that's been around since 1996. If you're coming from Visual Studio, NASM is the equivalent of `ml64.exe` (MASM) but with a few key differences:

- **Intel syntax** (like MASM) — `mov rax, rcx` not AT&T's `movq %rcx, %rax`
- **Flat, explicit style** — no MASM magic like `INVOKE` or `.IF/.ENDIF`. You write exactly what you mean.
- **Cross-platform** — same source assembles on Windows, Linux, macOS (just different output formats)
- **No Visual Studio dependency** — it's a standalone ~700 KB executable. Download, unzip, done.

The output format we use is `win64` (aka COFF64) — the same `.obj` format that MSVC produces. So NASM slots into the Windows PE toolchain cleanly.

**Why not MASM?** You *could* use `ml64.exe` from Visual Studio — it'd work fine. But MASM requires the full VS/Build Tools install (~4+ GB) just to get that one executable. NASM gives you the assembler in a 700 KB download.

#### About GoLink

[GoLink](http://www.godevtool.com/) is a tiny PE linker written by Jeremy Gordon (hence "Go" — nothing to do with the Go language). It's specifically designed for assembly programming on Windows. Coming from Visual Studio, it replaces `link.exe` — but it's ~50 KB instead of requiring the entire MSVC toolchain.

Key differences from `link.exe`:

- **No lib files needed** — you just name the DLLs directly: `golink ... kernel32.dll`. It resolves imports from the DLLs themselves at link time. With MSVC's linker you'd need `.lib` import libraries.
- **No CRT baggage** — MSVC's linker wants to pull in `mainCRTStartup`, exception handlers, security cookies, etc. GoLink links exactly what you tell it, nothing more.
- **Minimal PE output** — it produces the smallest valid PE it can. No padding, no extra sections, no `/DYNAMICBASE` or `/NXCOMPAT` overhead unless you ask for it.
- **Single exe** — ~50 KB, no dependencies, no install.

The tradeoff: GoLink is old-school (last updated ~2017) and doesn't support everything `link.exe` does (no incremental linking, no PDB debug info, no LTCG). But for a project like this where the goal is "smallest valid PE binary," it's perfect.

#### Quick setup

1. Download NASM — grab the latest `win64` zip from the [releases page](https://www.nasm.us/pub/nasm/releasebuilds/)
2. Download GoLink — single zip from [godevtool.com](http://www.godevtool.com/#GoLink)
3. Extract both, put `nasm.exe` and `golink.exe` somewhere on your `PATH` (or just drop them in this directory)

Total toolchain size: **under 1 MB**. Compare that to Visual Studio Build Tools at 4+ GB.

#### Alternative: Build with Visual Studio

If you'd rather use your existing VS install, you can substitute MASM + MSVC's linker:

```cmd
ml64 /c snooze.asm
link /ENTRY:Start /SUBSYSTEM:CONSOLE /NODEFAULTLIB snooze.obj kernel32.lib
```

You'll need a "x64 Native Tools Command Prompt" for this. The binary will be slightly larger (~3–4 KB) due to MSVC's linker adding more PE metadata, but it works.

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

### What's happening in the assembly

If you're used to C, here's the mental model:

```c
// This is essentially what snooze.asm does:
void Start(void) {
    char* cmdline = GetCommandLineA();  // "snooze.exe 5"
    // skip past "snooze.exe " manually
    int seconds = parse_int(cmdline);   // hand-rolled atoi
    Sleep(seconds * 1000);
    ExitProcess(0);
}
```

The assembly just does this without any runtime support. The Windows x64 calling convention puts the first four arguments in `RCX, RDX, R8, R9` (with 32 bytes of "shadow space" reserved on the stack). Every `call` in the program follows this convention.

### The Windows x64 calling convention

Since you're a Visual Studio guy, you'll recognize this — it's the same ABI your C code compiles to:

| Param | Register | Notes |
|-------|----------|-------|
| 1st | RCX | Integer/pointer args |
| 2nd | RDX | |
| 3rd | R8 | |
| 4th | R9 | |
| 5th+ | Stack | At `[RSP+32]`, `[RSP+40]`, etc. |

**Shadow space**: Caller must always reserve 32 bytes on the stack before `call`, even if the function takes fewer than 4 args. This is for the callee to spill registers if needed. That's what the `sub rsp, 56` at the top is about (32 shadow + alignment + locals).

**Return value**: RAX.

## Size comparison

| Implementation | Typical size |
|---------------|-------------|
| This (NASM + GoLink) | ~2 KB |
| MASM + MSVC link /NODEFAULTLIB | ~3–4 KB |
| C with MSVC `/O1` + CRT | ~8–10 KB |
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
