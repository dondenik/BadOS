;TODO:
;fix bug where cmds cant start with the same letter
;enforce file size limit in txt
;fix bug where if a file is a full page txt breaks (maybe to do with enter encoding exceeding bounds)
;add calculator (talk to Nathan about something like "reverse polish" or something)
;add support for binary executables
;add more associated file types
;add more general cmds
;add PRNG (pseudorandom number generator) (perhaps xorshift)
;add interpreted language support
;snake
;make cmp_cmd's more dynamic and programtical so you can add cmds on the fly
bits 16
org 0x8000
entry:
cld
call clear_screen_widetext
mov word [input_msg_indexer], input_msg
mov si, loaded_kernel
call print_str
jmp handle_enter
hang:
mov ah, 0x10
int 0x16
cmp ah, 'K'
je .handle_left_arrow
;cmp ah, 'H'
;je .handle_up_arrow
cmp ah, 'M'
je .handle_right_arrow
;cmp ah, 'P'
;je .handle_down_arrow
mov [input_char], al
cmp al, 08
je .check_start_input_del
.carry_on:
mov si, input_char
call print_str
mov al, [input_char]
cmp al, 13
je handle_enter
cmp al, 08
je handle_backspace
mov bx, [input_msg_indexer]
mov [bx], al
add word [input_msg_indexer], 1
mov bx, input_msg
add bx, 127
cmp [input_msg_indexer], bx
je no_input_hang
jmp hang
.check_start_input_del:
mov bx, [input_msg_indexer]
cmp bx, input_msg
je hang
jmp handle_backspace
.handle_left_arrow:
mov bx, [input_msg_indexer]
cmp bx, input_msg
je hang
dec byte [cursor_x]
call set_cursor_pos
dec byte [input_msg_indexer]
jmp hang
.handle_right_arrow:
mov bx, [input_msg_indexer]
cmp byte [bx], 0
je hang
inc byte [cursor_x]
call set_cursor_pos
inc byte [input_msg_indexer]
jmp hang
no_input_hang:
mov ah, 0x10
int 0x16
cmp al, 13
je handle_enter
cmp al, 08
je handle_backspace
jmp no_input_hang
print_str:
lodsb
call set_cursor_pos
mov ah, 0x09
mov bl, 0x0F
mov cx, 1
cmp al, 0
je done
cmp al, 13
je .handle_13
cmp al, 10
je .handle_10
int 0x10
inc byte [cursor_x]
call set_cursor_pos
jmp print_str
.handle_13:
inc byte [cursor_y]
call set_cursor_pos
jmp print_str
.handle_10:
mov byte [cursor_x], 0
call set_cursor_pos
jmp print_str
set_cursor_pos:
mov ah, 0x02
mov bh, 0
mov dh, [cursor_y]
mov dl, [cursor_x]
int 0x10
ret
get_cursor_chr:
;chr at cursor
mov ah, 0x08
mov bh, 0
int 0x10
ret
replace_chr:
;Replace {AL} with {AH} in a string
;IN: SI: Input String, AL: Char To Replace, AH: Char To Replace With
;OUT: SI: Start Of Strings, BX: End Of Strings
push si
dec si
.looop:
inc si
cmp byte [si], 0
je .replace_done
cmp byte [si], al
jne .looop
mov byte [si], ah
jmp .looop
.replace_done:
mov bx, si
pop si
ret
split_str:
;split a string by {AL} (replace AL with 0)
;IN: SI: Input String, AL: Char To Split BY
;OUT: SI: Start Of Strings, BX: End Of Strings
mov ah, 0
call replace_chr
ret
clear_str:
;clears the INPUT_MSG (not for other things)
mov bx, [input_msg_indexer]
mov byte [bx], 0
cmp bx, input_msg
je done
sub byte [input_msg_indexer], 1
jmp clear_str

get_num_str_len:
	pusha

	mov bx, ax			; Move location of string to BX

	mov cx, 0			; Counter

.more:
	cmp byte [bx], 48		; Zero (end of string) yet?
	jl .done
	cmp byte [bx], 57
	jg .done
	cmp byte [bx], 0
	je .done
	inc bx				; If not, keep adding
	inc cx
	jmp .more


.done:
	mov word [.tmp_counter], cx	; Store count before restoring other registers
	popa

	mov ax, [.tmp_counter]		; Put count back into AX before returning
	ret


	.tmp_counter	dw 0

; ------------------------------------------------------------------
; os_string_to_int -- Convert decimal string to integer value
; IN: SI = string location (max 5 chars, up to '65536')
; OUT: AX = number

str2int:
pusha

	mov ax, si			; First, get length of string
	call get_num_str_len

	add si, ax			; Work from rightmost char in string
	mov word [.end_nums], si
	dec si

	mov cx, ax			; Use string length as counter

	mov bx, 0			; BX will be the final number
	mov ax, 0


	; As we move left in the string, each char is a bigger multiple. The
	; right-most character is a multiple of 1, then next (a char to the
	; left) a multiple of 10, then 100, then 1,000, and the final (and
	; leftmost char) in a five-char number would be a multiple of 10,000

	mov word [.multiplier], 1	; Start with multiples of 1

.loop:
	mov ax, 0
	mov byte al, [si]		; Get character
	sub al, 48			; Convert from ASCII to real number

	mul word [.multiplier]		; Multiply by our multiplier

	add bx, ax			; Add it to BX

	push ax				; Multiply our multiplier by 10 for next char
	mov word ax, [.multiplier]
	mov dx, 10
	mul dx
	mov word [.multiplier], ax
	pop ax

	dec cx				; Any more chars?
	cmp cx, 0
	je .finish
	dec si				; Move back a char in the string
	jmp .loop

.finish:
	mov word [.tmp], bx
	popa
	mov word ax, [.tmp]
	mov word si, [.end_nums]

	ret


	.multiplier	dw 0
	.tmp		dw 0
	.end_nums dw 0
; ------------------------------------------------------------------
; os_int_to_string -- Convert unsigned integer to string
; IN: AX = unsigned int
; OUT: AX = string location

int2str:
; 'borrowed' from MikeOS 4.5 Mirror GitHub under the name "os_int_to_string"
	pusha

	mov cx, 0
	mov bx, 10			; Set BX 10, for division and mod
	mov di, .t			; Get our pointer ready

.push:
	mov dx, 0
	div bx				; Remainder in DX, quotient in AX
	inc cx				; Increase pop loop counter
	push dx				; Push remainder, so as to reverse order when popping
	test ax, ax			; Is quotient zero?
	jnz .push			; If not, loop again
.pop:
	pop dx				; Pop off values in reverse order, and add 48 to make them digits
	add dl, '0'			; And save them in the string, increasing the pointer each time
	mov [di], dl
	inc di
	dec cx
	jnz .pop

	mov byte [di], 0		; Zero-terminate string

	popa
	mov ax, .t			; Return location of string
	ret


	.t times 7 db 0

debug:
pusha
call int2str
mov si, ax
call print_str
inc byte [cursor_y]
call set_cursor_pos
popa
pusha
mov ax, bx
call int2str
mov si, ax
call print_str
inc byte [cursor_y]
call set_cursor_pos
popa
pusha
mov ax, cx
call int2str
mov si, ax
call print_str
inc byte [cursor_y]
call set_cursor_pos
popa
pusha
mov ax, dx
call int2str
mov si, ax
call print_str
inc byte [cursor_y]
call set_cursor_pos
popa
ret
debug_gft:
pusha
mov bx, GFT
mov si, bx
pusha
call print_str
popa
call .goto_end_of_str
inc bx
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
add bx, 2
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
add bx, 2
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
add bx, 2
mov si, bx
pusha
call print_str
popa
call .goto_end_of_str
inc bx
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
add bx, 2
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
add bx, 2
mov ax, word [bx]
call int2str
mov si, ax
pusha
call print_str
popa
popa
ret
.goto_end_of_str:
cmp bx, 0
je .goto_end_of_str_done
inc bx
jmp .goto_end_of_str
.goto_end_of_str_done:
ret
get_file:
;in: string file name in bx
;out: AX: Start, BX: End, CX: extensions, DI: found or not (1: found, 0: not found)
mov [.input_filename], bx
mov si, GFT
.get:
cmp si, word [end_GFT]
je .get_file_not_found
mov bx, [.input_filename]
call cmp_str
je .match
jne .goto_next_filename
.goto_next_filename:
cmp byte [si], 0
jne .goto_eofn
add si, 7
jmp .get
.input_filename dw 0
.goto_eofn:
inc si
cmp byte [si], 0
je .goto_next_filename
jmp .goto_eofn
.match:
inc si
mov ax, word [si]
add si, 2
mov bx, word [si]
add si, 2
mov cx, word [si]
mov di, 1
ret
.get_file_not_found:
mov di, 0
ret
disk_load:
; load DH sectors to ES:BX from drive DL
;arguements: dh: num of sectors to read, cl: location of first sector
mov bx, 0x1000
mov es, bx
mov bx, 0
push dx ; Store DX on stack so later we can recall how many sectors were requested to be read even if it is altered
mov ah, 0x02 ; BIOS read sector function
mov al, dh ; Read DH sectors
mov ch, 0x01 ; Select cylinder 1
mov dh, 0x00 ; Select head 0
;mov cl, 0x00 ; Start reading from second sector (i.e. after the boot sector)
int 0x13 ; BIOS Interrupt
jc disk_error ; jump if carry flag set
pop dx ; Restore DX
cmp dh, al ; if AL (sectors read) != DH (sectors expected)
jne disk_error
mov bx, 0
mov es, bx
ret
disk_error:
mov si, disk_error_msg
call print_str
call handle_enter
jmp hang
disk_error_msg db 'DISK ERROR', 0
disk_write:
; load DH sectors to ES:BX from drive DL
;arguements: dh: num of sectors to write, cl: location of first sector
push dx ; Store DX on stack so later we can recall how many sectors were requested to be read even if it is altered
mov ah, 0x03 ; BIOS read sector function
mov al, dh ; Read DH sectors
mov ch, 0x01 ; Select cylinder 1
mov dh, 0x00 ; Select head 0
;mov cl, 0x00 ; Start reading from second sector (i.e. after the boot sector)
int 0x13 ; BIOS Interrupt
jc disk_error ; jump if carry flag set
pop dx ; Restore DX
cmp dh, al ; if AL (sectors read) != DH (sectors expected)
jne disk_error
mov bx, 0
mov es, bx
ret
clear_screen_widetext:
mov al, 02h ; al = 02h, code for video mode (80x25)
mov ah, 00h ; code for the change video mode function
int 10h ; trigger interrupt to call function
mov byte [cursor_x], 0
mov byte [cursor_y], 0
call set_cursor_pos
ret
clear_screen_nulfill:
mov al, 02h ; al = 02h, code for video mode (80x25)
mov ah, 00h ; code for the change video mode function
int 10h ; trigger interrupt to call function
mov byte [cursor_x], 0
mov byte [cursor_y], 0
call set_cursor_pos
.loup:
mov al, 0
call print_chr
cmp byte [cursor_x], 80
je .loup_eol
inc byte [cursor_x]
call set_cursor_pos
jmp .loup
.loup_eol:
cmp byte [cursor_y], 24
je .loup_done
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
jmp .loup
.loup_done:
mov byte [cursor_x], 0
mov byte [cursor_y], 0
call set_cursor_pos
ret
handle_enter:
call cmp_cmd
mov si, enter_handle_data
call print_str
.print_input:
mov si, input_msg
call print_str
.clear_input:
call clear_str
mov si, enter_handle_data
call print_str
mov si, cli_default_text
call print_str
cmp byte [cursor_y], 24
jge clr
jmp hang
handle_backspace:
dec byte [cursor_x]
call set_cursor_pos
push word [cursor_x]
push word [cursor_y]
dec byte [input_msg_indexer]
.loope:
mov bx, [input_msg_indexer]
cmp byte [bx], 0
je .done_loope
mov al, byte [bx+1]
mov byte [bx], al
mov al, [bx]
mov ah, 0x09
mov bh, 0
mov bl, 0x0F
mov cx, 1
int 0x10
inc byte [input_msg_indexer]
inc byte [cursor_x]
call set_cursor_pos
jmp .loope
.done_loope:
pop word [cursor_y]
pop word [cursor_x]
call set_cursor_pos
dec byte [input_msg_indexer]
jmp hang
handle_backspace_replace_with_space_deprecated:
dec byte [cursor_x]
call set_cursor_pos
mov ah, 0x09
mov bh, 0
mov bl, 0
mov al, 32
int 0x10
sub word [input_msg_indexer], 1
mov bx, [input_msg_indexer]
mov byte [bx], al
jmp hang
print_chr:
mov cx, 1
mov ah, 0x09
mov bh, 0
mov bl, 0x0F
int 0x10
ret
cmp_str:
.roop:
mov cl, byte [bx]
cmp byte [si], cl
jne done
cmp byte [si], 0
je done
inc si
inc bx
jmp .roop
ret
cmp_cmd:
;check if input_msg has cmd in it (currently just txt)
;will give args to the cmd program in this format: SI + 1: start of null seperated args, BX: end of args
mov si, input_msg
mov al, ' '
call split_str
push bx
mov bx, clr_cmd
call cmp_str
pop bx
je clr
push bx
mov bx, txt_cmd
call cmp_str
pop bx
je txt
push bx
mov bx, nfile_cmd
call cmp_str
pop bx
je nfile
push bx
mov bx, random_cmd
call cmp_str
pop bx
je random
push bx
mov bx, calc_cmd
call cmp_str
pop bx
je calc
push bx
mov bx, snake_cmd
call cmp_str
pop bx
je snake
ret
clr:
call clear_str
call clear_screen_widetext
mov si, cli_default_text
call print_str
jmp hang
txt:
inc si
mov bx, si ; first arg
call get_file
cmp di, 0
je .file_not_found
mov word [.file_offset], ax
call clear_screen_nulfill
mov bx, 0x1000
mov fs, bx
push word [.file_offset]
.toop:
pop bx
mov al, [fs:bx]
inc bx
push bx
call set_cursor_pos
mov ah, 0x09
mov bl, 0x0F
mov cx, 1
cmp al, 0
je .input_loop
cmp al, 13
je .handle_13
cmp al, 10
je .handle_10
int 0x10
inc byte [cursor_x]
call set_cursor_pos
jmp .toop
.handle_13:
inc byte [cursor_y]
call set_cursor_pos
jmp .toop
.handle_10:
mov byte [cursor_x], 0
call set_cursor_pos
jmp .toop
.input_loop:
mov ah, 0x10
int 0x16
;cmp to all special keys
cmp ah, 'K'
je .handle_left_arrow
cmp ah, 'H'
je .handle_up_arrow
cmp ah, 'M'
je .handle_right_arrow
cmp ah, 'P'
je .handle_down_arrow
cmp al, 08
je .handle_backspace
cmp al, 13
je .handle_enter
cmp al, 5
je .handle_exit
;---
;print input
call print_chr
;move cursor along and check if at end of line
cmp byte [cursor_x], 80
je .eol_mov_cursor
inc byte [cursor_x]
call set_cursor_pos
jmp .reloop_input_loop
.eol_mov_cursor:
inc byte [cursor_y]
mov byte [cursor_x], 0
inc byte [cursor_x]
.done_mov_cursor:
call set_cursor_pos
.reloop_input_loop:
jmp .input_loop
.handle_down_arrow:
cmp byte [cursor_y], 24
je .handle_up_arrow_eol
inc byte [cursor_y]
call set_cursor_pos
call get_cursor_chr
cmp al, 0
je .goto_eol
jmp .input_loop
.handle_down_arrow_eol:
jmp .input_loop
.handle_up_arrow:
cmp byte [cursor_y], 0
je .handle_up_arrow_eol
dec byte [cursor_y]
call set_cursor_pos
call get_cursor_chr
cmp al, 0
je .goto_eol
jmp .input_loop
.handle_up_arrow_eol:
jmp .input_loop
.handle_left_arrow:
cmp byte [cursor_x], 0
je .handle_left_arrow_eol
dec byte [cursor_x]
call set_cursor_pos
jmp .input_loop
.handle_left_arrow_eol:
cmp byte [cursor_y], 0
je .input_loop
mov byte [cursor_x], 0
dec byte [cursor_y]
call set_cursor_pos
jmp .goto_eol
.handle_right_arrow:
call get_cursor_chr
cmp al, 0
je .handle_right_arrow_eol
cmp byte [cursor_x], 80
je .handle_right_arrow_eol
inc byte [cursor_x]
call set_cursor_pos
jmp .input_loop
.handle_right_arrow_eol:
push word [cursor_y]
push word [cursor_x]
cmp byte [cursor_y], 24
je .input_loop
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
call get_cursor_chr
cmp al, 0
je .handle_right_arrow_eol_thingy
pop bx
pop bx
jmp .input_loop
.handle_right_arrow_eol_thingy:
pop word [cursor_x]
pop word [cursor_y]
call set_cursor_pos
jmp .input_loop
.handle_backspace:
cmp byte [cursor_x], 0
je .input_loop
dec byte [cursor_x]
call set_cursor_pos
mov al, ' '
call print_chr
push word [cursor_x]
push word [cursor_y]
.goop:
cmp byte [cursor_x], 80
jne .nrml_crry_on_backspace
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
jmp .input_loop
.nrml_crry_on_backspace:
inc byte [cursor_x]
call set_cursor_pos
call get_cursor_chr
dec byte [cursor_x]
call set_cursor_pos
call print_chr
call get_cursor_chr
inc byte [cursor_x]
call set_cursor_pos
cmp al, 0
jne .goop
pop word [cursor_y]
pop word [cursor_x]
call set_cursor_pos
jmp .input_loop
.handle_enter:
jmp .handle_enter_eol
.handle_enter_eol:
cmp byte [cursor_y], 24
je .input_loop
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
jmp .input_loop
.file_offset dw 0
.handle_exit:
mov bx, 0x1000
mov fs, bx
mov byte [cursor_x], 0
mov byte [cursor_y], 0
call set_cursor_pos
mov bx, [.file_offset]
add word [.file_offset], 2073
.handle_exit_loop:
cmp bx, [.file_offset]
je .handle_exit_loop_done
push bx
call get_cursor_chr
pop bx
mov [fs:bx], al
inc bx
cmp byte [cursor_x], 80
je .handle_exit_loop_eol
inc byte [cursor_x]
push bx
call set_cursor_pos
call get_cursor_chr
pop bx
cmp al, 0
je .handle_exit_loop_eol
jmp .handle_exit_loop
.handle_exit_loop_eol:
mov byte [cursor_x], 0
inc byte [cursor_y]
push bx
call set_cursor_pos
pop bx
mov byte [fs:bx], 13
inc bx
mov byte [fs:bx], 10
inc bx
jmp .handle_exit_loop
.handle_exit_loop_done:
call clear_screen_widetext
call clear_str
mov si, cli_default_text
call print_str
jmp hang
.goto_eol:
mov byte [cursor_x], 0
call set_cursor_pos
.laop:
call get_cursor_chr
cmp al, 0
je .goto_eol_done
inc byte [cursor_x]
call set_cursor_pos
jmp .laop
.goto_eol_done:
jmp .input_loop
.file_not_found:
mov si, .fnf_error_msg
call print_str
call clear_str
mov si, cli_default_text
call print_str
jmp hang
.fnf_error_msg db 13, 10, 'FILE NOT FOUND', 13, 10, 0
txt_help:
;pass
nfile:
inc si
push si
push bx
mov bx, si
call get_file
pop bx
pop si
cmp di, 0
jne .file_already_exists
mov bx, [end_GFT]
.insert_filename:
lodsb
mov byte [bx], al
inc bx
cmp al, 0
je .insert_filename_done
jmp .insert_filename
.insert_filename_done:
push bx
call str2int
pop bx
inc bx
mov cx, word [available_file_space]
add ax, cx
inc ax
mov word [available_file_space], ax
mov word [bx], cx
add bx, 2
mov word [bx], ax
add bx, 2
mov word [bx], 0
inc bx
mov word [end_GFT], bx
inc ax
mov word [available_file_space], ax
call clear_str
mov byte [cursor_x], 0
call set_cursor_pos
mov si, cli_default_text
call print_str
jmp hang
.file_already_exists:
mov si, .fae_error_msg
call print_str
call clear_str
mov si, cli_default_text
call print_str
jmp hang
.fae_error_msg db 'FILE ALREADY EXISTS', 0
nfile_help:
;pass
random:
call xorshift
call int2str
mov si, ax
mov byte [cursor_x], 0
call set_cursor_pos
call print_str
call clear_str
mov si, cli_default_text
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
call print_str
jmp hang
xorshift:      
; returns a 16-bit value >0, has a 2^32-1 period
; will change every time its called hopefully  
        push cx
        push dx
        db 0b8h                 ; t=(x^(x shl a))
random_x: dw 1
        mov dx,ax
        mov cl,5
        shl dx,cl
        xor ax,dx
        mov dx,ax               ; y=(y^(y shr c))^(t^(t shr b))
        mov cl,3                ;                  ^^^^^^^^^^^
        shr dx,cl
        xor ax,dx
        push ax                 ; save t^(t shr b)
        db 0b8h
random_y: dw 1
        mov [random_x],ax    ; x=y
        mov dx,ax               ; y=(y^(y shr c))^(t^(t shr b))
        shr dx,1                ;    ^^^^^^^^^^^
        xor ax,dx
        pop dx
        xor ax,dx
        mov [random_y],ax
        pop dx
        pop cx
        ret
calc:
inc si
cmp si, bx
jge .finish_calc
cmp byte [si], '+'
je .handle_plus
cmp byte [si], '*'
je .handle_times
cmp byte [si], '/'
je .handle_divide
cmp byte [si], '%'
je .handle_modulo
cmp byte [si], '-'
je .handle_minus
cmp byte [si], '^'
je .handle_power
cmp byte [si], 'R'
je .handle_RAND
;push the str2int version of things
call str2int
push ax
jmp calc
.handle_plus:
pop ax
pop cx
add ax, cx
push ax
call .goto_eoo
jmp calc
.handle_divide:
pop cx
pop ax
cmp cx, 0
je .divide_by_zero_error
cmp ch, 0
jne .divisor_overflow
div cl
push ax
call .goto_eoo
jmp calc
.divisor_overflow:
mov dx, 0
div cx
push ax
call .goto_eoo
jmp calc
.divide_by_zero_error:
mov si, .divide_by_zero_error_msg
call print_str
call clear_str
mov si, cli_default_text
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
call print_str
jmp hang
.divide_by_zero_error_msg db 'Bruh Did You Really Just Try To Divide By Zero?', 0
.handle_modulo:
pop cx
pop ax
cmp cx, 0
je .divide_by_zero_error
cmp ch, 0
jne .modulo_divisor_overflow
div cl
mov al, ah
mov ah, 0
push ax
call .goto_eoo
jmp calc
.modulo_divisor_overflow:
mov dx, 0
div cx
push dx
call .goto_eoo
jmp calc
.handle_minus:
pop cx
pop ax
sub ax, cx
push ax
call .goto_eoo
jmp calc
.handle_times:
pop ax
pop cx
mul cx
push ax
call .goto_eoo
jmp calc
.handle_power:
pop cx
pop ax
cmp cx, 0
je .handle_power_0
mov word [.power_base], ax
.handle_power_loop:
cmp cx, 1
je .handle_power_loop_done
mul word [.power_base]
dec cx
jmp .handle_power_loop
.power_base dw 0
.handle_power_loop_done:
push ax
call .goto_eoo
jmp calc
.handle_power_0:
mov ax, 1
push ax
call .goto_eoo
jmp calc
.handle_RAND:
inc si
cmp byte [si], 'A'
jne .handle_RAND_not
inc si
cmp byte [si], 'N'
jne .handle_RAND_not
inc si
cmp byte [si], 'D'
jne .handle_RAND_not
call xorshift
push ax
call .goto_eoo
jmp calc
.handle_RAND_not:
call debug
call .goto_eoo
jmp calc
.goto_eoo:
inc si
cmp byte [si], 0
je done
jmp .goto_eoo
.finish_calc:
pop ax
call int2str
mov si, ax
mov byte [cursor_x], 0
call set_cursor_pos
call print_str
call clear_str
mov si, cli_default_text
mov byte [cursor_x], 0
inc byte [cursor_y]
call set_cursor_pos
call print_str
jmp hang
snake:
mov byte [.direction], 0
cli
; save bios defined int 9
mov bx, word [0x24]
mov word [.bios_key_handler], bx
mov bx, word [0x26]
mov [.bios_key_handler + 2], bx
; make int 9 .key_handler
mov [0x24], word .key_handler
mov [0x26], es
sti
mov ah, 00h
mov al, 13h
int 10h
mov word [.player_x], 99
mov word [.player_y], 159
mov al, 0100b
call .mov_player
mov byte [cursor_x], 0
mov byte [cursor_y], 0
call set_cursor_pos
mov si, snake_cmd
call print_str
.loop: 
mov al, 0
mov ah, 86h
mov cx, 1
mov dx, 2
int 15h
;does not go second time
cmp byte [.direction], 1
je .handle_up
cmp byte [.direction], 2
je .handle_right
cmp byte [.direction], 3
je .handle_down
cmp byte [.direction], 4
je .handle_left
.handle_up:
call .clr_player
sub word [.player_x], 4
call .mov_player
jmp .loop
.handle_right:
call .clr_player
add word [.player_y], 4
call .mov_player
jmp .loop
.handle_down:
call .clr_player
add word [.player_x], 4
call .mov_player
jmp .loop
.handle_left:
call .clr_player
sub word [.player_y], 4
call .mov_player
jmp .loop
.mov_player:
pusha
push word [.player_x]
push word [.player_y]
dec word [.player_x]
dec word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
sub word [.player_x], 2
inc word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
sub word [.player_x], 2
inc word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
pop word [.player_y]
pop word [.player_x]
popa
ret
.mov_player_loop:
mov bx, word [.player_x]
mov word [.pixel_x], bx
mov bx, word [.player_y]
mov word [.pixel_y], bx
mov al, 0100b
call .write_pixel
ret
.clr_player:
pusha
push word [.player_x]
push word [.player_y]
dec word [.player_x]
dec word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
sub word [.player_x], 2
inc word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
sub word [.player_x], 2
inc word [.player_y]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
inc word [.player_x]
call .mov_player_loop
pop word [.player_y]
pop word [.player_x]
popa
ret
.clr_player_loop:
mov bx, word [.player_x]
mov word [.pixel_x], bx
mov bx, word [.player_y]
mov word [.pixel_y], bx
mov al, 0100b
call .write_pixel
ret
.key_handler:
pusha
in al, 60h
cmp al, 0x12
je .exit
cmp al, 0x48
je .up
cmp al, 0x4B
je .left
cmp al, 0x4D
je .right
cmp al, 0x50
je .down
jmp .exit_key_handler
.exit:
cli
mov bx, word [.bios_key_handler]
mov [0x24], word bx
mov bx, word [.bios_key_handler + 2]
mov [0x26], bx
sti
call clear_str
mov si, cli_default_text
call print_str
call clear_screen_widetext
mov si, cli_default_text
call print_str
; send EOI:
mov al, 61h
out 20h, al
popa
pop bx
pop bx
jmp hang
.up:
mov byte [.direction], 1
jmp .exit_key_handler
.right:
mov byte [.direction], 2
jmp .exit_key_handler
.down:
mov byte [.direction], 3
jmp .exit_key_handler
.left:
mov byte [.direction], 4
jmp .exit_key_handler
.exit_key_handler:
; send EOI:
mov al, 61h
out 20h, al
popa
iret
.write_pixel:
   pusha
   mov dx, [.pixel_x]
   mov cx, [.pixel_y]
   ; write pixels on screen
   mov ah, 0ch
   ; dx = column
   ; cx = row
   ; al = colour
   int 10h
   popa
   ret
.bios_key_handler dw 0, 0
.direction db 0
.pixel_x dw 0
.pixel_y dw 0
.player_y dw 0
.player_x dw 0
done:
ret
data:
loaded_kernel db 'Loaded Kernel Successfully', 13, 10, 0
input_char db 0, 0
cursor_x db 0
cursor_y db 0
input_msg_indexer db 0, 0
input_msg times 128 db 0
enter_handle_data db 13, 10, 0
cli_default_text db '>>>', 0
end_GFT dw end_GFT_at_boot
available_file_space dw 2073
valid_cmds:
txt_cmd db 'txt', 0
nfile_cmd db 'nfile', 0
random_cmd db 'random', 0
calc_cmd db 'calc', 0
snake_cmd db 'snake', 0
clr_cmd db 'hscroll', 0
free_valid_cmd_slots:
times 16 db 0
GFT:
;null terminating string, start, end, number of ext files associated
db 'file', 0
dw 0, 2072, 0
end_GFT_at_boot db 0
%assign len ($-$$)
%warning Kernel is len bytes long