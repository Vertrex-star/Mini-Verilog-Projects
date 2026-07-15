module test (
		input[7:0] i_D, input i_En,
		output reg[3:0] o_S
);


	always@(*) begin 
		if(i_En == 0) 
			o_S = 4'b0000;
		else begin
			casex(i_D)
				8'b1xxxxxxx: o_S = {3'h7, 1'b1};
				8'b01xxxxxx: o_S = {3'h6, 1'b1};
				8'b001xxxxx: o_S = {3'h5, 1'b1};
				8'b0001xxxx: o_S = {3'h4, 1'b1};
				8'b00001xxx: o_S = {3'h3, 1'b1};
				8'b000001xx: o_S = {3'h2, 1'b1};
				8'b0000001x: o_S = {3'h1, 1'b1};
				8'b00000001: o_S = {3'h0, 1'b1};
				default: 	 o_S = 4'b0000;
			endcase
		end
	end
endmodule 

// Test bench 

module test_bench;
		reg [7:0]  i_D;
		reg 		  i_En;
		wire [3:0] o_S;
		reg[3:0] expected; 
		integer i;
		integer errors = 0;
		
test UUT (
	.i_D(i_D),
	.i_En(i_En),
	.o_S(o_S)
);


function[3:0] expected_output(input [7:0] d, input en);
	integer j;
	begin 
		expected_output = 4'b000;
		if (en) begin
			for (j = 7; j >= 0; j = j - 1) begin
				if(d[j]) begin 
					expected_output = {j[2:0], 1'b1};
					j = -1;
				end 
			end
		end
	end
endfunction 

initial begin 
	i_En = 1;
	
	for(i = 0; i < 256; i = i + 1) begin 
		i_D = i;
		#10;
		expected = expected_output(i_D, i_En);
		
		if (o_S !== Expected) begin
			$display("ERROR: i_D: %b i_En: %b -> o_S = %b, expected = %b", i_D, i_En, o_S, expected);
			errors = errors + 1;	
		end 
	end
	
	i_En = 0;
	i_D = 8'b1110011;
	#10;
	
	if(o_S !== 4'b0000) begin 
		$display("ERROR: i_D: %b i_En: %B", i_D, i_En);
		errors = errors + 1;
	end 
	
	if(errors = 0)  
		$display("No Errors");
	else
		$display("Errors: %b", errors);
	$stop;
end		
endmodule 
