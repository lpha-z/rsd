// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.


//
// Return address stack
//

import BasicTypes::*;
import MemoryMapTypes::*;
import FetchUnitTypes::*;

module RAS(
    NextPCStageIF.RAS port,
    FetchStageIF.RAS fetch
);
    parameter RAS_ENTRY_NUM = CONF_RAS_ENTRY_NUM;
    typedef logic [$clog2(RAS_ENTRY_NUM)-1 : 0] RAS_IndexPath;
    PC_Path ras[RAS_ENTRY_NUM];
    RAS_IndexPath rasPtr;
    PC_Path pcPipeReg;

    // Internal
    PC_Path pushValue;
    RAS_IndexPath nextRAS_Ptr;
    PC_Path nextPcPipeReg;
    logic pushRAS;
    logic popRAS;

    // Output
    PC_Path rasOut[FETCH_WIDTH];

    always_ff @(posedge port.clk) begin
        if (port.rst) begin
            for (int i = 0; i < RAS_ENTRY_NUM; i++) begin
                ras[i] <= '0;
            end
            rasPtr <= '0;
            pcPipeReg <= '0;
        end
    end

    always_ff @(posedge port.clk) begin
        if (pushRAS) begin
            ras[nextRAS_Ptr] <= pushValue;
        end
        rasPtr <= nextRAS_Ptr;
        pcPipeReg <= nextPcPipeReg;
    end

    always_comb begin
        pushRAS = FALSE;
        popRAS = FALSE;
        pushValue = '0;
        nextPcPipeReg = port.predNextPC;

        for (int i = 0; i < FETCH_WIDTH; i++) begin
            rasOut[i] = '0;
        end

        for (int i = 0; i < FETCH_WIDTH; i++) begin
            if (fetch.readIsRASPushBr[i]) begin
                pushRAS = TRUE;
                pushValue = pcPipeReg + INSN_BYTE_WIDTH;
                break;
            end
            else if (fetch.readIsRASPopBr[i]) begin
                popRAS = TRUE;
                rasOut[i] = ras[rasPtr];
                break;
            end
        end

        if (pushRAS) begin
            nextRAS_Ptr = rasPtr + 1;
        end
        else if (popRAS) begin
            nextRAS_Ptr = rasPtr - 1;
        end
        else begin
            nextRAS_Ptr = rasPtr;
        end

        fetch.rasOut = rasOut;
    end
endmodule : RAS
