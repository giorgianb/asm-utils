SECTION .bss
buffer_length equ 1024
buffer resb buffer_length

SECTION .data
buffer_to_small_message db "Error printing number: buffer to small to convert number to string.", 10
buffer_to_small_message_length equ $-buffer_to_small_message

standard_input_file db 0

SECTION .text

; TODO
; Error checking on system calls
; Minimize amount of mov's
; Better register use (instead of comparing things one byte at a time, fetch 8 bytes with rax)
; Handle all posix options
; Handle POSIX enviroment variables
; Check for buffer overflows
; Try to minimize the amount of jmp's, etc
; Better commenting
global _start
%macro	flush_buffer 0
	mov rdi, 1
	mov rsi, buffer
	mov rdx, buffer_length
	sub rdx, r13
	call write

	; Reset buffer registers
	mov r12, buffer
	mov r13, buffer_length
%endmacro

%macro append_space 0
	mov byte [r12], ' '
	inc r12
	dec r13

	cmp r13, 0
	jne %%skip_flush_buffer
	flush_buffer
	%%skip_flush_buffer:
%endmacro

%macro append_space 1
	mov byte [r12], ' '
	inc r12
	dec r13

	cmp r13, 0
	jne %1
	flush_buffer
%endmacro

_start:
	pop rbx		; Pop argument count into rbx

	cmp rbx, 1
	jne .file_arguments_provided
	mov qword [rsp], standard_input_file
	mov rax, 0
	jmp .read_and_process

	.file_arguments_provided:
		add rsp, 8			; Skip program name
		dec rbx
	.process_loop:
		mov rdi, [rsp]  ; Load file name into rdi
		mov rsi, 0	; Specify read-only mode
		mov rdx, 0	; Specify file permissions (not necessary for read mode)

		call open
	.read_and_process:
		sub rsp, 8		; Make space to place byte count into
		mov rdi, rsp		; Pass space to place byte count into as first parameter
		mov rsi, rax		; File descriptor of file as second argument

		call wc
				; wc's return value still on stack
		push rdx	; Save word count on stack

		; r12 and r13 will keep track of where we can
		; write in the buffer and how much of the buffer we can
		; still use
		mov r12, buffer		
		mov r13, buffer_length

		mov rdi, rax		; 1st argument, rdi: number to convert
		mov rsi, r12		; 2nd argument: buffer to write converted number to
		mov rdx, r13		; 3rd argument, buffer length

		call integer_to_string

		cmp rax, 0		; If we couldn't convert the number, the buffer is to small: give up
		je .buffer_too_small

		; Update registers to reflect new count, and to point to empty space
		add r12, rax
		sub r13, rax

		cmp r13, 0
		jne .append_line_count_space
		; Buffer full, flush it
		flush_buffer
		.append_line_count_space:
			append_space

		.append_word_count:
			mov rdi, [rsp]
			mov rsi, r12
			mov rdx, r13

			call integer_to_string

			cmp rax, 0
			jne .append_word_count_end
			cmp r13, buffer_length
			je .buffer_too_small
			flush_buffer
			jmp .append_word_count
		.append_word_count_end:
			add rsp, 8	; Remove word count from stack
			add r12, rax
			sub r13, rax
			cmp r13, 0
			jne .append_word_count_space
			flush_buffer
		.append_word_count_space:
			append_space

		.append_byte_count:
			mov rdi, [rsp]
			mov rsi, r12
			mov rdx, r13

			call integer_to_string

			cmp rax, 0
			jne .append_byte_count_end
			cmp r13, buffer_length
			je .buffer_too_small
			flush_buffer
			jmp .append_byte_count
		.append_byte_count_end:
			add rsp, 8	; Remove byte count from stack
			add r12, rax
			sub r13, rax
			cmp r13, 0
			jne .append_byte_count_space
			flush_buffer
		.append_byte_count_space:
			append_space .buffer_not_full
			jmp .print_file_name

		.buffer_not_full:
			flush_buffer

		.print_file_name:
			mov rdi, [rsp]
			call c_string_length

			pop rsi			; Move file name into rsi
			mov byte [rsi+rax], 10	; Append new line to end
			inc rax			; Increment length

			mov rdi, 1	; Set up registers for write
			mov rdx, rax
			call write
		
		dec rbx			; Decrement argument count
		jnz .process_loop
	jmp .exit


	.exit:
		mov rax, 60	;; Specify sys_exit
		mov rdi, 0
		syscall
	
	.buffer_too_small:
		mov rdi, 2
		mov rsi, buffer_to_small_message
		mov rdx, buffer_to_small_message_length
		call write

		mov rax, 60
		mov rdi, -127
		syscall

; Return new line count, word count, and byte count of a file
; PARAMETERS
; 	rdi: Pointer to memory to write byte count to
;	rsi: File descriptor of file to count for
; RETURN VALUE
;	rax: new line count of file
;	rdx: word count of file
;	[rdi]: byte count of file
wc:
	; Save callee-saved registers
	push r12
	push r13
	push r14
	push r15

	push rdi	; Store it for later
	push rsi	; Store file descriptor
	mov r12, 0	; new line count in r12
	mov r13, 0	; word count in r13
	mov r14, 0	; byte count in r14
	mov r15, 0	; whether we are in a word in r15
	.fill_buffer:
		mov rdi, [rsp]		; file descriptor as first parameters 
		mov rsi, buffer		; buffer as second parameter
		mov rdx, buffer_length	; buffer length as third parameters
		call read

		mov rsi, buffer
		mov rcx, rax
		cmp rcx, 0	; if no more bytes left, or if any error occured, jump to end
		jbe .exit	
	.count:
		inc r14			; increment byte count

		mov al, [rsi]
		inc rsi

		; Check if current character is whitespace
		cmp al, 9
		je .found_whitespace
		cmp al, 10
		je .found_newline
		cmp al, 11
		je .found_whitespace
		cmp al, 12
		je .found_whitespace
		cmp al, 13
		je .found_whitespace
		cmp al, ' '
		je .found_whitespace
		jmp .no_whitespace_found

		.found_newline:
			inc r12		; increment new line count
		.found_whitespace:
			add r13, r15	; increment word count if in word (r15 will be 0)
			mov r15, 0
			jmp .found_character
		.no_whitespace_found:
			mov r15, 1

		.found_character:
			dec rcx			; decrement count of characters left to process
			jz .fill_buffer
			jmp .count
	.exit:
		cmp r15, 1
		jne .no_more_words
		inc r13
	.no_more_words:
		add rsp, 8		; Remove file descriptor off the stack
		pop rdi			; Pop location of byte count pointer into rdi
		mov [rdi], r14		; Return byte count

		mov rax, r12		; Return new line count
		mov rdx, r13		; Return word count

		; Restore calle-saved registers
		pop r15			
		pop r14
		pop r13
		pop r12

		ret

; Read bytes from a file into a buffer
; PARAMETERS
;	rdi: file descriptor to read from
; 	rsi: buffer to write bytes into
;	rdx: length of buffer
; RETURN VALUE
;	rax: number of bytes written
read:
	mov rax, 0
	syscall
	ret

; Write to a file from a buffer
; PARAMETERS
;	rdi: file descriptor to write buffer to
; 	rsi: buffer to write to file
;	rdx: length of buffer
; RETURN VALUE
;	rax: number of bytes written
write:
	mov rax, 1
	syscall
	ret

; Open a file
; PARAMETERS
; 	rdi: pointer to null terminated string, specifying file to open
; 	rsi: integer, specifies mode to open file
;	rdx: integer, specifies permissions of open file
; RETURN VALUE
; 	rax: file descriptor
open:
	mov rax, 2
	syscall
	ret

; Convert an unsigned integer into a base 10 string
; PARAMETERS
; 	rdi: integer to convert to string
;	rsi: buffer to write string
;	rdx: length of buffer
; RETURN VALUE
;	rax: the length of the string in the buffer
integer_to_string:
	; Check for 0-length buffer
	cmp rdx, 0
	jne .convert_setup
	mov rax, 0
	ret

	.convert_setup:
		mov rax, rdi	; Number to convert in rax
		mov rdi, rsi	; Buffer to write to in rdi
		mov rcx, rdx	; Length of buffer in rcx

		push rbx	; callee-saved register
		mov rbx, 10
	.convert:
		mov rdx, 0	; 0 for divide
		div rbx

		add rdx, '0'
		mov [rdi], dl
		inc rdi

		dec rcx
		jz .out_of_space

		cmp rax, 0
		jnz .convert
	.reverse_setup:
		mov rcx, rdi
		sub rcx, rsi	; Length is now in rcx

		dec rdi		; Decrement rdi so it points to the last character
	.reverse:
		mov al, [rsi]
		xchg al, [rdi]
		xchg [rsi], al

		inc rsi
		dec rdi
		cmp rsi, rdi
		jb .reverse

	mov rax, rcx
	pop rbx			; Restore rbx
	ret

	.out_of_space:		; Out of space: signal error by return 0
		cmp rax, 0
		je .reverse_setup
		mov rax, 0
		pop rbx
		ret

; Return the length of a c-string
; PARAMETERS
;	rdi: the c string to return the length of
; RETURN VALUE
;	rax: the length of the c-string
c_string_length:
	mov rsi, rdi
	mov rcx, 0

	.iterate:
		mov al, [rsi]
		cmp al, 0
		je .iterate_end
		inc rsi
		inc rcx
		jmp .iterate
	.iterate_end:
		mov rax, rcx
		ret
