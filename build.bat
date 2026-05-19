@echo off
REM build.bat — Assemble and link snooze.exe
REM Requires: nasm.exe and golink.exe on PATH (or in this directory)

echo [1/2] Assembling...
nasm -f win64 snooze.asm -o snooze.obj
if errorlevel 1 (
    echo FAILED: nasm assembly error
    exit /b 1
)

echo [2/2] Linking...
golink /entry:Start /console snooze.obj kernel32.dll
if errorlevel 1 (
    echo FAILED: golink error
    exit /b 1
)

echo.
echo Done! snooze.exe built successfully.
for %%A in (snooze.exe) do echo Size: %%~zA bytes
del snooze.obj 2>nul
