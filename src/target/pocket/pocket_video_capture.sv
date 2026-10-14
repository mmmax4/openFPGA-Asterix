// SPDX-License-Identifier: GPL-3.0-or-later
// The two clocks are related core_pll outputs. Register the overlay in the
// system domain before the Pocket pixel-clock capture so its combinational
// path has a full system period. RGB, blanking and sync use the same stages.
`default_nettype none
module pocket_video_capture (
    input  wire        clk_sys, clk_vid,
    input  wire [23:0] rgb,
    input  wire        hs, vs, de,
    output reg  [23:0] rgb_q,
    output reg         hs_q, vs_q, de_q
);
    reg [26:0] system_q;
    always @(posedge clk_sys) system_q <= {rgb, hs, vs, de};
    always @(posedge clk_vid) {rgb_q, hs_q, vs_q, de_q} <= system_q;
endmodule
