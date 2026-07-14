`timescale 1ns / 1ps

module uart_tx_simple_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg send = 1'b0;
    reg [7:0] data = 8'ha5;
    wire tx;
    wire busy;
    integer errors = 0;

    always #20 clk = ~clk;

    uart_tx_simple #(
        .CLK_HZ(25000000),
        .BAUD(115200)
    ) u_dut(
        .clk(clk),
        .rst(rst),
        .send(send),
        .data(data),
        .tx(tx),
        .busy(busy)
    );

    task hold_one_bit;
        input expected;
        integer i;
        begin
            if (tx !== expected) begin
                $display("UART bit starts with %b, expected %b", tx, expected);
                errors = errors + 1;
            end
            for (i = 1; i < 217; i = i + 1) begin
                @(posedge clk);
                #1;
                if (tx !== expected) begin
                    $display("UART changed early at cycle %0d: %b expected %b", i, tx, expected);
                    errors = errors + 1;
                end
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        send = 1'b1;
        @(posedge clk);
        #1;
        send = 1'b0;

        if (!busy || (tx !== 1'b0)) begin
            $display("UART did not assert the start bit immediately");
            errors = errors + 1;
        end

        hold_one_bit(1'b0);
        hold_one_bit(1'b1);
        hold_one_bit(1'b0);
        hold_one_bit(1'b1);
        hold_one_bit(1'b0);
        hold_one_bit(1'b0);
        hold_one_bit(1'b1);
        hold_one_bit(1'b0);
        hold_one_bit(1'b1);
        hold_one_bit(1'b1);

        if (busy || (tx !== 1'b1)) begin
            $display("UART did not return to idle after one stop bit");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: uart_tx_simple_tb");
        else
            $display("FAIL: uart_tx_simple_tb errors=%0d", errors);
        $finish;
    end
endmodule
