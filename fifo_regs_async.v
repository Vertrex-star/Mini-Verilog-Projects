module fifo_regs_async #(
	parameter g_WIDTH,
	parameter g_DEPTH
)(
	input wr_clk,
	input wr_rst,
	input wr_en,
	input [g_WIDTH-1:0] din,
	output full,
	
	input rd_clk,
	input rd_rst,
	input rd_en,
	output [g_WIDTH-1:0] dout,
	output full,
);

localparam PTR_WIDTH = $clog2(g_DEPTH) + 1;

reg [PTR_WIDTH-1:0] wr_ptr_bin, wr_ptr_gray;
reg [PTR_WIDTH-1:0] rd_ptr_bin, rd_ptr_gray;

reg [PTR_WIDTH-1:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
reg [PTR_WIDTH-1:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;

wire wr_en_real = wr_en & !full;
wire rd_en_real = rd_en & !empty;

wire [PTR_WIDTH-1:0] wr_ptr_bin_next = wr_ptr_bin + (wr_en_real ? 1'b1 : 1'b0);
wire [PTR_WIDTH-1:0] wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

wire [PTR_WIDTH-1:0] rd_ptr_bin_next = rd_ptr_bin + (rd_en_real ? 1'b1 : 1'b0);
wire [PTR_WIDTH-1:0] rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;

always @(posedge wr_clk) begin 
	if (wr_rst) begin 
		wr_ptr_bin <= 0;
		wr_ptr_gray <= 0;
	end else if (wr_en_real) begin 
		internal_d[wr_ptr_bin[PTR_WIDTH-2:0]] <= din;
		wr_ptr_bin <= wr_ptr_bin_next;
		wr_ptr_gray <= wr_ptr_gray_next;
	end

always @(posedge rd_clk) begin 
	if(rd_rst) begin 
		rd_ptr_bin <= 0;
		rd_ptr_gray <= 0;
	end 
	else if (rd_en_real) begin 
		rd_ptr_bin <= rd_ptr_bin_next;
		rd_ptr_gray <= rd_ptr_gray_next;
	end
 end 
 
 always @(posedge rd_clk) begin 
	if (rd_rst) begin 
		dout <= {g_WIDTH{1'b0}};
	end
	else if (rd_en_real) begin 
		dout <= internal_d[rd_ptr_bin[PTR_WIDTH-2:0]];
	end
 end
 
 always @(posedge wr_clk) begin 
	if(wr_rst) begin
		rd_ptr_gray_sync1 <= 0;
		rd_ptr_gray_sync2 <= 0;
	end 
	else begin 
		rd_ptr_gray_sync1 <= rd_ptr_gray;
		rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
	end
end

always @(posedge rd_clk) begin 
	if(rd_rst) begin
		wr_ptr_gray_sync1 <= 0;
		wr_ptr_gray_sync2 <= 0;
	end 
	else begin 
		wr_ptr_gray_sync1 <= wr_ptr_gray;
		wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
	end
end

	always @(posedge wr_clk) begin 
		if(wr_rst) 
			full <= 1'b0;
		else
			full <= (wr_ptr_gray_next == {~rd_ptr_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2], rd_ptr_gray_sync2[PTR_WIDTH-3:0]]}))
	end

	
	 always @(posedge rd_clk) begin
        if (rd_rst)
            empty <= 1'b1;
        else
            empty <= (rd_ptr_gray_next == wr_ptr_gray_sync2);
    end
 
endmodule 
