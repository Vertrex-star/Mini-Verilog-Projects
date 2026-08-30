module async_fifo #(
    parameter int depth = 16,
    parameter int width = 8
) (
    input  logic             wr_clk,
    input  logic             wr_rst,
    input  logic             wr_en,
    input  logic [width-1:0] din,

    input  logic             rd_clk,
    input  logic             rd_rst,
    input  logic             rd_en,

    output logic             full,
    output logic             empty,
    output logic [width-1:0] dout
);

    localparam int ADDR_WIDTH = $clog2(depth);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    logic rd_en_int, wr_en_int;
    assign rd_en_int = rd_en && !empty;
    assign wr_en_int = wr_en && !full;

    logic [PTR_WIDTH-1:0] wr_ptr, wr_ptr_next;
    logic [PTR_WIDTH-1:0] gray_wr_ptr, gray_wr_ptr_next;

    logic [PTR_WIDTH-1:0] rd_ptr, rd_ptr_next;
    logic [PTR_WIDTH-1:0] gray_rd_ptr, gray_rd_ptr_next;

    logic [PTR_WIDTH-1:0] gray_wr_ptr1, gray_wr_ptr2;  
    logic [PTR_WIDTH-1:0] gray_rd_ptr1, gray_rd_ptr2;  

    logic [PTR_WIDTH-1:0] wr_ptr_rd_domain;
    logic [PTR_WIDTH-1:0] rd_ptr_wr_domain;

    logic [width-1:0] internal_d [0:depth-1];
    logic [width-1:0] l_dout;

    assign wr_ptr_next = wr_en_int ? wr_ptr + 1'b1 : wr_ptr;
    assign rd_ptr_next = rd_en_int ? rd_ptr + 1'b1 : rd_ptr;

    assign gray_wr_ptr_next = (wr_ptr_next >> 1) ^ wr_ptr_next;
    assign gray_rd_ptr_next = (rd_ptr_next >> 1) ^ rd_ptr_next;

    // Pointer registers
    always_ff @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_ptr      <= '0;
            gray_wr_ptr <= '0;
        end else begin
            wr_ptr <= wr_ptr_next;
            gray_wr_ptr <= gray_wr_ptr_next;
        end
    end

    always_ff @(posedge rd_clk) begin
        if (rd_rst) begin
            rd_ptr      <= '0;
            gray_rd_ptr <= '0;
        end else begin
            rd_ptr <= rd_ptr_next;
            gray_rd_ptr <= gray_rd_ptr_next;
        end
    end

    always_comb begin
        wr_ptr_rd_domain[PTR_WIDTH-1] = gray_wr_ptr2[PTR_WIDTH-1];
        for (int i = PTR_WIDTH-2; i >= 0; i--)
            wr_ptr_rd_domain[i] = wr_ptr_rd_domain[i+1] ^ gray_wr_ptr2[i];

        rd_ptr_wr_domain[PTR_WIDTH-1] = gray_rd_ptr2[PTR_WIDTH-1];
        for (int i = PTR_WIDTH-2; i >= 0; i--)
            rd_ptr_wr_domain[i] = rd_ptr_wr_domain[i+1] ^ gray_rd_ptr2[i];
    end

    // Memory
    always_ff @(posedge wr_clk) begin
        if (wr_en_int)
            internal_d[wr_ptr[ADDR_WIDTH-1:0]] <= din;
    end

    always_ff @(posedge rd_clk) begin
        if (rd_rst)
            l_dout <= '0;
        else if (rd_en_int)
            l_dout <= internal_d[rd_ptr[ADDR_WIDTH-1:0]];
    end

    assign dout = l_dout;
	
    // CDC synchronizers 
    always_ff @(posedge rd_clk) begin
        if (rd_rst) begin
            gray_wr_ptr1 <= '0;
            gray_wr_ptr2 <= '0;
        end else begin
            gray_wr_ptr1 <= gray_wr_ptr;
            gray_wr_ptr2 <= gray_wr_ptr1;
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_rst) begin
            gray_rd_ptr1 <= '0;
            gray_rd_ptr2 <= '0;
        end else begin
            gray_rd_ptr1 <= gray_rd_ptr;
            gray_rd_ptr2 <= gray_rd_ptr1;
        end
    end


    // Full / empty flags
    always_ff @(posedge rd_clk) begin
        if (rd_rst)
            empty <= 1'b1;
        else
            empty <= (rd_ptr_next == wr_ptr_rd_domain);
    end

    // Full
    always_ff @(posedge wr_clk) begin
        if (wr_rst)
            full <= 1'b0;
        else
            full <= (wr_ptr_next[ADDR_WIDTH-1:0] == rd_ptr_wr_domain[ADDR_WIDTH-1:0]) &&
                    (wr_ptr_next[ADDR_WIDTH] != rd_ptr_wr_domain[ADDR_WIDTH]);
    end

endmodule
