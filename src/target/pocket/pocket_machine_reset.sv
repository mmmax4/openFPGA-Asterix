// Local Pocket integration: assert reset immediately when a readiness
// interlock falls, then release only after two ready system-clock edges.
// Keep the loader/cache readiness decode off the machine's reset fanout.
`default_nettype none
module pocket_machine_reset (
    input  wire clk,
    input  wire request,
    output wire reset_out
);
    reg [1:0] hold_reset = 2'b11;
    always @(posedge clk or posedge request) begin
        if (request)
            hold_reset <= 2'b11;
        else
            hold_reset <= {hold_reset[0], 1'b0};
    end
    assign reset_out = hold_reset[1];
endmodule
`default_nettype wire
