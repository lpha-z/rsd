    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function
main:
    li      a0, 0x80018000
    li      t3, 0x8001A000
    j       stloop
    
stloop:
    sw      a0, 0(a0)
    addi    a0, a0, 4
    bltu    a0, t3, stloop

    # Cache flush
    fence.i

    # Cherry picking
    li      a0, 0x80018000
    lw      a1, 0(a0)
    li      a0, 0x80019000
    lw      a2, 0(a0)
    li      a0, 0x80018008
    lw      a3, 0(a0)
    li      a0, 0x80018010
    lw      a4, 0(a0)

end:
    ret
    #j       end               # ここでループして終了
