module bus_controller(
    input         clk,
    input         rst,
    
    input         bus_req,
    input         bus_we,
    input  [31:0] bus_addr,
    input  [31:0] bus_wdata,
    output        bus_ready,
    output [31:0] bus_rdata,
    
    input  [31:0] lcd_input,
    output        lcd_wr_en,
    output [31:0] lcd_wr_data
    );
    localparam [31:0] lcd_addr = 32'h7f000000;
    
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] ACCESS = 2'd1;
    localparam [1:0] CAPTURE   = 2'd2;
    localparam [1:0] DONE   = 2'd3;
    
    reg[1:0]  state;
    reg       req_we;
    reg[31:0] req_addr;
    reg[31:0] req_wdata;
    reg[31:0] rdata;
    
    wire       sel_lcd   = (req_addr == lcd_addr);
    wire       sel_ram   = (req_addr != lcd_addr);
    wire[15:0] word_addr = req_addr[17:2];
    wire[31:0] ram_rdata;
    wire[31:0] lcd_rdata;
    wire       ram_wen;
    
    assign ram_wen     = sel_ram&&req_we&&(state == ACCESS);
    assign bus_rdata   = rdata;
    assign bus_ready   = (state == DONE);
    assign lcd_rdata   = lcd_input;
    assign lcd_wr_en   = sel_lcd && req_we && (state == ACCESS);
    assign lcd_wr_data = req_wdata;
    
    ram u_ram(
        .clk      (clk),
        .ram_addr (word_addr),
        .ram_wdata(req_wdata),
        .ram_wen  (ram_wen),
        .ram_data (ram_rdata)
    );
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            state     <= IDLE;
            req_we    <= 1'b0;
            req_addr  <= 32'b0;
            req_wdata <= 32'b0;
            rdata     <= 32'b0;
        end
        else begin
            case(state)
                IDLE: begin
                    if(bus_req) begin
                        req_we    <= bus_we;
                        req_addr  <= bus_addr;
                        req_wdata <= bus_wdata;
                        state <= ACCESS;
                    end
                end
                ACCESS: begin
                    state <= req_we ? DONE : CAPTURE;
                end
                CAPTURE: begin
                    rdata <= sel_lcd ? lcd_rdata : ram_rdata;
                    state <= DONE;
                end
                DONE: begin
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    
    
    
endmodule
