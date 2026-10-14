// SPDX-License-Identifier: GPL-3.0-or-later
// Hold a JTFRAME response for the selected address. Physical memory uses
// level req / one-cycle ack, with a mandatory low cycle between requests.
`default_nettype none
module rom_bridge #(parameter AW=20, DW=32)(
    input wire clk, rst,
    input wire cs,
    input wire [AW-1:0] addr,
    output wire ok,
    output reg [DW-1:0] data,
    output reg req = 0,
    output reg [AW-1:0] mem_addr = 0,
    input wire ack,
    input wire [DW-1:0] mem_data
);
    reg valid = 0;
    reg [1:0] state = 0;
    // Never assert ok for stale data when cs/address changes.
    assign ok = cs && valid && addr == mem_addr;
    always @(posedge clk) begin
        case (state)
            0: begin
                req <= 0;
                if (!rst && cs && (!valid || addr != mem_addr)) begin
                    valid <= 0;
                    mem_addr <= addr;
                    req <= 1;
                    state <= 1;
                end
            end
            1: if (ack) begin
                data <= mem_data;
                valid <= !rst && cs && addr == mem_addr;
                req <= 0;
                state <= 2;
            end
            2: state <= 0;
            default: state <= 0;
        endcase
        if (!cs) valid <= 0;
        // Drain an in-flight physical request across a menu reset. Dropping
        // it here could associate a late old ack with a reset-vector read.
        if (rst) valid <= 0;
    end
endmodule
