.section .data
.align 8
	game_over_msg: .ascii "\n\n==GAME OVER==\n\n"
	.equ go_msg_l, .-game_over_msg
	clear_seq: .ascii "\033[2J\033[H"
	.equ clear_seq_l, .-clear_seq
	apple_pos: .space 2
	move_dir: .space 2
	termios_buf: .space 64
	char_buf: .space 8
	screen_width: .byte 32
	screen_height: .byte 16
	snake_len: .byte 3
	snake_pos: .space 1024
.section .text
.global _start

_start:
	jal SET_INITIAL_FLAGS

	lb s1, screen_width
	lb s2, screen_height
	mul s3, s1, s2

	la t0, move_dir
	sb zero, 0(t0)
	sb zero, 1(t0)

	jal SET_RAND_APPLE_POS

	jal INIT_SNAKE_ARR

GAME_LOOP:
	li a0, 0
	li a1, 150000000	# 150 ms
	jal WAIT_FOR_TIME

	li a7, 63			# read syscall
	li a0, 0			# fd = stdin
	la a1, char_buf		# save to char_buf
	li a2, 1			# read 1 byte
	ecall
	
	beqz a0, GAME_LOOP

	la a0, char_buf
	lb a1, 0(a0)
	li a2, 'q'
	beq a1, a2, RESTORE_FLAGS_AND_EXIT

	# up input
	li a2, 'w'
	bne a1, a2, DOWN

	la t0, move_dir
	
	li t1, 0
	sb t1, 0(t0)

	li t1, 1
	sb t1, 1(t0)

	j AFTER_INPUT

DOWN:
	li a2, 's'
	bne a1, a2, LEFT
	
	la t0, move_dir
	
	li t1, 0
	sb t1, 0(t0)

	li t1, -1
	sb t1, 1(t0)

	j AFTER_INPUT

LEFT:
	li a2, 'a'
	bne a1, a2, RIGHT

	la t0, move_dir
	
	li t1, 1
	sb t1, 0(t0)

	li t1, 0
	sb t1, 1(t0)

	j AFTER_INPUT

RIGHT:
	li a2, 'd'
	bne a1, a2, GAME_LOOP_END

	la t0, move_dir
	
	li t1, -1
	sb t1, 0(t0)

	li t1, 0
	sb t1, 1(t0)

	j AFTER_INPUT

AFTER_INPUT:
	li a7, 29		# ioctl syscall
	li a0, 0		# fd = stdin
	li a1, 0x540B	# TCFLSH
	li a2, 0		# Select TCIFLUSH (flush unread input)
	ecall

	li a0, 0
	la a1, char_buf
	sb a0, 0(a1)

GAME_LOOP_END:
	la t0, snake_pos
	lb a0, snake_len
1:
	addi a0, a0, -1
	beq zero, a0, 2f

	lh t1, 2(t0)
	sh t1, 0(t0)

	addi t0, t0, 2

	j 1b

2:
	la t2, move_dir

	lb t1, 0(t0)
	lb t3, 0(t2)
	add t1, t1, t3
	sb t1, 0(t0)

	lb t4, screen_width
	blt t1, zero, GAME_OVER
	bge t1, t4, GAME_OVER

	lb t1, 1(t0)
	lb t3, 1(t2)
	add t1, t1, t3
	sb t1, 1(t0)

	lb t4, screen_height
	blt t1, zero, GAME_OVER
	bge t1, t4, GAME_OVER

	lh t3, 0(t2)
	beq t3, zero, 2f

	lh t3, 0(t0)

	la t0, snake_pos
	lb a0, snake_len
1:
	addi a0, a0, -1
	beq a0, zero, 2f

	lh t1, 0(t0)
	beq t1, t3, GAME_OVER

	addi t0, t0, 2

	j 1b

2:
	lh t4, apple_pos
	bne t3, t4, 3f
	jal INCREASE_LENGTH
	jal SET_RAND_APPLE_POS

3:
	jal DISPLAY
	j GAME_LOOP

DISPLAY:
	# clear screen at beginning of frame
	li a7, 64
	li a0, 1
	la a1, clear_seq
	li a2, clear_seq_l
	ecall

	li t2, 0
	mv s10, ra
	mv t5, sp
	jal TOP_BOTTOM_BAR
L:
	rem t3, t2, s1		# t3 = x_pos
	bnez t3, P			# If i % width != 0 branch

	addi sp, sp, -2		# else push # & '\n' to the output stack
	li t1, '#'
	sb t1, 0(sp)
	li t1, '\n'
	sb t1, 1(sp)

P:
	div t4, t2, s1		# t4 = y_pos

	addi sp, sp, -1

	la t0, apple_pos
	lb a0, 0(t0)
	bne a0, t3, 1f
	lb a0, 1(t0)
	bne a0, t4, 1f

	li t1, '@'

	j C

1:
	la t0, snake_pos
	lb a0, snake_len
	mv a2, zero

2:
	lb a1, 0(t0)
	bne a1, t3, 3f

	lb a1, 1(t0)
	bne a1, t4, 3f

	li a2, 1

3:
	addi t0, t0, 2

	addi a0, a0, -1
	beq zero, a0, 4f

	j 2b

4:
	li t0, 1
	bne a2, t0, E
	li t1, 'O'

	j C

E:
	li t1, '.'

C:
	sb t1, 0(sp)

	mv t0, s1
	addi t0, t0, -1
	bne t3, t0, D		# if i % width != width - 1 branch

	addi sp, sp, -1		# else push # to the output stack
	li t1, '#'
	sb t1, 0(sp)

D:
	addi t2, t2, 1
	bne t2, s3, L

	jal TOP_BOTTOM_BAR

	li a7, 64
	li a0, 1
	mv a1, sp

	add t2, t2, s1		# Add to account for top #
	add t2, t2, s1		# Add to account for bottom #

	add t2, t2, s2		# Add to account for left #
	add t2, t2, s2		# Add to account for right #
	add t2, t2, s2		# Add to account for '\n'
	
	add t2, t2, 6		# Add to account for the corner 4 # & 2 '\n'

	mv a2, t2
	ecall

	add sp, sp, t2		# Deallocate the whole write buffer

	mv ra, s10
	ret

TOP_BOTTOM_BAR:
	addi sp, sp, -1
	li t1, '\n'
	sb t1, 0(sp)

	mv a1, s1
	addi a1, a1, 2
	li a2, 0
1:
	addi sp, sp, -1
	li t1, '#'
	sb t1, 0(sp)

	addi a2, a2, 1

	bne a2, a1, 1b

	ret

SET_INITIAL_FLAGS:
	li a7, 29			# ioctl syscall
	li a0, 0			# fd = stdin
	li a1, 0x5401		# Get termios struct
	la a2, termios_buf	# save buffer
	ecall

	la t0, termios_buf
	addi t0, t0, 12			# c_lflag byte offset in termios
	lw s6, 0(t0)			# s6 is the saved c_flag data [DO NOT OVERWRITE THIS OR BAD THINGS HAPPEN]

	li t2, 0x0008 | 0x0002	# ECHO || ICANON
	not t2, t2				# NOT ECHO || ICANON
	and t2, t2, s6			# Apply the bitmask to turn off echo and set terminal to non-canonical mode
	sw t2, 0(t0)

	li a7, 29
	li a0, 0
	li a1, 0x5402			# Set termios struct
	la a2, termios_buf
	ecall

	li a7, 25	# fcntl syscall
	li a0, 0	# fd = stdin
	li a1, 3	# F_GETFL
	li a2, 0	# set all flags false
	ecall

	mv s0, a0	# save initial settings

	li a7, 25
	li a0, 0
	li a1, 4		# F_SETFL
	li a2, 0x800	# Set O_NONBLOCK
	or a2, a2, s0	# Merge with initial settings
	ecall

	ret

RESTORE_FLAGS_AND_EXIT:
	la a0, termios_buf
	addi a0, a0, 12		# c_lflag byte offset
	sw s6, 0(a0)		# restore saved c_flag data

	li a7, 29			# ioctl syscall #
	li a0, 0			# fd = stdin
	li a1, 0x5402		# set termios struct
	la a2, termios_buf
	ecall

	li a7, 25			# fcntl syscall
	li a0, 0			# fd = stdin
	li a1, 4			# F_SETFL
	mv a2, s0			# restore initial settings
	ecall

	li a7, 93			# exit syscall
	mv a0, s7
	ecall

# a0 = seconds; a1 = nano seconds
WAIT_FOR_TIME:
	addi sp, sp, -16

	sd a0, 0(sp)		# store seconds
	sd a1, 8(sp)		# store nano seconds

	li a7, 101		# nanosleep call #
	mv a1, zero		# rem = null
	mv a0, sp		# timespec struct * (set above using a0 & a1)
	ecall

	addi sp, sp, 16

	ret

INIT_SNAKE_ARR:
	li a1, 256
	la t0, snake_pos
	li a0, 0
1:
	sb zero, 0(t0)
	addi t0, t0, 1
	addi a0, a0, 1
	bne a0, a1, 1b

	ret

INCREASE_LENGTH:
	lb t1, snake_len

	la t0, snake_pos
	add t0, t0, t1
	add t0, t0, t1
	addi t0, t0, -2

	lh t1, 0(t0)
	sh t1, 2(t0)

	la t0, snake_len

	lb t1, 0(t0)
	addi t1, t1, 1
	sb t1, 0(t0)
	
	ret

SET_RAND_APPLE_POS:
	li a7, 278			# getrandom call #
	la a0, apple_pos	# save to apple_pos buffer
	li a1, 1			# buffer length
	li a2, 0			# set no flags
	ecall

	la a0, apple_pos
	
	lb t0, 0(a0)
	lb t1, screen_width
	remu t0, t0, t1

	sb t0, 0(a0)

	li a7, 278
	addi a0, a0, 1
	li a1, 1
	li a2, 0
	ecall


	la a0, apple_pos
	addi a0, a0, 1
	
	lb t0, 0(a0)
	lb t1, screen_height
	remu t0, t0, t1
	
	sb t0, 0(a0)

	ret

GAME_OVER:
	addi sp, sp, -7

	li t0, 'S'
	sb t0, 0(sp)
	li t0, 'C'
	sb t0, 1(sp)
	li t0, 'O'
	sb t0, 2(sp)
	li t0, 'R'
	sb t0, 3(sp)
	li t0, 'E'
	sb t0, 4(sp)
	li t0, ':'
	sb t0, 5(sp)
	li t0, ' '
	sb t0, 6(sp)

	li a7, 64
	li a0, 1
	mv a1, sp
	li a2, 7
	ecall

	lb a0, snake_len
	addi sp, sp, -20
	jal itoa			# external call to itoa.o that converts int to ascii

	mv a2, a1
	mv a1, a0

	li a7, 64
	li a0, 1
	ecall

	addi sp, sp, 27

	li a7, 64
	li a0, 1
	la a1, game_over_msg
	li a2, go_msg_l
	ecall

	j RESTORE_FLAGS_AND_EXIT
