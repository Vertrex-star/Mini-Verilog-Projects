module ADC (
	input logic clk,
	input logic rst_n,
	input logic [3:0] signal,

	output logic en,
	output logic [3:0] out
);

localparam int BIT_TREE_SIZE = 64;

logic [BIT_TREE_SIZE-1:0] tree;

logic [5:0] n;
logic [1:0] step;
logic temp_en;
logic [3:0] temp_out;
logic [3:0] cur_signal;
logic [3:0] node_val;

always_comb begin
tree = '0;
tree[4*0 +: 4] = 4'b1000;
tree[4*1 +: 4] = 4'b1100;
tree[4*2 +: 4] = 4'b0100;
tree[4*3 +: 4] = 4'b1110;
tree[4*4 +: 4] = 4'b1010;
tree[4*5 +: 4] = 4'b0110;
tree[4*6 +: 4] = 4'b0010;
tree[4*7 +: 4] = 4'b1111;
tree[4*8 +: 4] = 4'b1101;
tree[4*9 +: 4] = 4'b1011;
tree[4*10 +: 4] = 4'b1001;
tree[4*11 +: 4] = 4'b0111;
tree[4*12 +: 4] = 4'b0101;
tree[4*13 +: 4] = 4'b0011;
tree[4*14 +: 4] = 4'b0001;
end

function automatic int left(input int n);
	left = (n * 2) + 1;
endfunction

function automatic int right(input int n);
	right = (n * 2) + 2;
endfunction

assign cur_signal = (step == 0) ? signal : temp_signal;
assign node_val = tree[4*n +: 4];

always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			n <= 6'd0;
			step <= 2'd0;
			temp_out <= 4'd0;
			temp_en <= 1'b0;
		end else begin
			temp_en <= 1'b0;
		end

		if (cur_signal >= node_val) begin
			n <= left(n);
		end else begin
			n <= right(n);
		end
		
		if (step == 2'd3) begin
			temp_en <= 1'b1;
			n <= 6'd0;
			step <= 2'd0;
		end else begin
			step <= step + 2'd1;
		end
		
		temp_out <= node_val;
	end
end

assign en = temp_en;
assign out = temp_out;

endmodule
