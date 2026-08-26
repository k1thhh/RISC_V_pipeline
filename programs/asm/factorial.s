# factorial.s — compute 7! = 5040 iteratively
# Result in x11. Tests JAL/JALR link register convention using a call/ret pattern.
# x10 = n  x11 = result  x12 = scratch  x1 = return address

    addi x10, x0, 7           # n = 7
    jal  x1, fact             # call fact(7), return addr in x1
    jal  x0, done             # jump to halt after return

# ---- factorial subroutine ----
# Input: x10 = n   Output: x11 = n!
fact:
    addi x11, x0, 1           # result = 1
    addi x12, x0, 1           # i = 1
fact_loop:
    blt  x10, x12, fact_ret   # if i > n (i.e. n < i), return
    # multiply: result = result * i  (repeated addition)
    # x11 = x11 * x12  using x13=acc, x14=counter
    addi x13, x0, 0           # acc = 0
    addi x14, x0, 0           # cnt = 0
mul_loop:
    bge  x14, x12, mul_done   # if cnt >= i, done
    add  x13, x13, x11        # acc += result
    addi x14, x14, 1
    jal  x0, mul_loop
mul_done:
    addi x11, x13, 0          # result = acc
    addi x12, x12, 1          # i++
    jal  x0, fact_loop
fact_ret:
    jalr x0, 0(x1)            # return

done:
    addi x15, x0, 16    # address 0x10 = word 4 in data mem
    sw   x11, 0(x15)    # store 7! so testbench can read it
    nop
    nop
    nop
    halt
