`timescale 1ns / 1ps

// Trace-only simulation top.
// EXP is a visible label for manual project-based simulation. The supplied
// Tcl runner selects the actual experiment image and golden trace.
module soc_top #(
    parameter integer EXP = 12
);

    // The reusable environment contains the functional-test memory model,
    // confreg model, watchdog, and golden-trace comparison logic.
    tb_top trace_env();

    initial begin
        $display("==============================================================");
        $display("Trace simulation top: EXP=%0d", EXP);
        $display("Wave hierarchy: /soc_top/trace_env");
        $display("==============================================================");
    end
endmodule
