    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function
main:
    addi t0, zero, 0x0          # 誘導変数の初期化
    addi t1, zero, 0x50         # ループ回数
loop1:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    jal ra, func1
    addi t0, t0, 0x1
    bne t1, t0, loop1
end:
    j end

func1:
    mv s1, ra
    andi t2, t1, 0x1
    beq t2, zero, func1taken
func1untaken:
    jal ra, func4
    mv ra, s1
    ret
func1taken:
    jal ra, func2
    j func1untaken

func2:
    mv s2, ra
    jal ra, func3
    mv ra, s2
    ret

func4:
    ret

func3:
    mv s3, ra
    jal ra, func4
    jal ra, func4
    mv ra, s3
    ret
