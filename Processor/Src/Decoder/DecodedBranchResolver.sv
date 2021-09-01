// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.


//
// Resolve branch misprediction on the decode stage.
// This unit includes a simple return address stack.
//

import MicroArchConf::*;
import BasicTypes::*;
import MemoryMapTypes::*;
import OpFormatTypes::*;
import MicroOpTypes::*;
import PipelineTypes::*;
import DebugTypes::*;
import FetchUnitTypes::*;

module DecodedBranchResolver(
input
    logic clk, rst, stall, decodeComplete,
    logic insnValidIn[DECODE_WIDTH],
    RISCV_ISF_Common [DECODE_WIDTH-1 : 0] isf,      // Unpacked array of structure corrupts in Modelsim.
    BranchPred [DECODE_WIDTH-1 : 0] brPredIn,
    PC_Path pc[DECODE_WIDTH],
    InsnInfo [DECODE_WIDTH-1 : 0] insnInfo,
output 
    logic insnValidOut[DECODE_WIDTH],
    logic insnFlushed[DECODE_WIDTH],
    logic insnFlushTriggering[DECODE_WIDTH],
    logic flushTriggered,
    BranchPred brPredOut[DECODE_WIDTH],
    PC_Path recoveredPC,
    BranchGlobalHistoryPath recoveredBrHistory,
    RAS_CheckpointData recoveredRasCheckpoint
);

    PC_Path decodedPC[DECODE_WIDTH];
    PC_Path nextPC[DECODE_WIDTH];
    RISCV_ISF_U isfU[DECODE_WIDTH];

    logic addrCheck;
    logic addrIncorrect;
    DecodeLaneIndexPath addrCheckLane;
    typedef enum logic [1:0] 
    {
        BTT_NEXT = 0,       // nextPC 
        BTT_PC_RELATIVE = 1,         // BRANCH, JAL
        BTT_INDIRECT_JUMP  = 2,       // JALR

        // This insn is serialized, so the succeeding insns are flushed
        BTT_SERIALIZED  = 3 
    } BranchTargetType;
    BranchTargetType brTargetType[DECODE_WIDTH];
    logic addrMismatch[DECODE_WIDTH];

    always_comb begin
        
        // Initialize
        flushTriggered = FALSE;
        recoveredPC = '0;
        recoveredBrHistory = '0;
        recoveredRasCheckpoint.stackTopPtr = '0;
        recoveredRasCheckpoint.queueTailPtr = '0;

        for (int i = 0; i < DECODE_WIDTH; i++) begin
            insnValidOut[i] = insnValidIn[i];
            insnFlushed[i] = FALSE;
            insnFlushTriggering[i] = FALSE;
            brPredOut[i] = brPredIn[i];
            isfU[i] = isf[i];
        end

        addrCheck = FALSE;
        addrIncorrect = FALSE;
        addrCheckLane = '0;
        
        // Determine the type of branch
        for (int i = 0; i < DECODE_WIDTH; i++) begin
            
            if (insnInfo[i].isRelBranch) begin
                // Normal branch.
                brTargetType[i] = BTT_PC_RELATIVE;
            end
            else if (insnInfo[i].writePC) begin
                // Indirect branch
                brTargetType[i] = BTT_INDIRECT_JUMP;
            end
            else if (insnInfo[i].isSerialized) begin
                brTargetType[i] = BTT_SERIALIZED;
            end
            else begin
                brTargetType[i] = BTT_NEXT;
            end
        end

        // Detects possible  patterns where flash occurs
        for (int i = 0; i < DECODE_WIDTH; i++) begin
            if (!insnValidIn[i]) begin
                break;
            end
            
            if (!insnInfo[i].writePC && brPredIn[i].predTaken) begin
                // Recovery if not branch instructions are predicted as branches.
                addrCheckLane = i;
                addrCheck = TRUE;
                addrIncorrect = TRUE;   // ミスが確定
                break;
            end
            else if ( //JAL || ( Branch && predTaken )
                brTargetType[i] == BTT_PC_RELATIVE && 
                (isfU[i].opCode == RISCV_JAL || brPredIn[i].predTaken)   
            ) begin
                addrCheckLane = i;
                addrCheck = TRUE;
                break;
            end
            else if ( // JALR
                brTargetType[i] == BTT_INDIRECT_JUMP
            ) begin
                // Do not resolve branch pred
                addrCheckLane = i;
                break;
            end
            else if (brTargetType[i] == BTT_SERIALIZED) begin
                // The succeeding instructions are flushed.
                addrCheckLane = i;
                addrCheck = TRUE;
                addrIncorrect = TRUE;   // ミスが確定
                break;
            end
        end
        
        // Calculate target PC
        for (int i = 0; i < DECODE_WIDTH; i++) begin
            nextPC[i] = pc[i] + INSN_BYTE_WIDTH;
            if (brTargetType[i] == BTT_PC_RELATIVE) begin
                // Calculate target PC from displacement
                if (isfU[i].opCode == RISCV_JAL) begin
                    decodedPC[i] = pc[i] + ExtendBranchDisplacement( GetJAL_Target(isfU[i]));
                end
                else begin
                    decodedPC[i] = pc[i] + ExtendBranchDisplacement( GetBranchDisplacement(isfU[i]));
                end
            end
            else begin
                // non-branch instruction or indirect branch instruction
                decodedPC[i] = nextPC[i];
            end
        end
        
        for (int i = 0; i < DECODE_WIDTH; i++) begin
            addrMismatch[i] = brPredIn[i].predAddr != decodedPC[i];
        end
        
        for (int i = 0; i < DECODE_WIDTH; i++) begin
            if (((addrMismatch[i] && addrCheck) || addrIncorrect) && addrCheckLane == i) begin
                flushTriggered = TRUE;
                brPredOut[i].predAddr = decodedPC[i];
                brPredOut[i].predTaken = TRUE;
                break;
            end
        end
        recoveredPC = decodedPC[addrCheckLane];
        recoveredBrHistory = brPredIn[addrCheckLane].globalHistory;
        recoveredRasCheckpoint = brPredIn[addrCheckLane].rasCheckpoint;

        if (flushTriggered) begin
            for (int i = 0; i < DECODE_WIDTH; i++) begin
                if (i > addrCheckLane) begin
                    insnValidOut[i] = FALSE;
                    insnFlushed[i] = TRUE;
                end
            end
            insnFlushTriggering[addrCheckLane] = TRUE;
        end
    end // always_comb

endmodule

