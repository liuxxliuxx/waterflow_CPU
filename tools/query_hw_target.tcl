open_hw_manager
connect_hw_server
open_hw_target

set devices [get_hw_devices]
if {[llength $devices] == 0} {
    puts stderr "NO_HW_DEVICE"
    close_hw_manager
    exit 2
}

foreach device $devices {
    puts "HW_DEVICE=$device PART=[get_property PART $device] PROGRAMMED=[get_property PROGRAM.FILE $device]"
}

close_hw_manager
