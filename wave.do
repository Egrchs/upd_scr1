onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Clocks & Reset}
add wave -noupdate /scr1_top_tb_axi/clk
add wave -noupdate /scr1_top_tb_axi/rst_n
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/pipe_rst_n
add wave -noupdate -divider {Program Counter}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/curr_pc
add wave -noupdate -divider {IFU -> Translator}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/ifu2idu_vd
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/ifu2idu_instr
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/idu2ifu_rdy
add wave -noupdate -divider {Translator Internals}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/current_state
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/next_state
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/saved_instruction
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/needs_split
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/unsupported_instruction
add wave -noupdate -divider {Translator -> IDU}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/translator2idu_vd
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/translator2idu_instr
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/translator2idu_imem_err
add wave -noupdate -divider {IDU -> EXU}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/idu2exu_req
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/idu2exu_cmd
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/exu2idu_rdy
add wave -noupdate -divider {EXU -> Data Memory}
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/pipe2dmem_req_o
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/pipe2dmem_cmd_o
add wave -noupdate /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/pipe2dmem_addr_o
add wave -noupdate -divider {AXI Interface (Data)}
add wave -noupdate /scr1_top_tb_axi/io_axi_dmem_arvalid
add wave -noupdate /scr1_top_tb_axi/io_axi_dmem_arready
add wave -noupdate /scr1_top_tb_axi/io_axi_dmem_araddr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 40
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
WaveRestoreZoom {0 ns} {1366 ns}
