onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Global Signals}
add wave -noupdate -group {Clock & Reset} /scr1_top_tb_axi/clk
add wave -noupdate -group {Clock & Reset} /scr1_top_tb_axi/rst_n
add wave -noupdate -group {Program Counter} -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/curr_pc
add wave -noupdate -divider {STEP 1: Memory Read (AXI Bus)}
add wave -noupdate -expand -group {AXI Read Channel} -radix hexadecimal /scr1_top_tb_axi/i_top/io_axi_imem_rdata
add wave -noupdate -expand -group {AXI Read Channel} /scr1_top_tb_axi/i_top/io_axi_imem_rvalid
add wave -noupdate -expand -group {AXI Read Channel} /scr1_top_tb_axi/i_top/io_axi_imem_rready
add wave -noupdate -divider {STEP 2: IFU Input}
add wave -noupdate -expand -group {IFU Memory Input} -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_ifu/imem2ifu_rdata_i
add wave -noupdate -expand -group {IFU Memory Input} /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_ifu/imem2ifu_resp_i
add wave -noupdate -divider {STEP 3: IFU Output -> Translator Input}
add wave -noupdate -expand -group {IFU->Translator Link} -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/ifu2idu_instr
add wave -noupdate -expand -group {IFU->Translator Link} /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/ifu2idu_vd
add wave -noupdate -expand -group {IFU->Translator Link} /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/idu2ifu_rdy
add wave -noupdate -divider {STEP 4: Translator Output -> IDU Input}
add wave -noupdate -expand -group {Translator->IDU Link} -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/translator2idu_instr
add wave -noupdate -expand -group {Translator->IDU Link} /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/translator2idu_vd
add wave -noupdate -expand -group {Translator->IDU Link} /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/exu2idu_rdy
add wave -noupdate -divider {STEP 5: Decode & Exception}
add wave -noupdate -expand -group Exception /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_exu/exu2csr_take_exc_o
add wave -noupdate -expand -group Exception -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_exu/exu2csr_exc_code_o
add wave -noupdate -expand -group Exception -radix hexadecimal /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_exu/exu2csr_trap_val_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {125 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 497
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {112 ns} {176 ns}
