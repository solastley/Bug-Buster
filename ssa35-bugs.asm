# This program simulates the Bugs game for CS 0447 Project 1
# Program by Solomon Astley, PeopleSoft #3938540
# Start Date: 03/06/2016

.data
	queue: .space 1024
	start: .word 0
	end: .word 0
	count: .word 0
	current_event: .space 8
	start_time: .word 0
	passed_time: .word 0
	time_stamp: .word 0
	
.text
	# Load the addresses of queue, start, and end into three register
	la $t0, queue
	la $t1, start
	la $t2, end
	
	# Put the address of queue at start and end addresses to initialize start
	# and end variables to be the base address of the queue buffer
	sw $t0, 0($t1)
	sw $t0, 0($t2)
	
	# Wait until the user presses the b key until anything is done
	# at all. This is accomplished by looping over and over, checking if
	# the b key was pressed in each loop.
init_poll:
	# Load the value in the address for key presses
	la $v0, 0xFFFF0000
	lw $t0, 0($v0)
	
	# If value is equal to zero, then loop again
	andi $t0, $t0, 1
	beq $t0, $0, init_poll
	
	# If value is equal to one, load word at address
	lw $t0, 4($v0)
	
	# Check to see if b key is pressed
	addi $v0, $t0, -66
	bne $v0, $0, init_poll
	
end_init_poll:
	
	# b key has been pressed, so initialize the start time variable and
	# begin the game
	la $t0, start_time
	la $t1, passed_time
	li $v0, 30
	syscall
	sw $a0, 0($t0)
	sw $a0, 0($t1)
	
	# Set LED at (32, 63) to orange for the bug buster
	li $a0, 32
	li $a1, 63
	li $a2, 2
	jal _setLED
	# Save bug buster location in register $t9 for convenience
	li $t9, 32
	
	# Load value into $t4 to keep track of init_loop iterations
	li $t4, 4
init_loop:
	# Load arguments for random number generation between 0 and 63 inclusive
	li $a0, 0
	li $a1, 64
	li $v0, 42
	syscall
	
	# $a0 now contains random number. Call the _getLED function and branch
	# to beginning of loop if that LED has already been lit up.
	li $a1, 0
	jal _getLED
	beq $v0, 3, init_loop
	
	# Set LED to green to simulate a bug appearing
	move $s1, $a0
	li $a1, 0
	li $a2, 3
	jal _setLED
	
	# Insert bug_move event into queue
	li $a0, 3
	move $a1, $s1
	li $a2, 0
	li $a3, 0
	addi $sp, $sp, -20
	sw $a2, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	# Add 1 to $t4 and end loop if equal to 4 (value in $t5)
	subi $t4, $t4, 1
	beq $t4, $0, end_init_loop
	j init_loop	
	
end_init_loop:
	
# ------------------------ Beginning of Main Program ------------------------------
	
	# Save current time in time_stamp variable
	la $t0, time_stamp
	li $v0, 30
	syscall
	sw $a0, 0($t0)
	
	# This is the poll loop required for the program.
	# The loop executes continuously, each time checking to
	# see if a key has been pressed by the user. If a key has
	# been pressed, then the appropriate action is taken.
poll:
	# Check if seven seconds has passed, if so, add more bugs
	la $t0, passed_time
	lw $t1, 0($t0)
	li $v0, 30
	syscall
	sub $t2, $a0, $t1
	
	slti $t3, $t2, 4000
	bne $t3, $0, skip_add
	sw $a0, 0($t0)
	jal add_more_bugs
skip_add:
	
	# Load the value in the address for key presses
	la $v0, 0xFFFF0000
	lw $t0, 0($v0)
	
	# If value is equal to zero, then loop again
	andi $t0, $t0, 1
	beq $t0, $0, check_time
	
	# If value is equal to one, load word at address
	lw $t0, 4($v0)
	
	# Check to see if left key is pressed
lkey:	addi $v0, $t0, -226
	bne $v0, $0, rkey
	jal lkey_press
	j check_time
	
	# Check to see if right key is pressed
rkey:	addi $v0, $t0, -227
	bne $v0, $0, ukey
	jal rkey_press
	j check_time
	
	# Check to see if up key is pressed
ukey:	addi $v0, $t0, -224
	bne $v0, $0, dkey
	jal ukey_press
	j check_time
	
	# Check to see if down key is pressed
dkey:	addi $v0, $t0, -225
	bne $v0, $0, check_time
	li $v0, 10
	syscall
	
	# If 100 ms has passed since last time-stamp, then process events queue
check_time:
	# Find difference between last time_stamp and current time and place in $t0
	la $t0, time_stamp
	lw $t1, 0($t0)
	li $v0, 30
	syscall
	sub $t1, $a0, $t1
	
	# If difference is greater than 100 ms, the process events
	slti $t2, $t1, 150
	beq $t2, $0, process_events
	j poll
	
process_events:
	# Load the current count into $t8
	la $t0, count
	lw $t8, 0($t0)
	
	# Loop through process_loop count number of times
process_loop:
	# If number of events left is zero, end the loop
	beq $t8, $0, end_process_loop
	
	jal _remove_q
	
	# Load the type of the event in the current_event buffer
	la $t0, current_event
	lbu $t1 0($t0)
	
	# Decrement the loop count variable
	addi $t8, $t8, -1
	
	# If type is a pulse type, go to pulse branch
	addi $v0, $t1, -1
	beq $v0, $0, pulse
	
	# If type is a bug move type, go to bug_move branch
	addi $v0, $t1, -3
	beq $v0, $0, bug_move
	
	# If type is a wave type, go to wave branch
	addi $v0, $t1, -2
	beq $v0, $0, wave
	
	j process_loop
	
# ------------------------ End of Main Program ------------------------------

# ------------------------ Branches for Events ------------------------------
	
	# This branch is entered when a pulse event is processed
pulse:
	# Load x and y coordinates for pulse
	lbu $s1, 1($t0)
	lbu $s2, 2($t0)
	
	# Decrement the value for the y-coordinate
	addi $s2, $s2, -1
	
	# Check is pulse has reached top of LED panel
	li $s3, 0xFFFFFFFF
	beq $s3, $s2, end_pulse
	
	# Check to see if beginning of pulse
	li $t3, 62
	beq $s2, $t3, begin_pulse
	j continue_pulse
	
begin_pulse:
	# Load arguments for _setLED function for red LED
	move $a0, $s1
	move $a1, $s2
	li $a2, 1
	jal _setLED
	
	# Add new event to queue for pulse
	li $a0, 1
	move $a1, $s1
	move $a2, $s2
	li $a3, 0
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j process_loop
	
continue_pulse:
	# Check if next LED is green
	move $a0, $s1
	move $a1, $s2
	jal _getLED
	li $t0, 3
	beq $v0, $t0, kill_bug
	
	# Load arguments for _setLED function for black LED
	move $a0, $s1
	addi $a1, $s2, 1
	li $a2, 0
	jal _setLED
	
	# Load arguments for _setLED function for red LED
	move $a1, $s2
	li $a2, 1
	jal _setLED
	
	# Add new event to queue for pulse
	li $a0, 1
	move $a1, $s1
	move $a2, $s2
	li $a3, 0
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j process_loop
	
kill_bug:
	# Change LEDs for bug and phaser to black
	li $a2, 0
	jal _setLED
	addi $a1, $s2, 1
	jal _setLED
	
	# Create wave event at current location
	li $a0, 2
	move $a1, $s1
	move $a2, $s2
	move $a3, $0
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j process_loop
	
end_pulse:
	# Load arguments for _setLED function for black LED
	move $a0, $s1
	addi $a1, $s2, 1
	li $a2, 0
	jal _setLED
	
	j process_loop
	
	# This branch is entered when a bug_move event is processed
bug_move:
	# Load count for bugs so they move slower than pulses
	#lbu $s2, 3($t0)
	#slti $t1, $s2, 3
	#beq $t1, $0, do_bug_move
	#li $a0, 3
	#lbu $a1, 1($t0)
	#lbu $a2, 2($t0)
	#move $a3, $s2
	#addi $sp, $sp, -20
	#sw $0, 16($sp)
	#jal _insert_q
	#addi $sp, $sp, 20

do_bug_move:	
	# Load x and y coordinates for bug position
	lbu $s0, 1($t0)
	lbu $s1, 2($t0)
	
	# If bug's position is 62, branch to end_bug_move
	li $t1, 62
	beq $s1, $t1, end_bug_move_b
	
	# Check if next LED is red (a pulse)
	move $a0, $s0
	addi $a1, $s1, 1
	jal _getLED
	li $t5, 1
	beq $v0, $t5, end_bug_move
	
	# Check if LED two spaces ahead is red (a pulse)
	addi $a1, $a1, 1
	jal _getLED
	li $t5, 1
	beq $v0, $t5, end_bug_move_c
	
	# Check if current LED is red (a pulse)
	move $a1, $s1
	jal _getLED
	li $t5, 1
	beq $v0, $t5, end_bug_move
	
	# Set current LED to black and next to green
	li $a2, 0
	jal _setLED
	addi $a1, $s1, 1
	li $a2, 3
	jal _setLED
	
	# Add new bug_move event to queue
	li $a0, 3
	move $a1, $s0
	addi $a2, $s1, 1
	li $a3, 0
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j process_loop
	
end_bug_move:
	# Load arguments to add new wave event to queue
	li $a0, 2
	move $a1, $s0
	move $a2, $s1
	move $a3, $0
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j process_loop
	
end_bug_move_b:
	# Set current LED (at bottom of LED panel) to black
	move $a0, $s0
	move $a1, $s1
	li $a2, 0
	jal _setLED
	
	j process_loop
	
end_bug_move_c:
	# Set current LED to black
	move $a0, $s0
	move $a1, $s1
	li $a2, 0
	jal _setLED
	
	# Set next LED to green
	addi $a1, $a1, 1
	li $a2, 3
	jal _setLED
	
	j process_loop
	
	# This function is called when a wave event is processed
wave: 
	# Load x and y coordinates and radius for wave
	lbu $s0, 1($t0)
	lbu $s1, 2($t0)
	lbu $s2, 3($t0)
	
	# Case where radius is zero, just turn current LED to red
	beq $s2, $0, zero_radius
	
	# Every other case, radius is between 1 and 10, so get coordinates
	# of locations of wave LEDs, check if they are valid, and turn them on
right_wave:
	# add radius to current x-position
	add $t0, $s0, $s2
	slti $t1, $t0, 65
	beq $t1, $0, top_right_wave
	
	# Set LED to black for previous right-wave
	subi $t1, $t0, 1
	move $a0, $t1
	move $a1, $s1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, top_right_wave
	
	# Check if next LED is less than 64
	add $t0, $s0, $s2
	slti $t1, $t0, 64
	beq $t1, $0, top_right_wave
	
	# Set LED to red for right-wave
	move $a0, $t0
	move $a1, $s1
	li $a2, 1
	jal _setLED
	
top_right_wave:
	# add radius to current x-position
	add $t0, $s0, $s2
	slti $t1, $t0, 65
	beq $t1, $0, bottom_right_wave
	
	# subtract radius from current y-position
	sub $t2, $s1, $s2
	slti $t3, $t2, -1
	li $t4, 1
	beq $t3, $t4, bottom_right_wave
	
	# Set LED to black for previous bottom_right-wave
	subi $a0, $t0, 1
	addi $a1, $t2, 1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, bottom_right_wave
	
	# Check if next LED to right is less than 64
	add $t0, $s0, $s2
	slti $t1, $t0, 64
	beq $t1, $0, bottom_right_wave
	
	# Check if next LED up is greater than -1
	sub $t2, $s1, $s2
	slt $t3, $t2, $0
	li $t4, 1
	beq $t3, $t4, bottom_right_wave
	
	# Set LED to red for bottom_right-wave
	move $a0, $t0
	move $a1, $t2
	li $a2, 1
	jal _setLED
	
bottom_right_wave:
	# add radius to current x-position
	add $t0, $s0, $s2
	slti $t1, $t0, 65
	beq $t1, $0, left_wave
	
	# add radius to current y-position
	add $t2, $s1, $s2
	slti $t3, $t0, 65
	beq $t3, $0, left_wave
	
	# Set LED to black for previous bottom_right-wave
	subi $t1, $t0, 1
	subi $t3, $t2, 1
	move $a0, $t1
	move $a1, $t3
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, left_wave
	
	# Check if next LED to right is less than 64
	add $t0, $s0, $s2
	slti $t1, $t0, 64
	beq $t1, $0, left_wave
	
	# Check if next LED down is less than 64
	add $t2, $s1, $s2
	slti $t3, $t2, 64
	beq $t3, $0, left_wave
	
	# Set LED to red for bottom_right-wave
	move $a0, $t0
	move $a1, $t2
	li $a2, 1
	jal _setLED
	
left_wave:
	# subtract radius from current x-position
	sub $t0, $s0, $s2
	slti $t1, $t0, -1
	li $t2, 1
	beq $t1, $t2, top_left_wave
	
	# Set LED to black for previous left-wave
	addi $t1, $t0, 1
	move $a0, $t1
	move $a1, $s1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, top_left_wave
	
	# Check if next LED is greater than -1
	sub $t0, $s0, $s2
	slt $t1, $t0, $0
	li $t2, 1
	beq $t1, $t2, top_left_wave
	
	# Set LED to red for left-wave
	move $a0, $t0
	li $a2, 1
	jal _setLED
	
top_left_wave:
	# subtract radius from current x-position
	sub $t0, $s0, $s2
	slti $t1, $t0, -1
	li $t2, 1
	beq $t1, $t2, bottom_left_wave
	
	# subtract radius from current y-position
	sub $t2, $s1, $s2
	slti $t3, $t2, -1
	li $t4, 1
	beq $t3, $t4, bottom_left_wave
	
	# Set LED to black for previous top-left-wave
	addi $a0, $t0, 1
	addi $a1, $t2, 1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, bottom_left_wave
	
	# Check if next LED to left is greater than -1
	sub $t0, $s0, $s2
	slt $t1, $t0, $0
	li $t2, 1
	beq $t1, $t2, bottom_left_wave
	
	# Check if next LED up is greater than -1
	sub $t2, $s1, $s2
	slt $t3, $t2, $0
	li $t4, 1
	beq $t3, $t4, bottom_left_wave
	
	# Set LED to red for bottom_right-wave
	move $a0, $t0
	move $a1, $t2
	li $a2, 1
	jal _setLED
	
bottom_left_wave:
	# subtract radius from current x-position
	sub $t0, $s0, $s2
	slti $t1, $t0, -1
	li $t2, 1
	beq $t1, $t2, bottom_wave
	
	# add radius to current y-position
	add $t2, $s1, $s2
	slti $t3, $t0, 65
	beq $t3, $0, bottom_wave
	
	# Set LED to black for previous bottom_left-wave
	addi $t1, $t0, 1
	subi $t3, $t2, 1
	move $a0, $t1
	move $a1, $t3
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, bottom_wave
	
	# Check if next LED to left is greater than -1
	sub $t0, $s0, $s2
	slt $t1, $t0, $0
	li $t2, 1
	beq $t1, $t2, bottom_wave
	
	# Check if next LED to left is less than 64
	add $t2, $s1, $s2
	slti $t3, $t2, 64
	beq $t3, $0, bottom_wave
	
	# Set LED to red for bottom_left-wave
	move $a0, $t0
	move $a1, $t2
	li $a2, 1
	jal _setLED
	
bottom_wave:
	# Add radius to current y-position
	add $t0, $s1, $s2
	slti $t1, $t0, 65
	beq $t1, $0, top_wave
	
	# Set LED to black for previous bottom-wave
	subi $t1, $t0, 1
	move $a0, $s0
	move $a1, $t1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, top_wave
	
	# Check if next LED is less than 64
	add $t0, $s1, $s2
	slti $t1, $t0, 64
	beq $t1, $0, top_wave
	
	# Set LED to red for bottom-wave
	move $a0, $s0
	move $a1, $t0
	li $a2, 1
	jal _setLED
	
top_wave:
	# Subtract radius from current y-position and check to make sure it is greater than -2
	sub $t0, $s1, $s2
	slti $t1, $t0, -1
	li $t2, 1
	beq $t1, $t2, next_wave
	
	# Set LED to black for previous top-wave
	addi $t1, $t0, 1
	move $a0, $s0
	move $a1, $t1
	li $a2, 0
	jal _setLED
	
	# End wave event if radius is greater than 10
	slti $t0, $s2, 10
	beq $t0, $0, end_wave
	
	# Check if next LED is greater than -1
	sub $t0, $s1, $s2
	slt $t1, $t0, $0
	li $t2, 1
	beq $t1, $t2, next_wave
	
	# Set LED to red for top-wave
	move $a1, $t0
	li $a2, 1
	jal _setLED
	
	j next_wave
	
zero_radius:
	# Load arguments for _setLED
	move $a0, $s0
	move $a1, $s1
	li $a2, 1
	jal _setLED
	
next_wave:
	# Load arguments to add new wave event to queue
	li $a0, 2
	move $a1, $s0
	move $a2, $s1
	addi $a3, $s2, 1
	addi $sp, $sp, -20
	sw $0, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	j end_wave
	
end_wave:
	j process_loop
	
end_process_loop:
	# Set time_stamp to current time
	la $t0, time_stamp
	li $v0, 30
	syscall
	sw $a0, 0($t0)
	
	j poll

# --------------------- Functions for Key Presses ---------------------------
	
	# This function is called if the left key is pressed
	# It takes no arguments and simply moves the bug buster one LED left
lkey_press:
	# Decrement the stack pointer and save return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# If bug buster x-location is zero, do nothing
	beq $t9, $0, end_lkey
	
	# Load arguments to set current buster LED to black
	move $a0, $t9
	li $a1, 63
	li $a2, 0
	jal _setLED
	
	# Load arguments to set new buster LED to orange
	addi $t9, $t9, -1
	move $a0, $t9
	li $a1, 63
	li $a2, 2
	jal _setLED
	
end_lkey:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	# This function is called if the right key is pressed
	# It takes no arguments and simply moves the bug buster one LED right
rkey_press:
	# Decrement the stack pointer and save return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# If bug buster x-location is 63, do nothing
	li $t0, 63
	beq $t9, $t0, end_rkey
	
	# Load arguments to set current buster LED to black
	move $a0, $t9
	li $a1, 63
	li $a2, 0
	jal _setLED
	
	# Load arguments to set new buster LED to orange
	addi $t9, $t9, 1
	move $a0, $t9
	li $a1, 63
	li $a2, 2
	jal _setLED
	
end_rkey:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	# This function is called when the up key is pressed.
	# It takes no arguments and creates a pulse event at the current
	# location of the bug buster.
ukey_press:
	# The _insert_q function takes five arguments, so decrement the stack
	# pointer and place fifth argument at 16($sp) as per the standard
	addi $sp, $sp, -20
	li $t0, 0
	sw $t0, 16($sp)
	
	# Place $ra at 0($sp) to save it
	sw $ra, 0($sp)
	
	# Load arguments for _insert_q function
	li $a0, 1
	move $a1, $t9
	li $a2, 63
	li $a3, 0
	
	jal _insert_q
	
	# Get return address, increment stack pointer, and return
	lw $ra, 0($sp)
	addi $sp, $sp, 20
	jr $ra
	
# --------------------- Functions for Queue Manipulation ---------------------------
	
	# This function is called when an item is inserted into the queue.
	# It takes five arguments:
	#	$a0 - type of event, $a1 - x-coordinate, $a2 - y-coordinate
	#	$a3 - radius, 16($sp) - start time
	# Some events use 1 or 2 of these arguments, some use more.
	# Types of events: (1) pulse, (2) wave, (3) bug move, (4) end game
_insert_q:
	# Load the start time argument from the stack
	lw $t1, 16($sp)
	
	# Load the address of end of queue
	la $t0, end
	lw $t0, 0($t0)
	
	# Load address of queue and add 1024 to it for end of buffer
	la $t2, queue
	addi $t2, $t2, 1023
	slt $t3, $t2, $t0
	beq $t3, $0, normal_insert
	
	# End needs placed at beginning of buffer
	la $t2, queue
	la $t0, end
	sw $t2, 0($t0)
	
	# Add event parameters to queue at end
	la $t0, end
	lw $t0, 0($t0)
	sb $a0, 0($t0)
	sb $a1, 1($t0)
	sb $a2, 2($t0)
	sb $a3, 3($t0)
	sw $t1, 4($t0)
	j skip_normal
	
	# Add event parameters to queue at the end
normal_insert:
	sb $a0, 0($t0)
	sb $a1, 1($t0)
	sb $a2, 2($t0)
	sb $a3, 3($t0)
	sw $t1, 4($t0)
	
	# Increment the address of the end of the queue by 8 bytes
skip_normal:
	move $t1, $t0
	addi $t1, $t1, 8
	la $t0, end
	sw $t1, 0($t0)
	
	# Increment the count variable by one
	la $t0, count
	lw $t1, 0($t0)
	addi $t1, $t1, 1
	sw $t1, 0($t0)
	
	jr $ra
	
	# This function is called when an item is removed from the queue.
	# It takes no arguments and stores the next event in the queue
	# in the current_event space.
_remove_q:
	# Load the addresses of the start of the queue and current_event space
	la $t0, start
	lw $t0, 0($t0)
	la $t1, current_event
	
	# Load words from queue and store them in the current_event space
	lw $t2, 0($t0)
	sw $t2, 0($t1)
	lw $t2, 4($t0)
	sw $t2, 4($t1)
	
	# Increment the address of the beginning of the queue by 8
	move $t2, $t0
	addi $t2, $t2, 8
	la $t0, start
	sw $t2, 0($t0)
	
	# Check if start is now at end of queue
	la $t1, queue
	addi $t1, $t1, 1024
	slt $t3, $t2, $t1
	bne $t3, $0, normal_remove
	
	# Change address of start to base of queue
	la $t0, queue
	la $t1, start
	sw $t0, 0($t1)
	
	# Decrement the count variable by one
normal_remove:
	la $t0, count
	lw $t1, 0($t0)
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	
	jr $ra
	
	# void _setLED(int x, int y, int color)
	#   sets the LED at (x,y) to color
	#   color: 0=off, 1=red, 2=yellow, 3=green
	#
	# arguments: $a0 is x, $a1 is y, $a2 is color
	# trashes:   $t0-$t3
	# returns:   none
	#
_setLED:
	# byte offset into display = y * 16 bytes + (x / 4)
	sll	$t0,$a1,4      # y * 16 bytes
	srl	$t1,$a0,2      # x / 4
	add	$t0,$t0,$t1    # byte offset into display
	li	$t2,0xffff0008 # base address of LED display
	add	$t0,$t2,$t0    # address of byte with the LED
	# now, compute led position in the byte and the mask for it
	andi	$t1,$a0,0x3    # remainder is led position in byte
	neg	$t1,$t1        # negate position for subtraction
	addi	$t1,$t1,3      # bit positions in reverse order
	sll	$t1,$t1,1      # led is 2 bits
	# compute two masks: one to clear field, one to set new color
	li	$t2,3		
	sllv	$t2,$t2,$t1
	not	$t2,$t2        # bit mask for clearing current color
	sllv	$t1,$a2,$t1    # bit mask for setting color
	# get current LED value, set the new field, store it back to LED
	lbu	$t3,0($t0)     # read current LED value	
	and	$t3,$t3,$t2    # clear the field for the color
	or	$t3,$t3,$t1    # set color field
	sb	$t3,0($t0)     # update display
	jr	$ra
	
	# int _getLED(int x, int y)
	#   returns the value of the LED at position (x,y)
	#
	#  arguments: $a0 holds x, $a1 holds y
	#  trashes:   $t0-$t2
	#  returns:   $v0 holds the value of the LED (0, 1, 2 or 3)
	#
_getLED:
	# byte offset into display = y * 16 bytes + (x / 4)
	sll  $t0,$a1,4      # y * 16 bytes
	srl  $t1,$a0,2      # x / 4
	add  $t0,$t0,$t1    # byte offset into display
	la   $t2,0xffff0008
	add  $t0,$t2,$t0    # address of byte with the LED
	# now, compute bit position in the byte and the mask for it
	andi $t1,$a0,0x3    # remainder is bit position in byte
	neg  $t1,$t1        # negate position for subtraction
	addi $t1,$t1,3      # bit positions in reverse order
    	sll  $t1,$t1,1      # led is 2 bits
	# load LED value, get the desired bit in the loaded byte
	lbu  $t2,0($t0)
	srlv $t2,$t2,$t1    # shift LED value to lsb position
	andi $v0,$t2,0x3    # mask off any remaining upper bits
	jr   $ra

# ---------------------Function to Add Random Bugs----------------------

add_more_bugs:
	# Store $ra on stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Load value into $t4 to keep track of init_loop iterations
	li $t4, 4
rand_bug_loop:
	# Load arguments for random number generation between 0 and 63 inclusive
	li $a0, 0
	li $a1, 64
	li $v0, 42
	syscall
	
	# $a0 now contains random number. Call the _getLED function and branch
	# to beginning of loop if that LED has already been lit up.
	li $a1, 0
	jal _getLED
	beq $v0, 3, rand_bug_loop
	
	# Set LED to green to simulate a bug appearing
	move $s1, $a0
	li $a1, 0
	li $a2, 3
	jal _setLED
	
	# Insert bug_move event into queue
	li $a0, 3
	move $a1, $s1
	li $a2, 0
	li $a3, 0
	addi $sp, $sp, -20
	sw $a2, 16($sp)
	jal _insert_q
	addi $sp, $sp, 20
	
	# Add 1 to $t4 and end loop if equal to 4 (value in $t5)
	subi $t4, $t4, 1
	beq $t4, $0, end_rand_bug_loop
	j rand_bug_loop	
	
end_rand_bug_loop:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
