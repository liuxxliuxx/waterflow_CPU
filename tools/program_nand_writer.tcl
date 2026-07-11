set bitfile {C:/Users/liuxx/Desktop/small_term/NAND_writer/bitstream/NAND_writer.bit}
if {![file exists $bitfile]} {
    puts stderr "BITSTREAM_NOT_FOUND=$bitfile"
    exit 2
}

open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices] 0]
if {$device eq ""} {
    puts stderr "NO_HW_DEVICE"
    close_hw_manager
    exit 2
}

current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device
puts "NAND_WRITER_PROGRAMMED=$device"

# The writer autonomously erases block 0 and programs the two payload pages.
after 5000
puts "NAND_WRITER_AUTOPROGRAM_WAIT_COMPLETE"
close_hw_manager
