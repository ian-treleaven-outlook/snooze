; snooze.asm — Tiny Windows suspend-to-RAM utility in x86-64 assembly
; No C runtime. Calls SetSuspendState from powrprof.dll.
; Usage: snooze [/h]
;   snooze     — suspend to RAM (S3 sleep)
;   snooze /h  — hibernate (S4, save to disk)
;
; Build: nasm -f win64 snooze.asm -o snooze.obj
;        golink /entry:Start /console snooze.obj kernel32.dll powrprof.dll
;
; Resulting binary is typically ~2 KB.

bits 64
default rel

; --- Win32 imports ---
extern GetCommandLineA          ; kernel32.dll
extern ExitProcess              ; kernel32.dll
extern SetSuspendState          ; powrprof.dll

; BOOLEAN SetSuspendState(
;   BOOLEAN bHibernate,              // FALSE=sleep(S3), TRUE=hibernate(S4)
;   BOOLEAN bForce,                  // TRUE=force (don't ask apps)
;   BOOLEAN bWakeupEventsDisabled    // TRUE=disable wake events
; );

section .text
global Start

;-----------------------------------------------------------------------------
; Entry point
;-----------------------------------------------------------------------------
Start:
    sub     rsp, 40             ; 32 shadow + 8 alignment

    ; Get the raw command line string
    call    GetCommandLineA
    mov     rsi, rax            ; RSI = pointer to command line

    ; Skip the program name (may be quoted)
    cmp     byte [rsi], '"'
    je      .skip_quoted

.skip_unquoted:
    cmp     byte [rsi], 0
    je      .do_sleep           ; No arguments = default sleep
    cmp     byte [rsi], ' '
    je      .skip_spaces
    inc     rsi
    jmp     .skip_unquoted

.skip_quoted:
    inc     rsi                 ; skip opening quote
.sq_inner:
    cmp     byte [rsi], 0
    je      .do_sleep
    cmp     byte [rsi], '"'
    je      .sq_done
    inc     rsi
    jmp     .sq_inner
.sq_done:
    inc     rsi                 ; skip closing quote

    ; Skip whitespace between program name and argument
.skip_spaces:
    cmp     byte [rsi], ' '
    jne     .check_arg
    inc     rsi
    jmp     .skip_spaces

.check_arg:
    ; Check if we have /h or -h (hibernate)
    cmp     byte [rsi], 0
    je      .do_sleep           ; No argument = sleep

    ; Check for /h, /H, -h, -H
    cmp     byte [rsi], '/'
    je      .check_h
    cmp     byte [rsi], '-'
    je      .check_h
    jmp     .do_sleep           ; Unknown arg, default to sleep

.check_h:
    inc     rsi
    cmp     byte [rsi], 'h'
    je      .do_hibernate
    cmp     byte [rsi], 'H'
    je      .do_hibernate
    jmp     .do_sleep           ; Unknown flag, default to sleep

;-----------------------------------------------------------------------------
; Suspend to RAM (S3)
; SetSuspendState(FALSE, FALSE, FALSE)
;-----------------------------------------------------------------------------
.do_sleep:
    xor     ecx, ecx           ; bHibernate = FALSE
    xor     edx, edx           ; bForce = FALSE
    xor     r8d, r8d           ; bWakeupEventsDisabled = FALSE
    call    SetSuspendState

    xor     ecx, ecx
    call    ExitProcess

;-----------------------------------------------------------------------------
; Hibernate (S4)
; SetSuspendState(TRUE, FALSE, FALSE)
;-----------------------------------------------------------------------------
.do_hibernate:
    mov     ecx, 1             ; bHibernate = TRUE
    xor     edx, edx           ; bForce = FALSE
    xor     r8d, r8d           ; bWakeupEventsDisabled = FALSE
    call    SetSuspendState

    xor     ecx, ecx
    call    ExitProcess
