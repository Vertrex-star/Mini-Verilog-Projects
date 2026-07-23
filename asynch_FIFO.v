module fifo_regs#(parameter g_WIDTH = 4, parameter g_DEPTH = 4) (
	input i_clk,
	input rst,

	input wr_en,
	input rd_en,

	input [g_WIDTH-1:0] din,
	output [g_WIDTH-1:0] dout,

	output full,
	output empty
);

wire wr_en_real = wr_en & !full;
wire rd_en_real = rd_en & !empty;

reg [$clog2(g_DEPTH+1)-1:0] count;
reg [g_WIDTH-1:0] internal_d [0:g_DEPTH-1];
reg [$clog2(g_DEPTH)-1:0] wr_ptr;
reg [$clog2(g_DEPTH)-1:0] rd_ptr;

always @(posedge i_clk) begin
	if (rst) begin
		count  <= 0;
		wr_ptr <= 0;
		rd_ptr <= 0;
	end else begin
		if (wr_en_real && !rd_en_real)
			count <= count + 1;
		else if (!wr_en_real && rd_en_real)
			count <= count - 1;

		if (wr_en_real) begin
			internal_d[wr_ptr] <= din;
			wr_ptr <= (wr_ptr == g_DEPTH-1) ? 0 : wr_ptr + 1;
		end

		if (rd_en_real) begin
			rd_ptr <= (rd_ptr == g_DEPTH-1) ? 0 : rd_ptr + 1;
		end
	end
end

assign dout  = internal_d[rd_ptr];
assign full  = (count == g_DEPTH);
assign empty = (count == 0);

endmodule
