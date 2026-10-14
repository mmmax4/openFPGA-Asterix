// SPDX-License-Identifier: GPL-3.0-or-later
// Four independent K053260 ROM clients share the physical sample ROM bus.
`default_nettype none
module pcm_arbiter(
    input wire clk, rst,
    input wire [3:0] req,
    input wire [20:0] addr [4],
    output reg [3:0] ack,
    output wire mem_req,
    output reg [21:0] mem_addr,
    input wire mem_ack
);
    reg [1:0] owner = 0, next_owner = 0, state = 0;
    reg [3:0] served = 0;
    reg found;
    reg [1:0] chosen;
    integer i;
    always @* begin
        found = 0;
        chosen = next_owner;
        for (i=0; i<4; i=i+1) begin
            if (!found && req[2'(next_owner+i)] && !served[2'(next_owner+i)]) begin
                found = 1;
                chosen = 2'(next_owner+i);
            end
        end
    end
    assign mem_req = state == 1;
    always @(posedge clk) begin
        ack <= 0;
        served <= served & req;
        case (state)
            0: if (!rst && found) begin
                owner <= chosen;
                mem_addr <= {1'b0,addr[chosen]};
                state <= 1;
            end
            1: if (mem_ack) begin
                ack[owner] <= 1;
                served[owner] <= 1;
                next_owner <= owner+2'd1;
                state <= 2;
            end
            2: state <= 0;
            default: state <= 0;
        endcase
        // Preserve ownership until the physical response, even on soft reset.
        if (rst && state == 0) begin next_owner<=0; served<=0; end
    end
endmodule
