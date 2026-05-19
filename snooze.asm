; snooze.asm — Tiny Windows sleep utility in x86-64 assembly
; No C runtime. No imports beyond kernel32.dll.
; Usage: snooze <seconds>
;
; Build: nasm -f win64 snooze.asm -o snooze.obj
;        golink /entry:Start /console snooze.obj kernel32.dll
;
; Resulting binary is typically ~2 KB.

bits 64
default rel

; --- Win32 imports (kernel32.dll) ---
extern GetCommandLineA
extern GetStdHandle
extern WriteFile
extern Sleep
extern ExitProcess

section .data
    usage       db "snooze: sleep for N seconds (no C runtime, pure x64 asm)", 13, 10
                db "Usage: snooze <seconds>", 13, 10, 0
    usage_len   equ $ - usage - 1

    err_nan     db "Error: argument must be a positive integer", 13, 10, 0
    err_nan_len equ $ - err_nan - 1

section .bss
    written     resd 1          ; for WriteFile bytes-written param

section .text
global Start

;-----------------------------------------------------------------------------
; Entry point
;-----------------------------------------------------------------------------
Start:
    sub     rsp, 56             ; 32 shadow + 8 align + 16 local space

    ; Get the raw command line string
    call    GetCommandLineA
    mov     rsi, rax            ; RSI = pointer to command line

    ; Skip the program name (may be quoted)
    cmp     byte [rsi], '"'
    je      .skip_quoted

.skip_unquoted:
    cmp     byte [rsi], 0
    je      .show_usage
    cmp     byte [rsi], ' '
    je      .skip_spaces
    inc     rsi
    jmp     .skip_unquoted

.skip_quoted:
    inc     rsi                 ; skip opening quote
.sq_inner:
    cmp     byte [rsi], 0
    je      .show_usage
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
    ; Check we actually have an argument
    cmp     byte [rsi], 0
    je      .show_usage

    ; --- Parse decimal integer from RSI ---
    xor     rax, rax            ; accumulator = 0
    xor     rcx, rcx            ; temp for digit

.parse_loop:
    movzx   ecx, byte [rsi]
    cmp     cl, '0'
    jb      .parse_done
    cmp     cl, '9'
    ja      .parse_done
    imul    rax, rax, 10
    sub     cl, '0'
    add     rax, rcx
    inc     rsi
    jmp     .parse_loop

.parse_done:
    ; Verify we consumed at least one digit and stopped at end/space
    cmp     byte [rsi], 0
    je      .valid_end
    cmp     byte [rsi], ' '
    je      .valid_end
    cmp     byte [rsi], 13      ; CR
    je      .valid_end
    cmp     byte [rsi], 10      ; LF
    je      .valid_end
    jmp     .show_nan           ; non-digit garbage in argument

.valid_end:
    test    rax, rax
    jz      .show_usage         ; 0 seconds = probably a mistake, show usage

    ; Multiply seconds → milliseconds (seconds * 1000)
    imul    rcx, rax, 1000

    ; --- Call Sleep(milliseconds) ---
    ; Windows x64 ABI: first param in RCX (already there)
    call    Sleep

    ; --- ExitProcess(0) ---
    xor     ecx, ecx
    call    ExitProcess

;-----------------------------------------------------------------------------
; Print usage and exit(1)
;-----------------------------------------------------------------------------
.show_usage:
    ; GetStdHandle(STD_ERROR_HANDLE = -12)
    mov     ecx, -12
    call    GetStdHandle
    ; WriteFile(handle, usage, len, &written, NULL)
    mov     rcx, rax
    lea     rdx, [usage]
    mov     r8d, usage_len
    lea     r9, [written]
    mov     qword [rsp+32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess

;-----------------------------------------------------------------------------
; Print NaN error and exit(1)
;-----------------------------------------------------------------------------
.show_nan:
    mov     ecx, -12
    call    GetStdHandle
    mov     rcx, rax
    lea     rdx, [err_nan]
    mov     r8d, err_nan_len
    lea     r9, [written]
    mov     qword [rsp+32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess
