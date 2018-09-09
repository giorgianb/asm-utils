SECTION .bss

directory_buffer_length equ 1024
directory_buffer resb directory_buffer_length

SECTION .data
struc	linux_dirent64
	d_ino:		resw 4
	d_off:		resw 4
	d_reclen:	resw 1	
	d_type:		resb 1
	d_name:		resb 1
endstruc
default_directory db ".", 0

SECTION .text

global _start

; TODO
; Clean up code
; Error check system calls
; Accept some posix options
_start:
	; Pop argument count into rbx
	pop rbx

	add rsp, 8	; Skip program name
	dec rbx		; Decrement argument count
	jnz .process_loop
	push default_directory
	inc rbx
	.process_loop:
		mov rdi, [rsp]	; Copy argument into rdi
		mov rsi, 65536	; Specify O_DIRECTORY
		mov rdx, 511	; Specify permissions (not necessary for O_DIRECTORY)
		call open
		mov r12, rax

		mov rdi, rax
		mov rsi, directory_buffer
		mov rdx, directory_buffer_length
		call getdents64

		mov r12, rax			; Save number of bytes read in r12
		mov rbp, directory_buffer	; rbp points to the current struct linux_dirent64
		.print_directory_buffer:

			lea rdi, [rbp + d_name]
			call c_string_length
			mov byte [rbp + d_name + rax], 10
			inc rax				; Increase length

			mov rdi, 1
			lea rsi, [rbp + d_name]
			mov rdx, rax
			call write

			sub r12w, [rbp + d_reclen]
			add bp, [rbp + d_reclen]
			cmp r12, 0
			jne .print_directory_buffer

		add rsp, 8
		dec rbx
		jnz .process_loop
	.exit:
		mov rax, 60	;; Specify sys_exit
		mov rdi, 0
		syscall


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

; Read directory entry structures into buffer
; PARAMETERS:
;	rdi: integer, file descriptor of directory to read entries of
;	rsi: buffer to read entries into
;	rdx: integer, buffer size
; RETURN VALUE
;	rax: the number of bytes read
getdents64:
	mov rax, 217
	syscall
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

