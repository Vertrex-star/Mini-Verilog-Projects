module RX #(
    parameter int clkPerBit = 5208
) (
    input logic clk,
    input logic rst,
    input logic serial,
    output logic [7:0] out,
    output logic check
);

    localparam int CNT_WIDTH = $clog2(clkPerBit);

    typedef enum logic [1:0] {
        IDLE,
        RECEIVE,
        STOP,
        CLEAN
    } state_t;

    state_t select;

    logic [7:0] store;
    logic [CNT_WIDTH-1:0] clkCount;
    logic [2:0] bitIndex;
    logic serialBuffer;
    logic serialR;
    logic readOk;

    always_ff @(posedge clk) begin
        if (rst) begin
            serialBuffer <= 1'b1;
            serialR <= 1'b1;
        end else begin
            serialBuffer <= serial;
            serialR <= serialBuffer;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            select <= IDLE;
            clkCount <= '0;
            bitIndex <= '0;
            readOk <= 1'b0;
        end else begin
            case (select)

                IDLE: begin
                    readOk <= 1'b0;
                    if (serialR == 1'b1) begin
                        clkCount <= '0;
                        bitIndex <= '0;
                    end else begin
                        if (clkCount == (clkPerBit - 1) / 2) begin
                            select <= RECEIVE;
                            clkCount <= '0;
                        end else begin
                            clkCount <= clkCount + 1'b1;
                        end
                    end
                end

                RECEIVE: begin
                    if (clkCount < clkPerBit - 1) begin
                        clkCount <= clkCount + 1'b1;
                    end else begin
                        clkCount <= '0;
                        store[bitIndex] <= serialR;
                        if (bitIndex < 7) begin
                            bitIndex <= bitIndex + 1'b1;
                        end else begin
                            select <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clkCount < clkPerBit - 1) begin
                        clkCount <= clkCount + 1'b1;
                    end else begin
                        clkCount <= '0;
                        readOk <= 1'b1;
                        select <= CLEAN;
                    end
                end

                CLEAN: begin
                    select <= IDLE;
                    bitIndex <= '0;
                    clkCount <= '0;
                    readOk <= 1'b0;
                end

                default: select <= IDLE;

            endcase
        end
    end

    assign out = store;
    assign check = readOk;

endmodule
