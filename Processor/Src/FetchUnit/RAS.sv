// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.


//
// Return address stack
//
// This is a renamed RAS, which performs queue-based recovery.
// We are building a spaghetti stack on top of the queue structure.
// Note that the effective RAS depth is variable and not fixed to RAS_ENTRY_NUM.
//

import BasicTypes::*;
import MemoryMapTypes::*;
import FetchUnitTypes::*;

module RAS(
    NextPCStageIF.RAS port,
    FetchStageIF.RAS fetch,
    ControllerIF.RAS ctrl
);
    PC_Path ras_value[RAS_ENTRY_NUM];
    RAS_IndexPath ras_chain[RAS_ENTRY_NUM];
    RAS_IndexPath stackTopPtr; // ras_value[stackTopPtr] has should-be-poped value
    RAS_IndexPath queueTailPtr; // ras_value[queueTailPtr] is should-be-pushed position

    // Internal
    PC_Path pushValue;
    logic pushRAS;
    logic popRAS;
    logic regFetchStall;

    // Output
    PC_Path rasOut[FETCH_WIDTH];
    RAS_CheckpointData rasCheckpoint[FETCH_WIDTH];

    always_ff @(posedge port.clk) begin
        if (port.rst) begin
            for (int i = 0; i < RAS_ENTRY_NUM; i++) begin
                ras_value[i] <= '0;
                ras_chain[i] <= '0;
            end
            stackTopPtr <= '0;
            queueTailPtr <= '0;
            regFetchStall <= FALSE;
        end
        else begin
            if (port.recoverBrHistory) begin
                stackTopPtr <= port.recoveredRasCheckpoint.stackTopPtr;
                queueTailPtr <= port.recoveredRasCheckpoint.queueTailPtr;
            end
            else if (pushRAS) begin
                ras_value[queueTailPtr] <= pushValue;
                ras_chain[queueTailPtr] <= stackTopPtr;
                stackTopPtr <= queueTailPtr;
                queueTailPtr <= queueTailPtr + 1;
            end
            else if (popRAS) begin
                stackTopPtr <= ras_chain[stackTopPtr];
            end
            regFetchStall <= ctrl.ifStage.stall;
        end
    end

    always_comb begin
        pushRAS = FALSE;
        popRAS = FALSE;
        pushValue = '0;

        for (int i = 0; i < FETCH_WIDTH; i++) begin
            rasOut[i] = '0;
            rasCheckpoint[i].stackTopPtr = stackTopPtr;
            rasCheckpoint[i].queueTailPtr = queueTailPtr;
        end

        for (int i = 0; i < FETCH_WIDTH; i++) begin
            if (!fetch.fetchStageIsValid[i]) begin
                break;
            end
            // check '!stall' is needed because BTB never stalls even when FetchStage stalls.
            else if (!regFetchStall && fetch.btbHit[i] && fetch.readIsRASPushBr[i]) begin
                pushRAS = TRUE;
                pushValue = fetch.fetchStagePC[i] + INSN_BYTE_WIDTH;
                rasCheckpoint[i].stackTopPtr = queueTailPtr;
                rasCheckpoint[i].queueTailPtr = queueTailPtr + 1;
                break;
            end
            else if (!regFetchStall && fetch.btbHit[i] && fetch.readIsRASPopBr[i]) begin
                popRAS = TRUE;
                rasOut[i] = ras_value[stackTopPtr];
                rasCheckpoint[i].stackTopPtr = ras_chain[stackTopPtr];
                break;
            end
            else if (fetch.brPredTaken[i]) begin
                break;
            end
        end

        fetch.rasOut = rasOut;
        fetch.rasCheckpoint = rasCheckpoint;
    end
endmodule : RAS
