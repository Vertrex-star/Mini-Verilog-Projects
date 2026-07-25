module float_product (
	input        sA,
	input        sB,
	input [7:0]  eA,
	input [7:0]  eB,
	input [22:0] mA,
	input [22:0] mB,

	output [31:0] float
);

	// sign 
	wire sC;

	// sum exponents 
	wire [8:0] exp_add;
	assign exp_add = eA + eB;

	// remove double bias
	wire signed [9:0] exp_adjust;
	assign exp_adjust = $signed({1'b0, exp_add}) - 10'sd127;

	// multiply magnitudes 
	wire [23:0] A_full, B_full;
	assign A_full = {1'b1, mA};   // restore implicit leading 1
	assign B_full = {1'b1, mB};

	wire [47:0] product;
	assign product = A_full * B_full;

	// normalize (1st)
	wire shift1;
	wire [46:0] norm1_mantissa;
	assign shift1        = product[47];
	assign norm1_mantissa = shift1 ? product[47:1] : product[46:0];

	// round (round-to-nearest-even)
	wire [22:0] mant_candidate;
	wire guard, round_bit, sticky, round_up;
	assign mant_candidate = norm1_mantissa[46:24];
	assign guard          = norm1_mantissa[23];
	assign round_bit      = norm1_mantissa[22];
	assign sticky         = |norm1_mantissa[21:0];
	assign round_up       = guard & (round_bit | sticky | mant_candidate[0]);

	wire [23:0] mant_rounded;
	assign mant_rounded = mant_candidate + round_up;

	// normalize (2nd, catches rounding overflow)
	wire shift2;
	wire [22:0] final_mantissa;
	assign shift2        = mant_rounded[23];
	assign final_mantissa = shift2 ? mant_rounded[23:1] : mant_rounded[22:0];

	// adjust exponent for both shifts, clamp to 8 bits 
	wire signed [9:0] exp_final_wide;
	assign exp_final_wide = exp_adjust + $signed({9'b0, shift1}) + $signed({9'b0, shift2});

	wire exp_overflow, exp_underflow;
	assign exp_overflow  = (exp_final_wide >= 10'sd255);
	assign exp_underflow = (exp_final_wide <= 10'sd0);

	wire [7:0] final_exponent;
	assign final_exponent = exp_overflow  ? 8'd255 :
	                         exp_underflow ? 8'd0   :
	                         exp_final_wide[7:0];

	// special value detection 
	wire is_zeroA     = (eA == 8'd0)   && (mA == 23'd0);
	wire is_zeroB     = (eB == 8'd0)   && (mB == 23'd0);
	wire is_denormalA = (eA == 8'd0)   && (mA != 23'd0);
	wire is_denormalB = (eB == 8'd0)   && (mB != 23'd0);
	wire is_infA      = (eA == 8'd255) && (mA == 23'd0);
	wire is_infB      = (eB == 8'd255) && (mB == 23'd0);
	wire is_nanA      = (eA == 8'd255) && (mA != 23'd0);
	wire is_nanB      = (eB == 8'd255) && (mB != 23'd0);

	wire is_nan_result  = is_nanA || is_nanB || (is_zeroA && is_infB) || (is_zeroB && is_infA);
	wire is_inf_result  = (is_infA || is_infB) && !is_nan_result;
	wire is_zero_result = (is_zeroA || is_zeroB) && !is_nan_result && !is_inf_result;

	// final select
	assign sC = is_nan_result ? 1'b0 : (sA ^ sB);

	wire [7:0] eC;
	assign eC = (is_nan_result || is_inf_result) ? 8'd255 :
	            is_zero_result                    ? 8'd0   :
	            final_exponent;

	wire [22:0] mC;
	assign mC = is_nan_result                     ? 23'h400000 :  
	            (is_inf_result || is_zero_result) ? 23'd0       :
	            final_mantissa;

	assign float = {sC, eC, mC};

endmodule
