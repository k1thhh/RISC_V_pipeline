# bubble_sort.s — sort 8 integers stored at address 0x200
# Stores sorted result in-place. Exercises LW/SW, BGE/BLT, nested loops, load-use stalls.
# x10 = base  x11 = outer i  x12 = inner j  x13 = n  x14 = a[j]  x15 = a[j+1]  x1 = tmp

    addi x10, x0, 512         # base = 0x200
    addi x13, x0, 8           # n = 8

    # initialise array: 8 3 7 1 5 9 2 6
    addi x1, x0,8
    sw x1,  0(x10)
    addi x1, x0,3
    sw x1,  4(x10)
    addi x1, x0, 7
    sw x1,  8(x10)
    addi x1,x0, 1
    sw x1, 12(x10)
    addi x1, x0, 5
    sw x1, 16(x10)
    addi x1,x0, 9
    sw x1, 20(x10)
    addi x1, x0, 2
    sw x1, 24(x10)
    addi x1, x0, 6
    sw x1, 28(x10)

    addi x11, x0, 0           # outer = 0
outer:
    addi x16, x13, -1
    bge x11, x16, done       # if outer >= n-1 stop
    addi x12, x0, 0           # j = 0
inner:
    sub x16, x16, x11        # limit = n-1-outer
    bge x12, x16, next_outer
    slli x17, x12,2          # byte offset = j*4
    add x17, x17, x10        # ptr = base + offset
    lw x14, 0(x17)          # a[j]
    lw x15, 4(x17)          # a[j+1]
    blt x14, x15, no_swap
    sw x15, 0(x17)
    sw x14, 4(x17)
no_swap:
    addi x12, x12, 1
    addi x16,x13, -1         # recompute limit (n-1)
    jal  x0, inner
next_outer:
    addi x11, x11, 1
    jal  x0, outer
done:
    nop
    nop
    nop
    halt
