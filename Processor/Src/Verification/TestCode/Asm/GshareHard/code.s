    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function
main:
    j       main2
main2:
    li t5, 0x143f3bdb           # 分岐パターン

    addi t0, zero, 0x0          # 誘導変数の初期化
    addi t1, zero, 0x20         # ループ回数
loop1head:
    mv t2, t5                   # 分岐パターンの初期化
loop1:
    srli t2, t2, 0x1
    andi t3, t2, 0x1
    bne t3, zero, loop1         # (A)t2に設定したパターンで分岐成立・不成立が変わる
    bne t2, zero, loop1         # (B)ループ脱出まで成立
loop1end:
    addi t0, t0, 0x1
    bne t0, t1, loop1head       # (C)ループ脱出まで成立

main3:
    ret
    #j       main3              # ここでループして終了

######
# 分岐パターンが 0x143f3bdb の場合、各分岐命令の成立・不成立は以下のようになる
# A に対する分岐履歴は29回とも異なる
#
# ...
# 28周目 TNTNTNTTNT で A が taken
# 29周目  NTNTNTTNTT で A が not-taken、B が not-taken、C が taken
#  1周目     TNTTNTTNNT で A が taken
#  2周目      NTTNTTNNTT で A が not-taken、B が taken
#  3周目        TNTTNNTTNT で A が taken
#  4周目         NTTNNTTNTT で A が taken
#  5周目          TTNNTTNTTT で A が not-taken、B が taken
#  6周目            NNTTNTTTNT で A が taken
# ...
#
