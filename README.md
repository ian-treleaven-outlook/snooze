# snooze

A tiny Windows sleep/hibernate utility written in **x86-64 assembly**. No C runtime, no dependencies beyond `kernel32.dll` and `powrprof.dll`.

```
> snooze
```

Puts the computer to sleep (S3 suspend). That's it.

```
> snooze /h
```

Hibernates (S4 — saves RAM to disk, full power off).

## Why?

Windows makes "put the computer to sleep from a script/shortcut" weirdly annoying:

- `rundll32 powrprof.dll,SetSuspendState 0,1,0` — works but ugly, and if hibernation is enabled it hibernates instead of sleeping (classic gotcha)
- PowerShell `Add-Type` + `[System.Windows.Forms.Application]::SetSuspendState(...)` — loads the entire .NET runtime to call one function
- Third-party tools — why install an app for this?

**snooze** is a 1.5 KB binary that does exactly one thing. Drop it in your PATH, make a desktop shortcut, bind it to a hotkey — done.

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

- **No lib files needed** — you just name the DLLs directly: `golink ... kernel32.dll powrprof.dll`. It resolves imports from the DLLs themselves at link time. With MSVC's linker you'd need `.lib` import libraries.
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

If you'd rather use your existing VS install, you can substitute MASM + MSVC's linker. Note: NASM syntax differs slightly from MASM, so you'd need a small port — or just use the NASM/GoLink approach (it's simpler for this).

### Build

```cmd
build.bat
```

Or manually:

```cmd
nasm -f win64 snooze.asm -o snooze.obj
golink /entry:Start /console snooze.obj kernel32.dll powrprof.dll
```

That's it. Two commands, 1,536 bytes output.

## How it works

The entire program calls one Windows API:

```c
// powrprof.dll
BOOLEAN SetSuspendState(
    BOOLEAN bHibernate,           // FALSE = sleep (S3), TRUE = hibernate (S4)
    BOOLEAN bForce,               // TRUE = don't send PBT_APMQUERYSUSPEND to apps
    BOOLEAN bWakeupEventsDisabled // TRUE = disable scheduled wake events
);
```

That's the same API that the Start menu's "Sleep" button calls under the hood. Unlike the `rundll32` hack, calling `SetSuspendState(FALSE, ...)` directly will always sleep (not accidentally hibernate).

### What the assembly does

```c
// Pseudocode equivalent:
void Start(void) {
    char* cmdline = GetCommandLineA();
    bool hibernate = has_flag(cmdline, "/h");
    SetSuspendState(hibernate, FALSE, FALSE);
    ExitProcess(0);
}
```

### The Windows x64 calling convention

| Param | Register | Notes |
|-------|----------|-------|
| 1st | RCX | Integer/pointer args |
| 2nd | RDX | |
| 3rd | R8 | |
| 4th | R9 | |
| 5th+ | Stack | At `[RSP+32]`, `[RSP+40]`, etc. |

**Shadow space**: Caller must always reserve 32 bytes on the stack before `call`, even if the function takes fewer than 4 args. That's what the `sub rsp, 40` at the top is about (32 shadow + 8 alignment).

## Usage

```cmd
snooze           REM sleep (S3 suspend to RAM)
snooze /h        REM hibernate (S4 suspend to disk)
snooze -h        REM same thing
```

### Desktop shortcut

1. Right-click desktop → New → Shortcut
2. Target: `C:\path\to\snooze.exe`
3. Optional: give it a nice icon, pin to taskbar, or bind to a hotkey

### Note on privileges

`SetSuspendState` typically works without admin rights (it uses the same path as the Start menu sleep button). However, Group Policy can restrict sleep/hibernate — if it doesn't work, check Power Options.

## Size comparison

| Implementation | Typical size |
|---------------|-------------|
| This (NASM + GoLink) | 1,536 bytes |
| C with `#pragma comment(linker, "/NODEFAULTLIB")` | ~3–4 KB |
| C with MSVC `/O1` + CRT | ~8–10 KB |
| Go | ~2 MB |
| Rust (stripped) | ~150 KB |
| `rundll32` one-liner | 0 KB (but unreliable for sleep vs. hibernate) |

## License

Public domain. Do whatever you want with it.
