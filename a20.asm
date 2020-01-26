BITS 16

;This is the OFFSET of the boot signature p-address (7dfeh) when 
;accessed 1MiB higher (107dfeh) thank to the wrap around, via the 0ffffh segment (107dfeh = 0ffffh:7e0eh)
%define BOOT_SIG_ALIAS  (7c00h + 200h - 2h + 10h)  

ORG 7c00h 

  xor ax, ax               ;My BIOS's CSM need this (or variant) to be the first instruction
  mov ds, ax               ;DS <- 0000
  mov ss, ax
  xor sp, sp               ;SS:SP <- 0000:0000
 
  jmp 0000:WORD __START__  
       
_BZONE:
  ;Skip eventual VBR patches 
  TIMES 1eh db 0h
                    
__START__:

  mov ax, 0003h
  int 10h                  ;Go to a known video mode, so we can realibly output chars

  ;Greeting
  mov di, 80*2
  mov si, strOK
  call print

  ;#### TEST IF A20 LINE IS ENABLED###
  
  ;Check the boot signature
  mov ax, 0ffffh
  mov es, ax               ;ES <- FFFF (For wrap-around check)
  cmp WORD [es:BOOT_SIG_ALIAS], 0aa55h       ;Equal iif A20 line is *disabled*    
  jne .try_disable                           ;This jumps iif the A20 is *enabled*

    ;A20 line is disabled
  
    mov si, strA20Disabled
    call print

    ;STOP, the A20 line can surely be enabled. Nothing to test here.

  jmp .end


.try_disable:

  mov si, strTryDisable
  call print
  
  ;### TEST IF A20 LINE CAN BE DISABLED ###

  mov ax, 2403h       
  int 15h                   ;A20 gate support
  jc .no_bios_support
  test ah, ah
  jnz .no_bios_support

  

  mov si, strBiosMethods
  call print 

  ;BIOS SUPPORT

  ;Let's see what we got
  ;BX : bit0 = KBC supports a20, bit1 = fast a20

  mov ax, bx
  and ax, 03h
  add ax, 0c30h               ;An either RED "0" (None), "1" (KBC only), "2" (fast a20 only) or "3" (both)
  stosw

  mov si, strBiosDisable
  call print
                  
  ;Try with the BIOS

  mov ax, 2400h
  int 15h                     ;Disable the A20 line
  jc .no_bios_support
  test ah, ah
  jnz .no_bios_support

  mov si, strBiosDone
  call print

  mov dx, 1  ;Remember we can from the BIOS

 jmp .test_still_enabled

.no_bios_support:

  mov si, strNoBios
  call print 
  ;Here AH is either 01h (KBC in secure mode) or 86h (function not supported)

  mov al, ah
  and al, 01h                 ;AL = 1 (KBC in secure mode) or 0 (func not supported)
  add ax, 0c30h               ;A RED "0" (func not supported) or "1" (KBC in secure mode)
  stosw

.disable:
  
  mov si, strDisabling
  call print

  ;Ignore the bios
  call disable_a20

  mov si, strBiosDone
  call print

  xor dx, dx

.test_still_enabled:

  mov si, strOK
  call print 

  mov si, strStillEnabled

  mov ax, 0ffffh
  mov es, ax
  cmp WORD [es:BOOT_SIG_ALIAS], 0aa55h
  jne .not_yet_disabled

  mov si, strDisabled
  xor dx, dx

.not_yet_disabled:
  call print

  cmp dx, 1
  je .disable
  

.end:
 
  cli
  hlt

wait_ob_full:
  in al, 64h
  test al, 01h
  jz wait_ob_full
  ret

wait_ib_empty:
  in al, 64h
  test al, 02h
  jnz wait_ib_empty
  ret

send_cmd:
  push ax
  call wait_ib_empty
  pop ax
  out 64h, al
  ret

send_cmd_and_read:
  call send_cmd

  call wait_ob_full
  in al, 60h
  ret 

send_cmd_and_write:
  call send_cmd

  push ax
  call wait_ib_empty
  pop ax
  mov al, ah
  out 60h, al 
  ret 


disable_a20:
  mov al, 0adh
  call send_cmd     ;Disable PS1, no response

  mov al, 0d0h
  call send_cmd_and_read  ;Read COP

  and al, 0fdh

  mov ah, al
  mov al, 0d1h
  call send_cmd_and_write ;Write COP

  mov al, 0aeh  
  call send_cmd     ;Enable PS1, no response

  ;Fast A20 line *disable*
  in al, 92h
  and al, 0fch
  out 92h, al

  ;Bah!
  out 0eeh, al 

  ret

  ;SI = String
print:
  push ax

  push 0b800h
  pop es
  mov ah, 09h
 
.show:
  lodsb
  test al, al
  jz .end

  stosw
jmp .show  

.end:
  pop ax
  ret

  strOK db "Testing A20 line.", 0
  strA20Disabled db "A20 line already disabled by BIOS.", 0
  strTryDisable db "Trying disabling A20 line with BIOS.", 0
  strBiosMethods db "Bios methods: ", 0
  strBiosDisable db ". Disabling with BIOS.", 0
  strBiosDone db "Done.", 0
  strNoBios db "No BIOS support for that: ", 0
  strDisabling db ". Disabling manually.", 0
  strStillEnabled db "Still enabled.", 0
  strDisabled db "Disabled.", 0

TIMES 510 - ($-$$) db 0
dw 0aa55h




