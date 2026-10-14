# ==============================================================================
# Asterix on the Pocket: timing constraints beyond the BSP's
# sys_constr.sdc. The 96 MHz system clock, its 6 MHz video pair and the
# shifted SDRAM clock all come from core_pll and are timed as one related
# group; the two 74.25 MHz inputs and the audio PLL are asynchronous to it.
# The PLL's fifth output drives nothing in core_top, so no clock of its own
# reaches the netlist and it is not named here -- naming it only bought an
# ignored-filter warning that hid the ones that mattered.
# ==============================================================================
# Replace the BSP groups: another set_clock_groups does not cancel the BSP's
# false paths between outputs of this same PLL. Those clocks are related.
remove_clock_groups -all
# Define the external SDRAM clock before assigning related clocks to groups.
create_generated_clock -name dram_clk -source \
    [get_pins {ic|core_pll|core_pll_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    [get_ports {dram_clk}]
set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { ic|core_pll|core_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|core_pll|core_pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|core_pll|core_pll_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|core_pll|core_pll_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk \
          dram_clk } \
 -group { ic|pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk }

# These specific JT51 source and destination registers all update only on
# cen_p1 (cen2 in asterix_core, at least 48 system edges apart, also across
# pause/resume). Allow only 2 edges, conservatively, with the corresponding
# hold adjustment. The ungated MMR channel arrays reg_* and reset paths are
# deliberately absent. See docs/QUARTUS_REVIEW.md for the source audit.
set FM_PHASE_SOURCES [get_registers { *|*u_csr_ch|pms* *|*u_csr_ch|kc* *|*u_csr_ch|kf* *|*u_lfo|pm* }]
set FM_PHASE_TARGETS [get_registers { *|*u_pg|keycode_II* }]
if {[get_collection_size $FM_PHASE_SOURCES] == 0 || [get_collection_size $FM_PHASE_TARGETS] == 0} {
    error "JT51 phase multicycle endpoints did not match"
}
set_multicycle_path -setup 2 -from $FM_PHASE_SOURCES -to $FM_PHASE_TARGETS
set_multicycle_path -hold  1 -from $FM_PHASE_SOURCES -to $FM_PHASE_TARGETS

# These eleven original T80 launch groups and 27 named capture groups update
# only on guarded CPU enables or a subset. The local wait adapter guarantees
# at least two system edges between all CPU enables, including recovery.
# DIRSet is tied to zero in T80s. See the independently recorded feedback
# chains in docs/QUARTUS_REVIEW.md; physical register retiming is disabled.
# NMI_S n2109, other CPU registers and reset remain single-cycle.
set Z80_DECODE_SOURCES [get_registers {
    *|*u0|n2098_q* *|*u0|n2103_q* *|*u0|n2080_q* *|*u0|n2132_q*
    *|*u0|n2131_q* *|*u0|n2099_q* *|*u0|n2111_q* *|*u0|n2102_q*
    *|*u0|n2091_q* *|*u0|n2093_q* *|*u0|n2095_q*
}]
set Z80_GATED_TARGETS [get_registers {
    *|*u_regs|n7902_q* *|*u_regs|n7903_q*
    *|*u0|n2079_q* *|*u0|n2080_q* *|*u0|n2085_q* *|*u0|n2086_q*
    *|*u0|n2097_q* *|*u0|n2102_q* *|*u0|n2103_q* *|*u0|n2104_q*
    *|*u0|n2105_q* *|*u0|n2106_q* *|*u0|n2112_q* *|*u0|n2115_q*
    *|*u0|n2116_q* *|*u0|n2119_q* *|*u0|n2121_q* *|*u0|n2123_q*
    *|*u0|n2124_q* *|*u0|n2127_q* *|*u0|n2128_q* *|*u0|n2131_q*
    *|*u0|n2132_q* *|*u0|n2134_q* *|*u0|n2137_q*
    *|*u0|n2101_q* *|*u0|n2117_q*
}]
if {[get_collection_size $Z80_DECODE_SOURCES] == 0 || [get_collection_size $Z80_GATED_TARGETS] == 0} {
    error "Audited T80 gated multicycle endpoints did not match"
}
set_multicycle_path -setup 2 -from $Z80_DECODE_SOURCES -to $Z80_GATED_TARGETS
set_multicycle_path -hold  1 -from $Z80_DECODE_SOURCES -to $Z80_GATED_TARGETS

# FX68K Ir and nanoAddr both update on enT1, at T4/Phi1 with !wClk.
# Normal captures are at least four edges apart. Power-up can return the
# state machine through T0 and shorten this to two edges; its nanoAddr write
# is a constant. Therefore use only setup2/hold1 on this exact pair. This
# does not assume spacing of other 68000 enables or cover Irc/Ird/reset.
# Native Quartus vector filters include same-stage duplication aliases; the
# explicit name checks reject any accidentally selected pipeline stage.
set FX_IR_SOURCE [get_registers {*|Ir[*]*}]
set FX_NANO_TARGET [get_registers {*|nanoAddr[*]*}]
if {[get_collection_size $FX_IR_SOURCE] == 0 || [get_collection_size $FX_NANO_TARGET] == 0} {
    error "Audited FX68K Ir/nanoAddr endpoints did not match"
}
foreach_in_collection node $FX_IR_SOURCE {
    if {![regexp {\|Ir\[[0-9]+\](~.*)?$} [get_node_info -name $node]]} {
        error "Non-Ir stage selected by FX68K source filter"
    }
}
foreach_in_collection node $FX_NANO_TARGET {
    if {![regexp {\|nanoAddr\[[0-9]+\](~.*)?$} [get_node_info -name $node]]} {
        error "Non-nanoAddr stage selected by FX68K target filter"
    }
}
set_multicycle_path -setup 2 -from $FX_IR_SOURCE -to $FX_NANO_TARGET
set_multicycle_path -hold  1 -from $FX_IR_SOURCE -to $FX_NANO_TARGET

# SDRAM: the chip is clocked by the phase-shifted PLL output (core_pll's
# outclk_3).  The shift divides the budget between two checks that pull
# opposite ways: the data the chip returns is captured by an I/O-cell register
# on the core clock, and the address and command the core drives are captured
# by the chip.  On the captured data, setup gets 2T - shift and hold gets
# T - shift, so a nanosecond off the shift is a nanosecond onto setup and a
# nanosecond off hold.
#
# THE SHIFT IS PER-DESIGN.  5.859 ns is where Master of Weapon's fit balanced
# (setup slack = 6.241 - shift at slow 85C, hold slack = shift - 5.519 at fast
# 0C); the board is the same for every core but the fit is not.  If the worst
# path in a build is dram_dq[*] -> sdram_ctrl|dq_in[*], measure both slacks at
# two shift values, solve for where they meet, and round to a multiple of
# 130.2 ps, the step the 960 MHz VCO can make.  projects/report_worst.tcl
# writes the reports to read: worst_paths*.txt for setup, worst_hold_fast.txt
# for hold.  METHODOLOGY.md section 5.20.
set_input_delay -max -clock dram_clk 7.0 [get_ports {dram_dq[*]}]
set_input_delay -min -clock dram_clk 2.5 [get_ports {dram_dq[*]}]
set SDRAM_OUT [get_ports {dram_a[*] dram_ba[*] dram_cke dram_dqm[*] dram_dq[*] dram_ras_n dram_cas_n dram_we_n}]
set_output_delay -max -clock dram_clk  1.5 $SDRAM_OUT
set_output_delay -min -clock dram_clk -0.8 $SDRAM_OUT
set_multicycle_path -setup 2 -from [get_clocks {dram_clk}] -to [get_registers {*|sdram_ctrl:*|dq_in[*]}]
set_multicycle_path -setup 3 -from [get_registers {*|sdram_ctrl:*|last[*]}] -to [get_registers {*|sdram_ctrl:*|*}]
set_multicycle_path -hold  2 -from [get_registers {*|sdram_ctrl:*|last[*]}] -to [get_registers {*|sdram_ctrl:*|*}]

# SRAM: registered pins held for whole system cycles, a read sampled several
# cycles after the address (target/pocket/sram_port.sv), so the pins are not
# timed against a clock.
set_false_path -to   [get_ports {sram_*}]
set_false_path -from [get_ports {sram_dq[*]}]

# The PSRAMs are unused on this board; the BSP still brings their pins out.
set_false_path -to   [get_ports {cram0_* cram1_*}]
set_false_path -from [get_ports {cram0_dq[*] cram1_dq[*] cram0_wait cram1_wait}]

