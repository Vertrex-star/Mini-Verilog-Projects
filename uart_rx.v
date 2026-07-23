module uart_rx #(parameter clkPerBit) (
    input serial,
    input clk,

    output [7:0] out,
    output check
);

parameter idle        = 2'b00;
parameter receiveBits = 2'b01;
parameter stopBits    = 2'b10;
parameter cleanup     = 2'b11;

reg [1:0] switch = 2'b00;
reg [7:0] store;
reg serialBuffer;
reg serialR = 1'b1;
reg readOk = 0;
reg [7:0] clkCount = 0;
reg [2:0] bitIndex = 0;

always @(posedge clk) begin // need to double store in a register due to metastability as this is a bit that has a lot depending on it
    serialBuffer <= serial;
    serialR      <= serialBuffer;
end

always @(posedge clk) begin
    case (switch)
        idle: begin
            if (serialR == 1'b1) begin
                clkCount <= 0;
                bitIndex <= 0;
                readOk   <= 0;
            end
            else begin
                if (clkCount == ((clkPerBit - 1) / 2)) begin
                    switch   <= receiveBits;
                    clkCount <= 0;
                end
                else begin
                    clkCount <= clkCount + 1;
                    switch   <= idle;
                end
            end
        end

        receiveBits: begin
            if (clkCount < (clkPerBit - 1)) begin
                clkCount <= clkCount + 1;
                switch   <= receiveBits;
            end
            else begin
                clkCount        <= 0;
                store[bitIndex]  <= serialR;
                if (bitIndex < 7) begin
                    bitIndex <= bitIndex + 1;
                    switch   <= receiveBits;
                end
                else begin
                    switch <= stopBits;
                end
            end
        end

        stopBits: begin
            if (clkCount < (clkPerBit - 1)) begin
                clkCount <= clkCount + 1;
                switch   <= stopBits;
            end
            else begin
                clkCount <= 0;
                readOk   <= 1'b1;
                switch   <= cleanup;
            end
        end

        cleanup: begin
            switch <= idle;
            readOk <= 1'b0;
        end

        default:
            switch <= idle;

    endcase
end

assign out   = store;
assign check = readOk;

endmodule
