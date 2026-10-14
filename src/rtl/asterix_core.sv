// SPDX-License-Identifier: GPL-3.0-or-later
// Pocket adapter for jlrh Asterix: all logic runs on the proven 96 MHz memory clock.
`default_nettype none

module asterix_core (
    input  logic        clk,            // 96 MHz
    input  logic        rst,
    input  logic        bucky,          // stable before reset exit
    input  logic        pause,          // freeze the CPUs and sound, keep the picture
    input  logic        pix_sync,       // see clk_enables.sv

    // ---------------- memory, all through target/pocket/moomesa_mem.sv
    output logic        mrom_req,  output logic [19:1] mrom_addr,   // 68000 ROM, image-relative
    input  logic        mrom_ack,  input  logic [15:0] mrom_q,
    output logic        srom_req,  output logic [17:0] srom_addr,   // Z80 ROM
    input  logic        srom_ack,  input  logic  [7:0] srom_q,
    output logic        pcm_req,   output logic [21:0] pcm_addr,    // K054539 samples
    input  logic        pcm_ack,   input  logic  [7:0] pcm_q,
    output logic        ext_req, ext_we, // Bucky's extra CPU-only RAM in SRAM
    output logic [15:0] ext_addr,
    output logic [15:0] ext_d,
    output logic [1:0]  ext_be,
    input  logic        ext_ack,
    input  logic [15:0] ext_q,
    output logic        tile_req,  output logic [18:0] tile_addr,   // tile ROM, 32-bit rows
    input  logic        tile_ack,  input  logic [31:0] tile_q,
    output logic        spr_req,   output logic [19:0] spr_addr,    // sprite ROM, 64-bit rows
    input  logic        spr_ack,   input  logic [63:0] spr_q,

    // ---------------- the ROM image as it downloads (byte offset in the image)
    input  logic        dl_we,
    input  logic [24:0] dl_addr,
    input  logic  [7:0] dl_data,

    // ---------------- the EEPROM's contents, for the save slot
    input  logic  [6:0] nv_addr,
    input  logic        nv_we,
    input  logic  [7:0] nv_din,
    output logic  [7:0] nv_dout,
    output logic        nv_changed,     // the game wrote the EEPROM (pulse)

    // ---------------- inputs, active low as the board reads them
    input  logic  [7:0] p1, p2, p3, p4, // bit 0 left, 1 right, 2 up, 3 down, 4 b1, 5 b2, 7 start
    input  logic  [7:0] in0,            // bit 0-3 coin 1-4, 4-7 service 1-4
    input  logic        test_n,         // service mode switch
    input  logic  [3:0] dsw,            // SW1:1-4 (IN1 bits 4-7)

    // ---------------- video, one pixel per pix_ce in the clk domain
    output logic [23:0] rgb,
    output logic        hsync, vsync, hblank, vblank,
    output logic        pix_ce, de,

    output logic signed [15:0] snd_l, snd_r,

    // ---------------- bring-up (rtl/dbg_fault.sv, the panel in core_top)
    output logic        dbg_halted,
    output logic [23:1] dbg_addr,
    output logic        dbg_bus, dbg_wait,
    output logic        watchdog_reset,
    output logic  [7:0] dbg_status,     // engine deadlines missed, sound overrun, IRQs seen
    output logic [15:0] dbg_snd_worst,  // K054539: most clocks a sample took (of 2000)
    output logic  [7:0] dbg_snd_reads   //          and most ROM reads
);
    wire [19:1] main_a;
    wire main_cs, main_ok;
    wire [15:0] main_data;
    wire [15:0] snd_a;
    wire snd_cs, snd_ok;
    wire [7:0] snd_data;
    wire [19:2] scr_a;
    wire scr_cs, scr_ok;
    wire [31:0] scr_data;
    wire [21:2] obj_a;
    wire obj_cs, obj_ok;
    wire [31:0] obj_data;

    rom_bridge #(.AW(19),.DW(16)) b_main(
        .clk(clk), .rst(rst), .cs(main_cs), .addr(main_a), .ok(main_ok), .data(main_data),
        .req(mrom_req), .mem_addr(mrom_addr), .ack(mrom_ack), .mem_data(mrom_q));
    wire [15:0] snd_mem_addr;
    assign srom_addr = {2'b0,snd_mem_addr};
    rom_bridge #(.AW(16),.DW(8)) b_snd(
        .clk(clk), .rst(rst), .cs(snd_cs), .addr(snd_a), .ok(snd_ok), .data(snd_data),
        .req(srom_req), .mem_addr(snd_mem_addr), .ack(srom_ack), .mem_data(srom_q));
    wire [17:0] tile_mem_addr;
    assign tile_addr = {1'b0,tile_mem_addr};
    rom_bridge #(.AW(18),.DW(32)) b_scr(
        .clk(clk), .rst(rst), .cs(scr_cs), .addr(scr_a), .ok(scr_ok), .data(scr_data),
        .req(tile_req), .mem_addr(tile_mem_addr), .ack(tile_ack), .mem_data(tile_q));
    rom_bridge #(.AW(20),.DW(32)) b_obj(
        .clk(clk), .rst(rst), .cs(obj_cs), .addr(obj_a), .ok(obj_ok), .data(obj_data),
        .req(spr_req), .mem_addr(spr_addr), .ack(spr_ack), .mem_data(spr_q[31:0]));

    wire [20:0] pcm_a [4];
    wire [3:0] pcm_cs, pcm_ok, pcm_reqs, pcm_acks;
    wire [20:0] pcm_mem_a [4];
    wire [7:0] pcm_data [4];
    genvar g;
    generate for (g=0;g<4;g=g+1) begin: pcm_bus
        rom_bridge #(.AW(21),.DW(8)) b_pcm(
            .clk(clk), .rst(rst), .cs(pcm_cs[g]), .addr(pcm_a[g]), .ok(pcm_ok[g]), .data(pcm_data[g]),
            .req(pcm_reqs[g]), .mem_addr(pcm_mem_a[g]), .ack(pcm_acks[g]), .mem_data(pcm_q));
    end endgenerate
    pcm_arbiter u_pcm_arb(.clk(clk),.rst(rst),.req(pcm_reqs),.addr(pcm_mem_a),.ack(pcm_acks),
        .mem_req(pcm_req),.mem_addr(pcm_addr),.mem_ack(pcm_ack));

    wire [14:1] ram_a;
    wire ram_cs, ram_we;
    wire [1:0] ram_dsn;
    wire [15:0] ram_din, ram_q;
    jtframe_ram16 #(.AW(14)) u_wram(.clk(clk),.addr(ram_a),.data(ram_din),
        .we({2{ram_we}} & ~ram_dsn),.q(ram_q));
    // Work RAM has a synchronous read port. A client must not consume q on
    // the first edge after changing its request: q still belongs to the
    // previous address until that edge completes. Sample request identity
    // alongside the RAM and acknowledge only the matching current transfer.
    // This also invalidates readiness immediately on a held-CS address/mode
    // change. Writes are acknowledged after matching data has been clocked in.
    reg ram_cs_q;
    reg [14:1] ram_a_q;
    reg ram_we_q;
    reg [1:0] ram_dsn_q;
    reg [15:0] ram_din_q;
    always @(posedge clk) begin
        ram_cs_q <= !rst && ram_cs;
        ram_a_q <= ram_a;
        ram_we_q <= ram_we;
        ram_dsn_q <= ram_dsn;
        ram_din_q <= ram_din;
    end
    wire ram_ok = !rst && ram_cs && ram_cs_q && ram_a==ram_a_q &&
                  ram_we==ram_we_q && ram_dsn==ram_dsn_q &&
                  (!ram_we || ram_din==ram_din_q);
    // Physical SRAM retained for the platform self-test; no work RAM client.
    assign ext_req = 0;
    assign ext_we = 0;
    assign ext_addr = 0;
    assign ext_d = 0;
    assign ext_be = 0;

    wire [6:0] game_nv_a;
    wire [7:0] game_nv_d, game_nv_q;
    wire game_nv_we;
    wire default_nv_we = dl_we && dl_addr[24:7] == (25'h0910000 >> 7);
    jtframe_dual_ram #(.DW(8),.AW(7)) u_nvram(
        .clk0(clk),.addr0(game_nv_a),.data0(game_nv_d),.we0(game_nv_we),.q0(game_nv_q),
        .clk1(clk),.addr1(default_nv_we ? dl_addr[6:0] : nv_addr),
        .data1(default_nv_we ? dl_data : nv_din),.we1(default_nv_we | nv_we),.q1(nv_dout));
    assign nv_changed = game_nv_we;

    reg [3:0] div6;
    reg [4:0] div4;
    reg [5:0] div2;
    reg [3:0] dot_div;
    wire cen6 = !pause && div6 == 15;
    wire cen4 = !pause && div4 == 23;
    wire cen2 = !pause && div2 == 47;
    wire pxl2 = pix_sync || dot_div == 7;
    always @(posedge clk) begin
        if (!pause) begin
            div6 <= div6 == 15 ? 0 : div6+4'd1;
            div4 <= div4 == 23 ? 0 : div4+5'd1;
            div2 <= div2 == 47 ? 0 : div2+6'd1;
        end
        dot_div <= pix_sync ? 0 : dot_div+4'd1;
        if (rst) begin div6<=0; div4<=0; div2<=0; end
    end
    wire [4:0] red, green, blue;
    wire lhbl, lvbl;
    wire signed [15:0] fm_l, fm_r, kpcm_l, kpcm_r;
    jtasterix_game u_game(
        .clk(clk),.rst(rst),.pxl_cen(pix_sync),.pxl2_cen(pxl2),
        .dbg_addr(dbg_addr),.dbg_bus(dbg_bus),.dbg_halted(dbg_halted),.dbg_wait(dbg_wait),
        .cen_6(cen6),.cen_fm(cen4),.cen_fm2(cen2),.cen_pcm(cen4),
        .red(red),.green(green),.blue(blue),.LHBL(lhbl),.LVBL(lvbl),.HS(hsync),.VS(vsync),
        .cab_1p({2'b11,p2[7],p1[7]}),.coin({2'b11,in0[1:0]}),
        // Main's KONAMI16 port preserves L/R/U/D/B1/B2 in bits 0..5.
        // Pocket kpad already supplies that order for both players.
        .joystick1(p1[5:0]),
        .joystick2(p2[5:0]),
        .dip_pause(!pause),.dip_test(test_n),.service(in0[4]),
        .snd_en(6'b111111),.gfx_en(4'b1111),.debug_bus(8'b0),.debug_view(dbg_status),
        .ioctl_addr(16'b0),.ioctl_ram(1'b0),.ioctl_din(),
        .main_addr(main_a),.main_cs(main_cs),.main_data(main_data),.main_ok(main_ok),
        .ram_addr(ram_a),.ram_cs(ram_cs),.ram_we(ram_we),.ram_din(ram_din),.ram_dsn(ram_dsn),
        .ram_data(ram_q),.ram_ok(ram_ok),
        .scr_addr(scr_a),.scr_cs(scr_cs),.scr_data(scr_data),.scr_ok(scr_ok),
        .obj_addr(obj_a),.obj_cs(obj_cs),.obj_data(obj_data),.obj_ok(obj_ok),
        .snd_addr(snd_a),.snd_cs(snd_cs),.snd_data(snd_data),.snd_ok(snd_ok),
        .pcma_addr(pcm_a[0]),.pcmb_addr(pcm_a[1]),.pcmc_addr(pcm_a[2]),.pcmd_addr(pcm_a[3]),
        .pcma_cs(pcm_cs[0]),.pcmb_cs(pcm_cs[1]),.pcmc_cs(pcm_cs[2]),.pcmd_cs(pcm_cs[3]),
        .pcma_data(pcm_data[0]),.pcmb_data(pcm_data[1]),.pcmc_data(pcm_data[2]),.pcmd_data(pcm_data[3]),
        .pcma_ok(pcm_ok[0]),.pcmb_ok(pcm_ok[1]),.pcmc_ok(pcm_ok[2]),.pcmd_ok(pcm_ok[3]),
        .fm_l(fm_l),.fm_r(fm_r),.pcm_l(kpcm_l),.pcm_r(kpcm_r),
        .nvram_addr(game_nv_a),.nvram_din(game_nv_d),.nvram_we(game_nv_we),.nvram_dout(game_nv_q)
    );
    // Each DAC is 5 bits; expand by replication for Pocket RGB888.
    assign rgb = {red,red[4:2],green,green[4:2],blue,blue[4:2]};
    assign hblank = ~lhbl;
    assign vblank = ~lvbl;
    assign de = lhbl && lvbl;
    assign pix_ce = pix_sync;
    wire signed [17:0] mix_l = (18'(fm_l) >>> 1) + ((18'(kpcm_l)*18'sd3) >>> 2);
    wire signed [17:0] mix_r = (18'(fm_r) >>> 1) + ((18'(kpcm_r)*18'sd3) >>> 2);
    function automatic signed [15:0] clip(input signed [17:0] value);
        if (value>32767) clip=16'sh7fff;
        else if (value < -32768) clip=16'sh8000;
        else clip=value[15:0];
    endfunction
    always @(posedge clk) begin
        snd_l <= rst || pause ? 16'sd0 : clip(mix_l);
        snd_r <= rst || pause ? 16'sd0 : clip(mix_r);
    end
    assign watchdog_reset = 0;
    assign dbg_snd_worst = 0;
    assign dbg_snd_reads = 0;
endmodule
