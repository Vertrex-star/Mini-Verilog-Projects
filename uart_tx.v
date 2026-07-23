module uart_tx #(parameter clkCyclesPerBit = 87) (
    input clk,
    input activateTx,
    input [7:0] inputStream,

    output txIsActive,
    output reg serialOut,
    output txDone
);

parameter idle  = 2'b00;
parameter start = 2'b01;
parameter data  = 2'b10;
parameter stop  = 2'b11;

reg [1:0] switch = idle;
reg [7:0] clockCount = 0;
reg [2:0] bitIndex = 0;
reg [7:0] tempInput = 0;
reg done = 0;
reg active = 0;

always @(posedge clk) begin
    case (switch)

        idle: begin
            serialOut  <= 1'b1;
            done       <= 1'b0;
            clockCount <= 0;
            bitIndex   <= 0;

            if (activateTx == 1'b1) begin
                active    <= 1'b1;
                tempInput <= inputStream;
                switch    <= start;
            end
        end

        start: begin
            serialOut <= 1'b0;

            if (clockCount < clkCyclesPerBit - 1) begin
                clockCount <= clockCount + 1;
                switch     <= start;
            end
            else begin
                clockCount <= 0;
                switch     <= data;
            end
        end

        data: begin
            serialOut <= tempInput[bitIndex];

            if (clockCount < clkCyclesPerBit - 1) begin
                clockCount <= clockCount + 1;
                switch     <= data;
            end
            else begin
                clockCount <= 0;

                if (bitIndex < 7) begin
                    bitIndex <= bitIndex + 1;
                    switch   <= data;
                end
                else begin
                    bitIndex <= 0;
                    switch   <= stop;
                end
            end
        end

        stop: begin
            serialOut <= 1'b1;

            if (clockCount < clkCyclesPerBit - 1) begin
                clockCount <= clockCount + 1;
                switch     <= stop;
            end
            else begin
                clockCount <= 0;
                done       <= 1'b1;
                active     <= 1'b0;
                switch     <= idle;
            end
        end

        default:
            switch <= idle;

    endcase
end

assign txIsActive = active;
assign txDone     = done;

endmodule
