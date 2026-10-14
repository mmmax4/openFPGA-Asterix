//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2022, Analogue Enterprises Limited
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------
// Platform Specific top-level -- Cowboys of Moo Mesa
// Instantiated by the real top-level: apf_top
//
// The machine (rtl/moomesa_core.sv) is platform-agnostic; this file is the APF
// glue: bridge, the ROM slot, the interact menu, video and audio hand-off, the
// memories, and the bring-up panel.  The ROM image lives in SDRAM and the
// tilemap RAM in the SRAM (target/pocket/moomesa_mem.sv).
//
// Everything above the "@ The game" banner is the framework's and is the same
// in every core here.  Below it, the shapes are proven on hardware -- the
// reset chain, the SRAM self-test, the pause, the clock-domain hand-overs --
// and the contents are yours.  Read METHODOLOGY.md sections 5.4, 5.5, 5.8 and
// 5.16 to 5.21 before changing a shape.
//------------------------------------------------------------------------------

`default_nettype none

module core_top
    #(
         //! ------------------------------------------------------------------------
         //! System Configuration Parameters
         //! ------------------------------------------------------------------------
         // Memory
         parameter USE_SDRAM    = 1,       //! Enable SDRAM (the whole ROM image)
         parameter USE_SRAM     = 1,       //! Enable SRAM (tilemap VRAM)
         parameter USE_CRAM0    = 0,       //! Cellular RAM #1: unused
         parameter USE_CRAM1    = 0,       //! Cellular RAM #2: unused
         // Video
         parameter BPP_R        = 8,       //! Bits Per Pixel Red
         parameter BPP_G        = 8,       //! Bits Per Pixel Green
         parameter BPP_B        = 8,       //! Bits Per Pixel Blue
         // Audio
         parameter AUDIO_DW     = 16,      //! Audio Bits
         parameter AUDIO_S      = 1,       //! Signed Audio
         parameter STEREO       = 1,       //! Stereo Output
         parameter AUDIO_MIX    = 0,       //! [0] No Mix | [1] 25% | [2] 50% | [3] 100% (mono)
         // Gamepad/Joystick
         parameter JOY_PADS     = 2,       //! Total Number of Gamepads
         parameter JOY_ALT      = 0,       //! 2 Players Alternate
         // Data I/O - [MPU -> FPGA]
         parameter DIO_MASK     = 4'h0,    //! Upper 4 bits of address
         parameter DIO_AW       = 27,      //! Address Width
         parameter DIO_DW       = 8,       //! Data Width (8 or 16 bits)
         parameter DIO_DELAY    = 7,       //! Number of clock cycles to delay each write output
         parameter DIO_HOLD     = 4,       //! Number of clock cycles to hold the ioctl_wr signal high
         // HiScore I/O - [MPU <-> FPGA]
         parameter HS_AW        = 16,      //! Max size of game RAM address for highscores
         parameter HS_SW        = 8,       //! Max size of capture RAM For highscore data (default 8 = 256 bytes max)
         parameter HS_CFG_AW    = 2,       //! Max size of RAM address for highscore.dat entries (default 4 = 16 entries max)
         parameter HS_CFG_LW    = 2,       //! Max size of length for each highscore.dat entries (default 1 = 256 bytes max)
         parameter HS_CONFIG    = 2,       //! Dataslot index for config transfer
         parameter HS_DATA      = 3,       //! Dataslot index for save data transfer
         parameter HS_NVM_SZ    = 32'd93,  //! Number bytes required for Save
         parameter HS_MASK      = 4'h1,    //! Upper 4 bits of address
         parameter HS_WR_DELAY  = 4,       //! Number of clock cycles to delay each write output
         parameter HS_WR_HOLD   = 1,       //! Number of clock cycles to hold the nvram_wr signal high
         parameter HS_RD_DELAY  = 4,       //! Number of clock cycles it takes for a read to complete
         // Save I/O - [MPU <-> FPGA]
         parameter SIO_MASK     = 4'h1,    //! Upper 4 bits of address
         parameter SIO_AW       = 27,      //! Address Width
         parameter SIO_DW       = 8,       //! Data Width (8 or 16 bits)
         parameter SIO_WR_DELAY = 4,       //! Number of clock cycles to delay each write output
         parameter SIO_WR_HOLD  = 1,       //! Number of clock cycles to hold the nvram_wr signal high
         parameter SIO_RD_DELAY = 4,       //! Number of clock cycles it takes for a read to complete
         parameter SIO_SAVE_IDX = 2        //! Dataslot index for save data transfer
     ) (
         //! --------------------------------------------------------------------
         //! Clock Inputs 74.25mhz.
         //! Not Phase Aligned, Treat These Domains as Asynchronous
         //! --------------------------------------------------------------------
         input wire          clk_74a, // mainclk1
         input wire          clk_74b, // mainclk1

         //! --------------------------------------------------------------------
         //! Cartridge Interface
         //! --------------------------------------------------------------------
         inout  wire   [7:0] cart_tran_bank2,
         output wire         cart_tran_bank2_dir,
         inout  wire   [7:0] cart_tran_bank3,
         output wire         cart_tran_bank3_dir,
         inout  wire   [7:0] cart_tran_bank1,
         output wire         cart_tran_bank1_dir,
         inout  wire   [7:4] cart_tran_bank0,
         output wire         cart_tran_bank0_dir,
         inout  wire         cart_tran_pin30,
         output wire         cart_tran_pin30_dir,
         output wire         cart_pin30_pwroff_reset,
         inout  wire         cart_tran_pin31,
         output wire         cart_tran_pin31_dir,

         //! --------------------------------------------------------------------
         //! Infrared
         //! --------------------------------------------------------------------
         input  wire         port_ir_rx,
         output wire         port_ir_tx,
         output wire         port_ir_rx_disable,

         //! --------------------------------------------------------------------
         //! GBA link port
         //! --------------------------------------------------------------------
         inout  wire         port_tran_si,
         output wire         port_tran_si_dir,
         inout  wire         port_tran_so,
         output wire         port_tran_so_dir,
         inout  wire         port_tran_sck,
         output wire         port_tran_sck_dir,
         inout  wire         port_tran_sd,
         output wire         port_tran_sd_dir,

         //! --------------------------------------------------------------------
         //! Cellular PSRAM 0 and 1, two chips (64mbit x2 dual die per chip)
         //! --------------------------------------------------------------------
         output wire [21:16] cram0_a,
         inout  wire  [15:0] cram0_dq,
         input  wire         cram0_wait,
         output wire         cram0_clk,
         output wire         cram0_adv_n,
         output wire         cram0_cre,
         output wire         cram0_ce0_n,
         output wire         cram0_ce1_n,
         output wire         cram0_oe_n,
         output wire         cram0_we_n,
         output wire         cram0_ub_n,
         output wire         cram0_lb_n,

         output wire [21:16] cram1_a,
         inout  wire  [15:0] cram1_dq,
         input  wire         cram1_wait,
         output wire         cram1_clk,
         output wire         cram1_adv_n,
         output wire         cram1_cre,
         output wire         cram1_ce0_n,
         output wire         cram1_ce1_n,
         output wire         cram1_oe_n,
         output wire         cram1_we_n,
         output wire         cram1_ub_n,
         output wire         cram1_lb_n,

         //! --------------------------------------------------------------------
         //! SDRAM, 512mbit 16bit
         //! --------------------------------------------------------------------
         output wire  [12:0] dram_a,        // Address bus
         output wire   [1:0] dram_ba,       // Bank select (single bits)
         inout  wire  [15:0] dram_dq,       // Bidirectional data bus
         output wire   [1:0] dram_dqm,      // High/low byte mask
         output wire         dram_clk,      // Chip clock
         output wire         dram_cke,      // Clock enable
         output wire         dram_ras_n,    // Select row address (active low)
         output wire         dram_cas_n,    // Select column address (active low)
         output wire         dram_we_n,     // Write enable (active low)

         //! --------------------------------------------------------------------
         //! SRAM, 1mbit 16bit
         //! --------------------------------------------------------------------
         output wire  [16:0] sram_a,        // Address bus
         inout  wire  [15:0] sram_dq,       // Bidirectional data bus
         output wire         sram_oe_n,     // Output enable
         output wire         sram_we_n,     // Write enable
         output wire         sram_ub_n,     // Upper Byte Mask
         output wire         sram_lb_n,     // Lower Byte Mask

         //! --------------------------------------------------------------------
         //! vblank driven by dock for sync in a certain mode
         //! --------------------------------------------------------------------
         input  wire         vblank,

         //! --------------------------------------------------------------------
         //! I/O to 6515D breakout USB UART
         //! --------------------------------------------------------------------
         output wire         dbg_tx,
         input  wire         dbg_rx,

         //! --------------------------------------------------------------------
         //! I/O pads near jtag connector user can solder to
         //! --------------------------------------------------------------------
         output wire         user1,
         input  wire         user2,

         //! --------------------------------------------------------------------
         //! RFU internal i2c bus
         //! --------------------------------------------------------------------
         inout  wire         aux_sda,
         output wire         aux_scl,

         //! --------------------------------------------------------------------
         //! RFU, do not use !!!
         //! --------------------------------------------------------------------
         output wire         vpll_feed,

         //! --------------------------------------------------------------------
         //! Video Output to Scaler
         //! --------------------------------------------------------------------
         output wire  [23:0] video_rgb,
         output wire         video_rgb_clock,
         output wire         video_rgb_clock_90,
         output wire         video_hs,
         output wire         video_vs,
         output wire         video_de,
         output wire         video_skip,

         //! --------------------------------------------------------------------
         //! Audio
         //! --------------------------------------------------------------------
         output wire         audio_mclk,
         output wire         audio_lrck,
         output wire         audio_dac,
         input  wire         audio_adc,

         //! --------------------------------------------------------------------
         //! Bridge Bus Connection (synchronous to clk_74a)
         //! --------------------------------------------------------------------
         output wire         bridge_endian_little,
         input  wire  [31:0] bridge_addr,
         input  wire         bridge_rd,
         output reg   [31:0] bridge_rd_data,
         input  wire         bridge_wr,
         input  wire  [31:0] bridge_wr_data,

         //! --------------------------------------------------------------------
         //! Controller Data
         //! --------------------------------------------------------------------
         input  wire  [31:0] cont1_key,
         input  wire  [31:0] cont2_key,
         input  wire  [31:0] cont3_key,
         input  wire  [31:0] cont4_key,
         input  wire  [31:0] cont1_joy,
         input  wire  [31:0] cont2_joy,
         input  wire  [31:0] cont3_joy,
         input  wire  [31:0] cont4_joy,
         input  wire  [15:0] cont1_trig,
         input  wire  [15:0] cont2_trig,
         input  wire  [15:0] cont3_trig,
         input  wire  [15:0] cont4_trig
     );

    // not using the IR port, so turn off both the LED, and
    // disable the receive circuit to save power
    assign port_ir_tx         = 0;
    assign port_ir_rx_disable = 1;

    // bridge endianness
    assign bridge_endian_little = 0;

    // cart is unused, so set all level translators accordingly
    // directions are 0:IN, 1:OUT
    assign cart_tran_bank3         = 8'hzz;
    assign cart_tran_bank3_dir     = 1'b0;
    assign cart_tran_bank2         = 8'hzz;
    assign cart_tran_bank2_dir     = 1'b0;
    assign cart_tran_bank1         = 8'hzz;
    assign cart_tran_bank1_dir     = 1'b0;
    assign cart_tran_bank0         = 4'hf;
    assign cart_tran_bank0_dir     = 1'b1;
    assign cart_tran_pin30         = 1'b0;  // reset or cs2, we let the hw control it by itself
    assign cart_tran_pin30_dir     = 1'bz;
    assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
    assign cart_tran_pin31         = 1'bz;  // input
    assign cart_tran_pin31_dir     = 1'b0;  // input

    // link port is input only
    assign port_tran_so      = 1'bz;
    assign port_tran_so_dir  = 1'b0; // SO is output only
    assign port_tran_si      = 1'bz;
    assign port_tran_si_dir  = 1'b0; // SI is input only
    assign port_tran_sck     = 1'bz;
    assign port_tran_sck_dir = 1'b0; // clock direction can change
    assign port_tran_sd      = 1'bz;
    assign port_tran_sd_dir  = 1'b0; // SD is input and not used

    assign video_skip = 1'b0;

    assign dbg_tx    = 1'bZ;
    assign user1     = 1'bZ;
    assign aux_scl   = 1'bZ;
    assign vpll_feed = 1'bZ;

    // Tie off the memory the pins not being used
    generate
        if(USE_CRAM0 == 0) begin
            assign cram0_a     = 'h0;
            assign cram0_dq    = {16{1'bZ}};
            assign cram0_clk   = 0;
            assign cram0_adv_n = 1;
            assign cram0_cre   = 0;
            assign cram0_ce0_n = 1;
            assign cram0_ce1_n = 1;
            assign cram0_oe_n  = 1;
            assign cram0_we_n  = 1;
            assign cram0_ub_n  = 1;
            assign cram0_lb_n  = 1;
        end
        if(USE_CRAM1 == 0) begin
            assign cram1_a     = 'h0;
            assign cram1_dq    = {16{1'bZ}};
            assign cram1_clk   = 0;
            assign cram1_adv_n = 1;
            assign cram1_cre   = 0;
            assign cram1_ce0_n = 1;
            assign cram1_ce1_n = 1;
            assign cram1_oe_n  = 1;
            assign cram1_we_n  = 1;
            assign cram1_ub_n  = 1;
            assign cram1_lb_n  = 1;
        end
        if(USE_SDRAM == 0) begin
            assign dram_a     = 'h0;
            assign dram_ba    = 'h0;
            assign dram_dq    = {16{1'bZ}};
            assign dram_dqm   = 'h0;
            assign dram_clk   = 'h0;
            assign dram_cke   = 'h0;
            assign dram_ras_n = 'h1;
            assign dram_cas_n = 'h1;
            assign dram_we_n  = 'h1;
        end
        if(USE_SRAM == 0) begin
            assign sram_a    = 'h0;
            assign sram_dq   = {16{1'bZ}};
            assign sram_oe_n = 1;
            assign sram_we_n = 1;
            assign sram_ub_n = 1;
            assign sram_lb_n = 1;
        end
    endgenerate

    //! ------------------------------------------------------------------------
    //! Host/Target Command Handler
    //! ------------------------------------------------------------------------
    wire        reset_n;  // driven by host commands, can be used as core-wide reset
    wire [31:0] cmd_bridge_rd_data;

    // bridge host commands
    // synchronous to clk_74a
    wire        status_boot_done  = pll_core_locked_s;
    wire        status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire        status_running    = reset_n;           // we are running as soon as reset_n goes high

    wire        dataslot_requestread;
    wire [15:0] dataslot_requestread_id;
    wire        dataslot_requestread_ack = 1;
    wire        dataslot_requestread_ok  = 1;

    wire        dataslot_requestwrite;
    wire [15:0] dataslot_requestwrite_id;
    wire [31:0] dataslot_requestwrite_size;
    wire        dataslot_requestwrite_ack = 1;
    wire        dataslot_requestwrite_ok  = 1;

    wire        dataslot_update;
    wire [15:0] dataslot_update_id;
    wire [31:0] dataslot_update_size;

    wire        dataslot_allcomplete;

    wire [31:0] rtc_epoch_seconds;
    wire [31:0] rtc_date_bcd;
    wire [31:0] rtc_time_bcd;
    wire        rtc_valid;

    wire        savestate_supported;
    wire [31:0] savestate_addr;
    wire [31:0] savestate_size;
    wire [31:0] savestate_maxloadsize;

    wire        savestate_start;
    wire        savestate_start_ack;
    wire        savestate_start_busy;
    wire        savestate_start_ok;
    wire        savestate_start_err;

    wire        savestate_load;
    wire        savestate_load_ack;
    wire        savestate_load_busy;
    wire        savestate_load_ok;
    wire        savestate_load_err;

    wire        osnotify_inmenu;

    // bridge target commands
    // synchronous to clk_74a
    reg         target_dataslot_read;
    reg         target_dataslot_write;
    reg         target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg         target_dataslot_openfile;   // require additional param/resp structs to be mapped

    wire        target_dataslot_ack;
    wire        target_dataslot_done;
    wire  [2:0] target_dataslot_err;

    reg  [15:0] target_dataslot_id;
    reg  [31:0] target_dataslot_slotoffset;
    reg  [31:0] target_dataslot_bridgeaddr;
    reg  [31:0] target_dataslot_length;

    wire [31:0] target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire [31:0] target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands

    // bridge data slot access
    // synchronous to clk_74a
    logic  [9:0] datatable_addr;
    logic        datatable_wren;
    logic [31:0] datatable_data;
    wire  [31:0] datatable_q;

    // the save slot's size for the APF, written continuously as the NES core
    // does (slot index 1 -> size entry 1*2+1): the 128-byte EEPROM
    localparam [31:0] NV_BYTES = 32'h80;
    always_ff @(posedge clk_74a) begin
        datatable_wren <= 1'b1;
        datatable_addr <= 10'd5;
        datatable_data <= NV_BYTES;
    end

    core_bridge_cmd icb
    (
        .clk                        ( clk_74a                    ),
        .reset_n                    ( reset_n                    ),

        .bridge_endian_little       ( bridge_endian_little       ),
        .bridge_addr                ( bridge_addr                ),
        .bridge_rd                  ( bridge_rd                  ),
        .bridge_rd_data             ( cmd_bridge_rd_data         ),
        .bridge_wr                  ( bridge_wr                  ),
        .bridge_wr_data             ( bridge_wr_data             ),

        .status_boot_done           ( status_boot_done           ),
        .status_setup_done          ( status_setup_done          ),
        .status_running             ( status_running             ),

        .dataslot_requestread       ( dataslot_requestread       ),
        .dataslot_requestread_id    ( dataslot_requestread_id    ),
        .dataslot_requestread_ack   ( dataslot_requestread_ack   ),
        .dataslot_requestread_ok    ( dataslot_requestread_ok    ),

        .dataslot_requestwrite      ( dataslot_requestwrite      ),
        .dataslot_requestwrite_id   ( dataslot_requestwrite_id   ),
        .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
        .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack  ),
        .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok   ),

        .dataslot_update            ( dataslot_update            ),
        .dataslot_update_id         ( dataslot_update_id         ),
        .dataslot_update_size       ( dataslot_update_size       ),

        .dataslot_allcomplete       ( dataslot_allcomplete       ),

        .rtc_epoch_seconds          ( rtc_epoch_seconds          ),
        .rtc_date_bcd               ( rtc_date_bcd               ),
        .rtc_time_bcd               ( rtc_time_bcd               ),
        .rtc_valid                  ( rtc_valid                  ),

        .savestate_supported        ( savestate_supported        ),
        .savestate_addr             ( savestate_addr             ),
        .savestate_size             ( savestate_size             ),
        .savestate_maxloadsize      ( savestate_maxloadsize      ),

        .savestate_start            ( savestate_start            ),
        .savestate_start_ack        ( savestate_start_ack        ),
        .savestate_start_busy       ( savestate_start_busy       ),
        .savestate_start_ok         ( savestate_start_ok         ),
        .savestate_start_err        ( savestate_start_err        ),

        .savestate_load             ( savestate_load             ),
        .savestate_load_ack         ( savestate_load_ack         ),
        .savestate_load_busy        ( savestate_load_busy        ),
        .savestate_load_ok          ( savestate_load_ok          ),
        .savestate_load_err         ( savestate_load_err         ),

        .osnotify_inmenu            ( osnotify_inmenu            ),

        .target_dataslot_read       ( target_dataslot_read       ),
        .target_dataslot_write      ( target_dataslot_write      ),
        .target_dataslot_getfile    ( target_dataslot_getfile    ),
        .target_dataslot_openfile   ( target_dataslot_openfile   ),

        .target_dataslot_ack        ( target_dataslot_ack        ),
        .target_dataslot_done       ( target_dataslot_done       ),
        .target_dataslot_err        ( target_dataslot_err        ),

        .target_dataslot_id         ( target_dataslot_id         ),
        .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
        .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
        .target_dataslot_length     ( target_dataslot_length     ),

        .target_buffer_param_struct ( target_buffer_param_struct ),
        .target_buffer_resp_struct  ( target_buffer_resp_struct  ),

        .datatable_addr             ( datatable_addr             ),
        .datatable_wren             ( datatable_wren             ),
        .datatable_data             ( datatable_data             ),
        .datatable_q                ( datatable_q                )
    );

    //! END OF APF /////////////////////////////////////////////////////////////

    //! ////////////////////////////////////////////////////////////////////////
    //! @ System Modules
    //! ////////////////////////////////////////////////////////////////////////

    //! ------------------------------------------------------------------------
    //! APF Bridge Read Data
    //! ------------------------------------------------------------------------
    wire [31:0] int_bridge_rd_data;
    wire [31:0] sv_bridge_rd_data;
    always_comb begin
        casex(bridge_addr)
            32'hF0000000: begin bridge_rd_data <= int_bridge_rd_data;   end // Reset
            32'hF0000010: begin bridge_rd_data <= int_bridge_rd_data;   end // Service Mode Switch
            32'hF1000000: begin bridge_rd_data <= int_bridge_rd_data;   end // DIP Switches
            32'hF2000000: begin bridge_rd_data <= int_bridge_rd_data;   end // Modifiers
            32'hF3000000: begin bridge_rd_data <= int_bridge_rd_data;   end // A/V Filters
            32'hF4000000: begin bridge_rd_data <= int_bridge_rd_data;   end // Extra DIP Switches
            32'hF8xxxxxx: begin bridge_rd_data <= cmd_bridge_rd_data;   end // APF Bridge (Reserved)
            32'h2xxxxxxx: begin bridge_rd_data <= sv_bridge_rd_data;    end // the save slot (EEPROM)
            32'hFA000000: begin bridge_rd_data <= int_bridge_rd_data;   end // Status Low  [31:0]
            32'hFB000000: begin bridge_rd_data <= int_bridge_rd_data;   end // Status High [63:32]
            default:      begin bridge_rd_data <= 0;                    end
        endcase
    end

    //! ------------------------------------------------------------------------
    //! Pause Core (Analogue OS Menu/Module Request)
    //! ------------------------------------------------------------------------
    wire pause_core, pause_req;
    pause_crtl core_pause
    (
        .clk_sys    ( clk_sys         ),
        .os_inmenu  ( osnotify_inmenu ),
        .pause_req  ( pause_req       ),
        .pause_core ( pause_core      )
    );

    //! ------------------------------------------------------------------------
    //! Interact: Dip Switches, Modifiers, Filters and Reset
    //! ------------------------------------------------------------------------
    wire  [7:0] dip_sw0, dip_sw1, dip_sw2, dip_sw3;
    wire  [7:0] ext_sw0, ext_sw1, ext_sw2, ext_sw3;
    wire  [7:0] mod_sw0, mod_sw1, mod_sw2, mod_sw3;
    wire  [3:0] scnl_sw, smask_sw, afilter_sw, vol_att;
    wire [63:0] status;
    wire        reset_sw, svc_sw, nvclear_sw;

    interact pocket_interact
    (
        // Clocks and Reset
        .clk_74a          ( clk_74a            ),
        .clk_sync         ( clk_sys            ),
        .reset_n          ( reset_n            ),
        // Pocket Bridge
        .bridge_addr      ( bridge_addr        ),
        .bridge_wr        ( bridge_wr          ),
        .bridge_wr_data   ( bridge_wr_data     ),
        .bridge_rd        ( bridge_rd          ),
        .bridge_rd_data   ( int_bridge_rd_data ),
        // Service Mode Switch
        .svc_sw           ( svc_sw             ),
        // DIP Switches
        .dip_sw0          ( dip_sw0            ),
        .dip_sw1          ( dip_sw1            ),
        .dip_sw2          ( dip_sw2            ),
        .dip_sw3          ( dip_sw3            ),
        // Extra DIP Switches
        .ext_sw0          ( ext_sw0            ),
        .ext_sw1          ( ext_sw1            ),
        .ext_sw2          ( ext_sw2            ),
        .ext_sw3          ( ext_sw3            ),
        // Modifiers
        .mod_sw0          ( mod_sw0            ),
        .mod_sw1          ( mod_sw1            ),
        .mod_sw2          ( mod_sw2            ),
        .mod_sw3          ( mod_sw3            ),
        // Status (Legacy Support)
        .status           ( status             ),
        // Filters Switches
        .scnl_sw          ( scnl_sw            ),
        .smask_sw         ( smask_sw           ),
        .afilter_sw       ( afilter_sw         ),
        .vol_att          ( vol_att            ),
        // Reset Switch
        .reset_sw         ( reset_sw           ),
        .nvclear_sw       ( nvclear_sw         )
    );

    //! ------------------------------------------------------------------------
    //! Audio
    //! ------------------------------------------------------------------------
    wire [AUDIO_DW-1:0] core_snd_l, core_snd_r; // Audio Mono/Left/Right

    audio_mixer #(.DW(AUDIO_DW),.STEREO(STEREO),.IIR(0)) pocket_audio_mixer
    (
        // Clocks and Reset
        .clk_74b    ( clk_74b    ),
        .reset      ( reset_sw   ),
        // Controls
        .afilter_sw ( afilter_sw ),
        .vol_att    ( vol_att    ),
        .mix        ( AUDIO_MIX  ),
        .pause_core ( pause_core ),
        // Audio From Core
        .is_signed  ( AUDIO_S    ),
        .core_l     ( core_snd_l ),
        .core_r     ( core_snd_r ),
        // I2S
        .audio_mclk ( audio_mclk ),
        .audio_lrck ( audio_lrck ),
        .audio_dac  ( audio_dac  )
    );

    //! ------------------------------------------------------------------------
    //! Video
    //! ------------------------------------------------------------------------
    wire       [2:0] video_preset;     // Video Preset Configuration
    wire [BPP_R-1:0] core_r;           // Video Red
    wire [BPP_G-1:0] core_g;           // Video Green
    wire [BPP_B-1:0] core_b;           // Video Blue
    wire             core_hs, core_hb; // Horizontal Sync/Blank
    wire             core_vs, core_vb; // Vertical Sync/Blank
    wire             core_de;          // Display Enable

    assign core_hb = 1'b0;
    assign core_vb = 1'b0;

    video_mixer #(.RW(BPP_R),.GW(BPP_G),.BW(BPP_B)) pocket_video_mixer
    (
        // Clocks
        .clk_74a                  ( clk_74a                  ),
        .clk_sys                  ( clk_sys                  ),
        .clk_vid                  ( clk_vid                  ),
        .clk_vid_90deg            ( clk_vid_90deg            ),
        // Input Controls
        .video_preset             ( video_preset             ),
        .scnl_sw                  ( scnl_sw                  ),
        .smask_sw                 ( smask_sw                 ),
        // Input Video from Core
        .core_r                   ( core_r                   ),
        .core_g                   ( core_g                   ),
        .core_b                   ( core_b                   ),
        .core_vs                  ( core_vs                  ),
        .core_hs                  ( core_hs                  ),
        .core_de                  ( core_de                  ),
        // Output to Display
        .video_rgb                ( video_rgb                ),
        .video_vs                 ( video_vs                 ),
        .video_hs                 ( video_hs                 ),
        .video_de                 ( video_de                 ),
        .video_rgb_clock          ( video_rgb_clock          ),
        .video_rgb_clock_90       ( video_rgb_clock_90       ),
        // Pocket Bridge Slots
        .dataslot_requestwrite    ( dataslot_requestwrite    ), // [i]
        .dataslot_requestwrite_id ( dataslot_requestwrite_id ), // [i]
        .dataslot_allcomplete     ( dataslot_allcomplete     ), // [i]
        // MPU -> FPGA (MPU Write to FPGA)
        // Pocket Bridge
        .bridge_endian_little     ( bridge_endian_little     ), // [i]
        .bridge_addr              ( bridge_addr              ), // [i]
        .bridge_wr                ( bridge_wr                ), // [i]
        .bridge_wr_data           ( bridge_wr_data           )  // [i]
    );

    //! ------------------------------------------------------------------------
    //! Data I/O
    //! ------------------------------------------------------------------------
    wire              ioctl_download;
    wire       [15:0] ioctl_index;
    wire              ioctl_wr;
    wire [DIO_AW-1:0] ioctl_addr;
    wire [DIO_DW-1:0] ioctl_data;

    data_io #(.MASK(DIO_MASK),.AW(DIO_AW),.DW(DIO_DW),.DELAY(DIO_DELAY),.HOLD(DIO_HOLD)) pocket_data_io
    (
        // Clocks and Reset
        .clk_74a                  ( clk_74a                  ),
        .clk_memory               ( clk_sys                  ),
        // Pocket Bridge Slots
        .dataslot_requestwrite    ( dataslot_requestwrite    ), // [i]
        .dataslot_requestwrite_id ( dataslot_requestwrite_id ), // [i]
        .dataslot_allcomplete     ( dataslot_allcomplete     ), // [i]
        // MPU -> FPGA (MPU Write to FPGA)
        // Pocket Bridge
        .bridge_endian_little     ( bridge_endian_little     ), // [i]
        .bridge_addr              ( bridge_addr              ), // [i]
        .bridge_wr                ( bridge_wr                ), // [i]
        .bridge_wr_data           ( bridge_wr_data           ), // [i]
        // Controller Interface
        .ioctl_download           ( ioctl_download           ), // [o]
        .ioctl_index              ( ioctl_index              ), // [o]
        .ioctl_wr                 ( ioctl_wr                 ), // [o]
        .ioctl_addr               ( ioctl_addr               ), // [o]
        .ioctl_data               ( ioctl_data               )  // [o]
    );

    //! ------------------------------------------------------------------------
    //! Gamepad/Analog Stick
    //! ------------------------------------------------------------------------
    // Player 1
    // - DPAD
    wire       p1_up,     p1_down,   p1_left,   p1_right;
    wire       p1_btn_y,  p1_btn_x,  p1_btn_b,  p1_btn_a;
    wire       p1_btn_l1, p1_btn_l2, p1_btn_l3;
    wire       p1_btn_r1, p1_btn_r2, p1_btn_r3;
    wire       p1_select, p1_start;
    // - Analog
    wire       j1_up,     j1_down,   j1_left,   j1_right;
    wire [7:0] j1_lx,     j1_ly,     j1_rx,     j1_ry;
    // Player 2
    // - DPAD
    wire       p2_up,     p2_down,   p2_left,   p2_right;
    wire       p2_btn_y,  p2_btn_x,  p2_btn_b,  p2_btn_a;
    wire       p2_btn_l1, p2_btn_l2, p2_btn_l3;
    wire       p2_btn_r1, p2_btn_r2, p2_btn_r3;
    wire       p2_select, p2_start;
    // - Analog
    wire       j2_up,     j2_down,   j2_left,   j2_right;
    wire [7:0] j2_lx,     j2_ly,     j2_rx,     j2_ry;
    // Single Player or Alternate 2 Players for Arcade (unused: both players are wired)
    wire m_start1, m_start2;
    wire m_coin1,  m_coin2, m_coin;
    wire m_up,     m_down,  m_left, m_right;
    wire m_btn1,   m_btn2,  m_btn3, m_btn4;
    wire m_btn5,   m_btn6,  m_btn7, m_btn8;

    gamepad #(.JOY_PADS(JOY_PADS),.JOY_ALT(JOY_ALT)) pocket_gamepad
    (
        .clk_sys   ( clk_sys   ),
        // Pocket PAD Interface
        .cont1_key ( cont1_key ), .cont1_joy ( cont1_joy ),
        .cont2_key ( cont2_key ), .cont2_joy ( cont2_joy ),
        .cont3_key ( cont3_key ), .cont3_joy ( cont3_joy ),
        .cont4_key ( cont4_key ), .cont4_joy ( cont4_joy ),
        // Player 1
        .p1_up     ( p1_up     ), .p1_down   ( p1_down   ),
        .p1_left   ( p1_left   ), .p1_right  ( p1_right  ),
        .p1_y      ( p1_btn_y  ), .p1_x      ( p1_btn_x  ),
        .p1_b      ( p1_btn_b  ), .p1_a      ( p1_btn_a  ),
        .p1_l1     ( p1_btn_l1 ), .p1_r1     ( p1_btn_r1 ),
        .p1_l2     ( p1_btn_l2 ), .p1_r2     ( p1_btn_r2 ),
        .p1_l3     ( p1_btn_l3 ), .p1_r3     ( p1_btn_r3 ),
        .p1_se     ( p1_select ), .p1_st     ( p1_start  ),
        .j1_up     ( j1_up     ), .j1_down   ( j1_down   ),
        .j1_left   ( j1_left   ), .j1_right  ( j1_right  ),
        .j1_lx     ( j1_lx     ), .j1_ly     ( j1_ly     ),
        .j1_rx     ( j1_rx     ), .j1_ry     ( j1_ry     ),
        // Player 2
        .p2_up     ( p2_up     ), .p2_down   ( p2_down   ),
        .p2_left   ( p2_left   ), .p2_right  ( p2_right  ),
        .p2_y      ( p2_btn_y  ), .p2_x      ( p2_btn_x  ),
        .p2_b      ( p2_btn_b  ), .p2_a      ( p2_btn_a  ),
        .p2_l1     ( p2_btn_l1 ), .p2_r1     ( p2_btn_r1 ),
        .p2_l2     ( p2_btn_l2 ), .p2_r2     ( p2_btn_r2 ),
        .p2_l3     ( p2_btn_l3 ), .p2_r3     ( p2_btn_r3 ),
        .p2_se     ( p2_select ), .p2_st     ( p2_start  ),
        .j2_up     ( j2_up     ), .j2_down   ( j2_down   ),
        .j2_left   ( j2_left   ), .j2_right  ( j2_right  ),
        .j2_lx     ( j2_lx     ), .j2_ly     ( j2_ly     ),
        .j2_rx     ( j2_rx     ), .j2_ry     ( j2_ry     ),
        // Single Player or Alternate 2 Players for Arcade
        .m_coin    ( m_coin    ),                           // Coinage P1 or P2
        .m_up      ( m_up      ), .m_down    ( m_down    ), // Up/Down
        .m_left    ( m_left    ), .m_right   ( m_right   ), // Left/Right
        .m_btn1    ( m_btn1    ), .m_btn4    ( m_btn4    ), // Y/X
        .m_btn2    ( m_btn2    ), .m_btn3    ( m_btn3    ), // B/A
        .m_btn5    ( m_btn5    ), .m_btn6    ( m_btn6    ), // L1/R1
        .m_btn7    ( m_btn7    ), .m_btn8    ( m_btn8    ), // L2/R2
        .m_coin1   ( m_coin1   ), .m_coin2   ( m_coin2   ), // P1/P2 Coin
        .m_start1  ( m_start1  ), .m_start2  ( m_start2  )  // P1/P2 Start
    );

    //! ------------------------------------------------------------------------
    // Asterix: 96 MHz system / SDRAM, 6 MHz RGB clock pair.
    
    
    wire pll_core_locked, pll_core_locked_s;
    wire clk_sys;       
    wire clk_vid;       
    wire clk_vid_90deg; 
    wire clk_sdram;     
    wire clk_unused1;

    core_pll core_pll
    (
        .refclk   ( clk_74a ),
        .rst      ( 0       ),
        .outclk_0 ( clk_sys       ),
        .outclk_1 ( clk_vid       ),
        .outclk_2 ( clk_vid_90deg ),
        .outclk_3 ( clk_sdram     ),
        .outclk_4 ( clk_unused1   ),
        .locked   ( pll_core_locked )
    );

    synch_3 sync_lck(pll_core_locked, pll_core_locked_s, clk_74a);

    wire reset_sw_s;
    synch_3 sync_rst(reset_sw, reset_sw_s, clk_sys);
    wire pll_locked_sys;
    synch_3 sync_lck2(pll_core_locked, pll_locked_sys, clk_sys);

    wire mem_init  = ~pll_locked_sys;
    wire mem_ready, mem_load_ready;
    logic loaded = 1'b0;
    wire  allc_s;
    synch_3 sync_allc(dataslot_allcomplete, allc_s, clk_sys);
    always_ff @(posedge clk_sys) if (allc_s) loaded <= 1'b1;
    wire game_bucky = 1'b0;
    wire rom_valid = 1'b1;
    wire machine_reset_request = reset_sw_s | ~loaded | ~mem_ready |
                                 ~mem_load_ready | ~sram_done | ~rom_valid;
    wire g_reset;
    pocket_machine_reset machine_reset (
        .clk(clk_sys), .request(machine_reset_request), .reset_out(g_reset)
    );

    wire        ioctl_isROM = ioctl_download && ioctl_index == 16'h1;
    wire        dl_we       = ioctl_isROM && ioctl_wr;
    wire [24:0] dl_addr     = ioctl_addr[24:0];
    wire  [7:0] dl_data     = ioctl_data;

    wire p1_b1 = p1_btn_b | (!game_bucky && p1_btn_x), p1_b2 = p1_btn_a | p1_btn_y;
    wire p2_b1 = p2_btn_b | (!game_bucky && p2_btn_x), p2_b2 = p2_btn_a | p2_btn_y;
    wire svc   = mod_sw1[0] | svc_sw;
    
    logic [15:0] c3_s1, c3_s2, c4_s1, c4_s2;
    always_ff @(posedge clk_sys) begin
        c3_s1 <= cont3_key[15:0]; c3_s2 <= c3_s1;
        c4_s1 <= cont4_key[15:0]; c4_s2 <= c4_s1;
    end
    function automatic [7:0] kpad(input st, input b3, input b2, input b1, input dn, input up, input rt, input lf);
        kpad = ~{st, b3, b2, b1, dn, up, rt, lf};
    endfunction
    wire [7:0] g_p1 = kpad(p1_start, game_bucky && p1_btn_x, p1_b2, p1_b1, p1_down | j1_down, p1_up | j1_up,
                           p1_right | j1_right, p1_left | j1_left);
    wire [7:0] g_p2 = kpad(p2_start, game_bucky && p2_btn_x, p2_b2, p2_b1, p2_down | j2_down, p2_up | j2_up,
                           p2_right | j2_right, p2_left | j2_left);
    wire [7:0] g_p3 = kpad(c3_s2[15], game_bucky && c3_s2[6], c3_s2[4] | c3_s2[7], c3_s2[5] | (!game_bucky && c3_s2[6]),
                           c3_s2[1], c3_s2[0], c3_s2[3], c3_s2[2]);
    wire [7:0] g_p4 = kpad(c4_s2[15], game_bucky && c4_s2[6], c4_s2[4] | c4_s2[7], c4_s2[5] | (!game_bucky && c4_s2[6]),
                           c4_s2[1], c4_s2[0], c4_s2[3], c4_s2[2]);

    function automatic cabinet_button(input [3:0] select_key, input [7:0] keys);
        case (select_key)
            4'd1: cabinet_button = keys[0]; 
            4'd2: cabinet_button = keys[1]; 
            4'd3: cabinet_button = keys[2]; 
            4'd4: cabinet_button = keys[3]; 
            4'd5: cabinet_button = keys[4]; 
            4'd6: cabinet_button = keys[5]; 
            4'd7: cabinet_button = keys[6]; 
            4'd8: cabinet_button = keys[7]; 
            default: cabinet_button = 1'b0;
        endcase
    endfunction
    wire [7:0] cabinet_keys = {p1_start, p1_select, p1_btn_r1, p1_btn_l1,
                               p1_btn_y, p1_btn_x, p1_btn_b, p1_btn_a};
    wire test_button = cabinet_button(mod_sw2[3:0], cabinet_keys);
    wire service_button = cabinet_button(mod_sw2[7:4], cabinet_keys);

    wire [7:0] g_in0 = ~{3'b000, service_button, c4_s2[14], c3_s2[14], p2_select, p1_select};
    wire       g_test_n = !(svc | test_button);

    wire [3:0] g_dsw = 4'b1010 ^ dip_sw0[3:0];

    wire g_rd_late      = ~mod_sw0[4];
    wire g_burst_slow   =  mod_sw0[5];
    wire g_sram_slow    =  mod_sw0[7];
    wire g_sram_slow_wr =  mod_sw1[7];

    wire        mrom_req, mrom_ack;  wire [19:1] mrom_addr;  wire [15:0] mrom_q;
    wire        srom_req, srom_ack;  wire [17:0] srom_addr;  wire  [7:0] srom_q;
    wire        pcm_req,  pcm_ack;   wire [21:0] pcm_addr;   wire  [7:0] pcm_q;
    wire        tile_req, tile_ack;  wire [18:0] tile_addr;  wire [31:0] tile_q;
    wire        spr_req,  spr_ack;   wire [19:0] spr_addr;   wire [63:0] spr_q;
    wire [15:0] mrom_misses;
    wire        vram_req, vram_we, vram_ack;
    wire [15:0] vram_addr;  wire [15:0] vram_din, vram_q;  wire [1:0] vram_ben;
    wire ext_req, ext_we;
    wire [15:0] ext_addr, ext_d;
    wire [1:0] ext_be;

    wire [15:0] sram_rd0, sram_rd1;
    wire        sram_done, tv_req, tv_we;
    wire [16:0] tv_addr17;
    wire [14:0] tv_addr = tv_addr17[14:0];
    wire [15:0] tv_din;
    sram_selftest #(.A0(17'h00000), .A1(17'h04000)) u_sramtest (
        .clk(clk_sys), .hold(!mem_ready || !loaded),
        .req(tv_req), .we(tv_we), .addr(tv_addr17), .d(tv_din), .ack(vram_ack), .q(vram_q),
        .done(sram_done), .rd0(sram_rd0), .rd1(sram_rd1)
    );

    assign vram_req  = sram_done ? ext_req : tv_req;
    assign vram_we   = sram_done ? ext_we : tv_we;
    assign vram_addr = sram_done ? ext_addr : {1'b0, tv_addr};
    assign vram_din  = sram_done ? ext_d : tv_din;
    assign vram_ben  = sram_done ? ext_be : 2'b11;

    asterix_mem u_mem (
        .bucky(game_bucky),
        .clk(clk_sys), .clk_sdram(clk_sdram), .init(mem_init), .ready(mem_ready),
        .load_ready(mem_load_ready),
        .rd_late(g_rd_late), .burst_slow(g_burst_slow),
        .sram_slow(g_sram_slow), .sram_slow_wr(g_sram_slow_wr),
        .dl_we(dl_we), .dl_addr(dl_addr), .dl_data(dl_data), .dl_active(ioctl_isROM),
        .mrom_req(mrom_req), .mrom_addr(mrom_addr), .mrom_ack(mrom_ack), .mrom_q(mrom_q),
        .srom_req(srom_req), .srom_addr(srom_addr), .srom_ack(srom_ack), .srom_q(srom_q),
        .pcm_req(pcm_req), .pcm_addr(pcm_addr), .pcm_ack(pcm_ack), .pcm_q(pcm_q),
        .tile_req(tile_req), .tile_addr(tile_addr), .tile_ack(tile_ack), .tile_q(tile_q),
        .spr_req(spr_req), .spr_addr(spr_addr), .spr_ack(spr_ack), .spr_q(spr_q),
        .vram_req(vram_req), .vram_we(vram_we), .vram_addr(vram_addr),
        .vram_din(vram_din), .vram_ben(vram_ben), .vram_ack(vram_ack), .vram_q(vram_q),
        .mrom_misses(mrom_misses),
        .SDRAM_DQ(dram_dq), .SDRAM_A(dram_a), .SDRAM_BA(dram_ba),
        .SDRAM_DQML(dram_dqm[0]), .SDRAM_DQMH(dram_dqm[1]),
        .SDRAM_CLK(dram_clk), .SDRAM_CKE(dram_cke),
        .SDRAM_nRAS(dram_ras_n), .SDRAM_nCAS(dram_cas_n), .SDRAM_nWE(dram_we_n),
        .SDRAM_nCS(),
        .sram_a(sram_a), .sram_dq(sram_dq),
        .sram_oe_n(sram_oe_n), .sram_we_n(sram_we_n),
        .sram_ub_n(sram_ub_n), .sram_lb_n(sram_lb_n)
    );

    wire        g_pix_ce, g_hs, g_vs, g_de, g_vb, g_hb;
    wire [23:0] g_rgb;
    wire signed [15:0] g_snd_l, g_snd_r;
    wire  [7:0] g_status;
    wire [15:0] g_snd_worst;
    wire  [7:0] g_snd_reads;
    wire        g_halted, g_watchdog;
    wire [23:1] g_dbg_addr;  wire g_dbg_bus, g_dbg_wait;

    reg  vt = 1'b0;
    reg  vt_s, vt_d;
    always @(posedge clk_vid) vt <= ~vt;
    always @(posedge clk_sys) begin vt_s <= vt; vt_d <= vt_s; end
    wire pix_sync = vt_s ^ vt_d;

    wire        sv_dl, sv_wr;
    wire [15:0] sv_index;
    wire [26:0] sv_addr;
    wire  [7:0] sv_data;
    data_io #(.MASK(4'h2),.AW(27),.DW(8),.DELAY(DIO_DELAY),.HOLD(DIO_HOLD)) save_data_io
    (
        .clk_74a                  ( clk_74a                  ),
        .clk_memory               ( clk_sys                  ),
        .dataslot_requestwrite    ( dataslot_requestwrite    ),
        .dataslot_requestwrite_id ( dataslot_requestwrite_id ),
        .dataslot_allcomplete     ( dataslot_allcomplete     ),
        .bridge_endian_little     ( bridge_endian_little     ),
        .bridge_addr              ( bridge_addr              ),
        .bridge_wr                ( bridge_wr                ),
        .bridge_wr_data           ( bridge_wr_data           ),
        .ioctl_download           ( sv_dl                    ),
        .ioctl_index              ( sv_index                 ),
        .ioctl_wr                 ( sv_wr                    ),
        .ioctl_addr               ( sv_addr                  ),
        .ioctl_data               ( sv_data                  )
    );
    wire        un_rd;
    wire  [6:0] un_addr;
    wire  [7:0] g_nv_dout;
    wire        g_nv_changed;
    data_unloader #(.ADDRESS_MASK_UPPER_4(4'h2),.ADDRESS_SIZE(7),.READ_MEM_CLOCK_DELAY(2),.INPUT_WORD_SIZE(1)) save_unloader
    (
        .clk_74a              ( clk_74a              ),
        .clk_memory           ( clk_sys              ),
        .bridge_rd            ( bridge_rd            ),
        .bridge_endian_little ( bridge_endian_little ),
        .bridge_addr          ( bridge_addr          ),
        .bridge_rd_data       ( sv_bridge_rd_data    ),
        .read_en              ( un_rd                ),
        .read_addr            ( un_addr              ),
        .read_data            ( g_nv_dout            )
    );
    wire       g_nv_we   = sv_dl && sv_wr && (sv_addr[26:7] == 20'd0);
    wire [6:0] g_nv_addr = sv_dl ? sv_addr[6:0] : un_addr;

    logic [27:0] sv_timer;          
    logic        sv_dirty, sv_tog, sv_loaded_arm, pause_d;
    logic [29:0] sv_boot;           
    always_ff @(posedge clk_sys) begin
        pause_d <= pause_core;
        if (g_nv_changed) begin sv_dirty <= 1'b1; sv_timer <= 28'd192_000_000; end
        else if (sv_timer != 28'd0) sv_timer <= sv_timer - 28'd1;
        if (sv_dirty && ((sv_timer == 28'd1) || (pause_core && !pause_d))) begin
            sv_dirty <= 1'b0; sv_tog <= ~sv_tog;
        end
        if (!loaded) begin sv_boot <= 30'd960_000_000; sv_loaded_arm <= 1'b1; end
        else if (sv_boot != 30'd0) sv_boot <= sv_boot - 30'd1;
        else if (sv_loaded_arm) begin sv_loaded_arm <= 1'b0; sv_tog <= ~sv_tog; end
    end
    logic [2:0] sv_tog_s;
    always_ff @(posedge clk_74a) begin
        sv_tog_s <= {sv_tog_s[1:0], sv_tog};
        target_dataslot_write      <= (sv_tog_s[2] != sv_tog_s[1]);
        target_dataslot_read       <= 1'b0;
        target_dataslot_getfile    <= 1'b0;
        target_dataslot_openfile   <= 1'b0;
        target_dataslot_id         <= 16'd2;
        target_dataslot_slotoffset <= 32'd0;
        target_dataslot_bridgeaddr <= 32'h20000000;
        target_dataslot_length     <= NV_BYTES;
    end

    asterix_core u_core (

        .clk(clk_sys), .rst(g_reset), .bucky(game_bucky), .pause(pause_core), .pix_sync(pix_sync),
        .ext_req(ext_req), .ext_we(ext_we), .ext_addr(ext_addr), .ext_d(ext_d), .ext_be(ext_be),
        .ext_ack(vram_ack && sram_done), .ext_q(vram_q),
        .mrom_req(mrom_req), .mrom_addr(mrom_addr), .mrom_ack(mrom_ack), .mrom_q(mrom_q),
        .srom_req(srom_req), .srom_addr(srom_addr), .srom_ack(srom_ack), .srom_q(srom_q),
        .pcm_req(pcm_req), .pcm_addr(pcm_addr), .pcm_ack(pcm_ack), .pcm_q(pcm_q),
        .tile_req(tile_req), .tile_addr(tile_addr), .tile_ack(tile_ack), .tile_q(tile_q),
        .spr_req(spr_req), .spr_addr(spr_addr), .spr_ack(spr_ack), .spr_q(spr_q),
        .dl_we(dl_we), .dl_addr(dl_addr), .dl_data(dl_data),
        .nv_addr(g_nv_addr), .nv_we(g_nv_we), .nv_din(sv_data), .nv_dout(g_nv_dout), .nv_changed(g_nv_changed),
        .p1(g_p1), .p2(g_p2), .p3(g_p3), .p4(g_p4), .in0(g_in0), .test_n(g_test_n), .dsw(g_dsw),
        .rgb(g_rgb), .hsync(g_hs), .vsync(g_vs),
        .hblank(g_hb), .vblank(g_vb), .pix_ce(g_pix_ce), .de(g_de),
        .snd_l(g_snd_l), .snd_r(g_snd_r),
        .dbg_halted(g_halted), .dbg_addr(g_dbg_addr), .dbg_bus(g_dbg_bus), .dbg_wait(g_dbg_wait),
        .watchdog_reset(g_watchdog),
        .dbg_status(g_status), .dbg_snd_worst(g_snd_worst), .dbg_snd_reads(g_snd_reads)
    );

    wire [1:0] aspect_sel = mod_sw0[2:1];
    assign video_preset = (aspect_sel == 2'd1) ? 3'd1 : 3'd0;

    wire        ovl_en = mod_sw0[3];
    logic [7:0] ovl_frames;
    logic       ovl_wdog;
    logic       vb_d;
    always_ff @(posedge clk_sys) begin
        vb_d <= g_vb;
        if (g_vb && !vb_d) ovl_frames <= ovl_frames + 8'd1;
        if (g_watchdog) ovl_wdog <= 1'b1;
    end

    logic [15:0] first_prog;  logic first_prog_v;
    logic  [7:0] first_snd;   logic first_snd_v;
    logic  [7:0] first_gfx;   logic first_gfx_v;
    always_ff @(posedge clk_sys) begin
        if (mem_init) begin first_prog_v <= 1'b0; first_snd_v <= 1'b0; first_gfx_v <= 1'b0; end
        else begin
            if (mrom_ack && !first_prog_v) begin first_prog <= mrom_q; first_prog_v <= 1'b1; end
            if (srom_ack && !first_snd_v)  begin first_snd  <= srom_q; first_snd_v  <= 1'b1; end
            if (tile_ack && !first_gfx_v)  begin first_gfx  <= tile_q[31:24]; first_gfx_v <= 1'b1; end
        end
    end

    logic        flt_rst;
    always_ff @(posedge clk_sys) flt_rst <= g_reset;
    wire         flt_hit;
    wire   [7:0] flt_vec, flt_n;
    wire  [23:0] flt_pc0, flt_pc1, flt_io;
    dbg_fault u_fault (
        .clk(clk_sys), .rst(flt_rst), .addr(g_dbg_addr), .bus(g_dbg_bus),
        .hit(flt_hit), .vec(flt_vec), .pc0(flt_pc0), .pc1(flt_pc1), .io(flt_io), .faults(flt_n)
    );

    wire [127:0] ovl_status = {
        
        8'b1010_1010, ovl_frames,
        pll_locked_sys, mem_ready, ioctl_download, allc_s,
        loaded, g_reset, g_halted, ovl_wdog,
        g_status,

        flt_vec, flt_pc0,
        
        first_prog, first_snd, first_gfx,
        
        sram_rd0, sram_rd1
    };

    wire [7:0] ovl_r, ovl_g, ovl_b;
    dbg_overlay #(.SQW(9)) ovl (
        .clk(clk_sys), .cen_pix(g_pix_ce), .enable(ovl_en), .de(g_de), .vsync(g_vs),
        .r_in(g_rgb[23:16]), .g_in(g_rgb[15:8]), .b_in(g_rgb[7:0]),
        .status(ovl_status), .r_out(ovl_r), .g_out(ovl_g), .b_out(ovl_b)
    );

    wire [7:0] vr_q, vg_q, vb_q;
    wire       vhs_q, vvs_q, vde_q;
    pocket_video_capture video_capture (
        .clk_sys(clk_sys), .clk_vid(clk_vid),
        .rgb({ovl_r, ovl_g, ovl_b}), .hs(g_hs), .vs(g_vs), .de(g_de),
        .rgb_q({vr_q, vg_q, vb_q}), .hs_q(vhs_q), .vs_q(vvs_q), .de_q(vde_q)
    );
    assign core_r  = vr_q;
    assign core_g  = vg_q;
    assign core_b  = vb_q;
    assign core_hs = vhs_q;
    assign core_vs = vvs_q;
    assign core_de = vde_q;

    localparam int SND_DIV = 2000;              
    logic [11:0] snd_div = 12'd0;
    logic signed [15:0] snd_hold_l = 16'sd0, snd_hold_r = 16'sd0;
    logic        snd_tog = 1'b0;
    always_ff @(posedge clk_sys) begin
        if (snd_div == 12'(SND_DIV - 1)) begin
            snd_div    <= 12'd0;
            snd_hold_l <= g_snd_l;
            snd_hold_r <= g_snd_r;
            snd_tog    <= ~snd_tog;
        end else begin
            snd_div <= snd_div + 12'd1;
        end
    end
    logic [2:0] snd_tog_s = 3'd0;
    logic signed [15:0] snd_xfer_l = 16'sd0, snd_xfer_r = 16'sd0;
    always_ff @(posedge clk_74b) begin
        snd_tog_s <= {snd_tog_s[1:0], snd_tog};
        if (snd_tog_s[2] != snd_tog_s[1]) begin
            snd_xfer_l <= snd_hold_l;
            snd_xfer_r <= snd_hold_r;
        end
    end
    assign core_snd_l = snd_xfer_l;
    assign core_snd_r = snd_xfer_r;

endmodule
