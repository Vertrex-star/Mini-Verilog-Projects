// Run Case
module testing(i_bit1, i_bit2, i_cin, o_out, o_cout);
	input i_bit1, i_bit2, i_cin;
	output o_out, o_cout;

	wire w_in1;
	wire w_in2;
	wire w_cin;
		
	assign w_in1 = (i_bit1 ^ i_bit2); 
	assign w_in2 = w_in1 & i_cin;
	assign w_cin = i_bit1 & i_bit2;

	assign o_out = (w_in1 ^ i_cin);
	assign o_cout = (w_in2 | w_cin);
		
endmodule 

module ripple_adder_4bit(
	input[3:0] a,
	input[3:0] b,
	input cin,
	output cout,
	output[3:0] sum
);

wire c0, c1, c2;

testing FA0(
	.i_bit1(a[0]), .i_bit2(b[0]), .i_cin(cin),
	.o_out(sum[0]), .o_cout(c0)
	);
	
testing FA1(
	.i_bit1(a[1]), .i_bit2(b[1]), .i_cin(c0),
	.o_out(sum[1]), .o_cout(c1)
	);
	
testing FA2(
	.i_bit1(a[2]), .i_bit2(b[2]), .i_cin(c1),
	.o_out(sum[2]), .o_cout(c2)
	);
	
testing FA3(
	.i_bit1(a[3]), .i_bit2(b[3]), .i_cin(c2),
	.o_out(sum[3]), .o_cout(cout)
	);
	
endmodule

// Test Case

module test_bench;
	reg[3:0] A, B;
	reg C;
	
	wire[3:0] G;
	wire D;
	
	ripple_adder_4bit UUT(
		.a(A), .b(B), .cin(C), 
		.cout(D), .sum(G)
	);
	
	initial 
		begin
			{A, B, C} = 9'b0000_0000_0; #10;  // 1
			{A, B, C} = 9'b0000_0000_1; #10;  // 2
			{A, B, C} = 9'b0001_0000_0; #10;  // 3
			{A, B, C} = 9'b0001_0001_0; #10;  // 4
			{A, B, C} = 9'b1111_0001_0; #10;  // 5
			{A, B, C} = 9'b1111_1111_0; #10;  // 6
			{A, B, C} = 9'b1111_1111_1; #10;  // 7
			{A, B, C} = 9'b1000_1000_0; #10;  // 8
			{A, B, C} = 9'b0101_1010_0; #10;  // 9
			{A, B, C} = 9'b0111_0001_0; #10 // 10
		
		end 

endmodule 
