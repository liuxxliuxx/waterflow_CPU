`timescale 1ns / 1ps

module ps2_raw_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg ps2_clk = 1'b1;
    reg ps2_dat = 1'b1;
    reg rd_en = 1'b0;
    reg clear_errors = 1'b0;
    wire [7:0] rd_data;
    wire empty;
    wire full;
    wire overflow;
    wire frame_error;
    integer errors = 0;
    integer fill_index;

    always #20 clk = ~clk;

    ps2_keyboard u_dut(
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .rd_en(rd_en),
        .clear_errors(clear_errors),
        .rd_data(rd_data),
        .empty(empty),
        .full(full),
        .overflow(overflow),
        .frame_error(frame_error)
    );

    task send_bit;
        input value;
        begin
            ps2_dat = value;
            repeat (4) @(posedge clk);
            ps2_clk = 1'b0;
            repeat (4) @(posedge clk);
            ps2_clk = 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    task send_frame;
        input [7:0] value;
        input bad_parity;
        input bad_stop;
        integer i;
        reg parity;
        begin
            parity = ~^value;
            send_bit(1'b0);
            for (i = 0; i < 8; i = i + 1)
                send_bit(value[i]);
            send_bit(bad_parity ? ~parity : parity);
            send_bit(bad_stop ? 1'b0 : 1'b1);
            ps2_dat = 1'b1;
            repeat (6) @(posedge clk);
        end
    endtask

    task expect_and_pop;
        input [7:0] expected;
        begin
            if (empty || (rd_data !== expected)) begin
                $display("PS2 FIFO mismatch: empty=%b data=%02x expected=%02x", empty, rd_data, expected);
                errors = errors + 1;
            end
            @(negedge clk);
            rd_en = 1'b1;
            @(negedge clk);
            rd_en = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        repeat (6) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_frame(8'he0, 1'b0, 1'b0);
        send_frame(8'hf0, 1'b0, 1'b0);
        send_frame(8'h1c, 1'b0, 1'b0);
        expect_and_pop(8'he0);
        expect_and_pop(8'hf0);
        expect_and_pop(8'h1c);

        send_frame(8'h55, 1'b1, 1'b0);
        if (!empty || !frame_error) begin
            $display("Bad-parity frame was not dropped or reported");
            errors = errors + 1;
        end

        @(negedge clk);
        clear_errors = 1'b1;
        @(negedge clk);
        clear_errors = 1'b0;
        repeat (2) @(posedge clk);
        if (frame_error || overflow) begin
            $display("Sticky PS2 errors did not clear");
            errors = errors + 1;
        end

        send_bit(1'b1);
        ps2_dat = 1'b1;
        repeat (4) @(posedge clk);
        if (!empty || !frame_error) begin
            $display("Bad-start frame was not dropped or reported");
            errors = errors + 1;
        end

        @(negedge clk);
        clear_errors = 1'b1;
        @(negedge clk);
        clear_errors = 1'b0;
        repeat (2) @(posedge clk);

        send_frame(8'haa, 1'b0, 1'b1);
        if (!empty || !frame_error) begin
            $display("Bad-stop frame was not dropped or reported");
            errors = errors + 1;
        end

        @(negedge clk);
        clear_errors = 1'b1;
        @(negedge clk);
        clear_errors = 1'b0;
        repeat (2) @(posedge clk);

        for (fill_index = 0; fill_index < 33; fill_index = fill_index + 1)
            send_frame(fill_index[7:0], 1'b0, 1'b0);
        if (!full || !overflow) begin
            $display("PS2 FIFO full/overflow status was not reported");
            errors = errors + 1;
        end

        @(negedge clk);
        clear_errors = 1'b1;
        @(negedge clk);
        clear_errors = 1'b0;
        repeat (2) @(posedge clk);
        if (overflow) begin
            $display("PS2 overflow flag did not clear");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: ps2_raw_tb");
        else
            $display("FAIL: ps2_raw_tb errors=%0d", errors);
        $finish;
    end
endmodule
