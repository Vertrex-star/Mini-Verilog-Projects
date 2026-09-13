module fpu_adder #(parameter int WIDTH = 32) (
	input logic clk,
	input logic rst_n,

	input logic[WIDTH-1:0] bin1,
	input logic[WIDTH-1:0] bin2,

	output logic[WIDTH-1:0] bout
);

// parsing 
logic bs1, bs2;
logic [7:0] be1, be2;
logic [22:0] bm1, bm2;

assign bs1 = bin1[0];
assign bs2 = bin2[0];
assign be1 = bin1[8:1];
assign be2 = bin2[8:1];
assign bm1 = bin1[31:9];
assign bm2 = bin2[31:9];

logic bsout;
assign bsout = bs1 ^ bs2;

// determine whether or not we got a special case
logic zero1, zero2;
logic inf1, inf2;
logic nan1, nan2;

assign zero1 = (be1 == 0) && (bm1 == 0);
assign zero2 = (be2 == 0) && (bm2 == 0);
assign inf1 = (be1 == '1) && (bm1 == 0);
assign inf2 = (be2 == '1) && (bm2 == 0);
assign nan1 = (be1 == '1) && (bm1 != 0);
assign nan2 = (be2 == '1) && (bm2 != 0);

logic isnan, isinf, iszero;

assign isnan = nan1 || nan2 || (bsout == 1'b1 && (inf1 && inf2));
assign isinf = !isnan && (bsout ? (inf1 ^ inf2) : (inf1 || inf2));
assign iszero = zero1 && zero2;

logic inf_sign;
assign inf_sign = inf1 ? bs1 : bs2;

// alignment (combinational)
logic signed [8:0] exp_diff;
logic [7:0] shift_amt;
logic e1_ge_e2;
logic [7:0] e_common;

assign exp_diff = {1'b0, be1} - {1'b0, be2};
assign e1_ge_e2 = (be1 >= be2);
assign shift_amt = e1_ge_e2 ? exp_diff[7:0] : (-exp_diff[7:0]);
assign e_common = e1_ge_e2 ? be1 : be2;

logic [46:0] full_bm1, full_bm2;

assign full_bm1 = {1'b1, bm1, 23'b0};
assign full_bm2 = {1'b1, bm2, 23'b0};

function automatic logic sticky_calc(input logic [46:0] val, input logic [7:0] shift);
	if (shift == 0)
		sticky_calc = 1'b0;
		
	else if (shift >= 47)
		sticky_calc = |val;
		
	else
		sticky_calc = |(val & ((47'b1 << shift) - 47'b1));
		
endfunction

logic [46:0] shifted_bm1, shifted_bm2;
logic sticky1, sticky2;

assign shifted_bm1 = e1_ge_e2 ? full_bm1 : (shift_amt >= 8'd47 ? 47'b0 : (full_bm1 >> shift_amt));
assign shifted_bm2 = e1_ge_e2 ? (shift_amt >= 8'd47 ? 47'b0 : (full_bm2 >> shift_amt)) : full_bm2;

assign sticky1 = e1_ge_e2 ? 1'b0 : sticky_calc(full_bm1, shift_amt);
assign sticky2 = e1_ge_e2 ? sticky_calc(full_bm2, shift_amt) : 1'b0;

logic mag1_ge_mag2;
assign mag1_ge_mag2 = (shifted_bm1 >= shifted_bm2);

logic same_sign;
assign same_sign = !bsout;

logic result_sign;
assign result_sign = same_sign ? bs1 : (mag1_ge_mag2 ? bs1 : bs2);

// stage 1 | Exponent difference | Align | Compare
logic c_NaN, c_inf, c_zero;
logic c_sign, c_same_sign, c_sticky, c_inf_sign;
logic [7:0] c_exp;
logic [46:0] c_big, c_small;

always_ff @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		c_NaN <= 1'b0;
		c_inf <= 1'b0;
		c_zero <= 1'b0;
		
		c_sign <= 1'b0;
		c_exp <= 8'b0;
		
		c_big <= 47'b0;
		c_small <= 47'b0;
		
		c_same_sign <= 1'b0;
		c_sticky <= 1'b0;
		c_inf_sign <= 1'b0;
		
	end else begin
		c_NaN <= isnan;
		c_inf <= isinf;
		c_zero <= iszero;
		
		c_sign <= result_sign;
		c_exp <= e_common;
		
		c_big <= mag1_ge_mag2 ? shifted_bm1 : shifted_bm2;
		c_small <= mag1_ge_mag2 ? shifted_bm2 : shifted_bm1;
		
		c_same_sign <= same_sign;
		c_sticky <= sticky1 | sticky2;
		c_inf_sign <= inf_sign;
		
	end
end

// stage 2 | Add | Subtract 
logic [47:0] sum_ext;
assign sum_ext = c_same_sign ? ({1'b0, c_big} + {1'b0, c_small}) : ({1'b0, c_big} - {1'b0, c_small});

logic d_NaN, d_inf, d_zero, d_sign, d_sticky, d_inf_sign;
logic [7:0] d_exp;
logic [47:0] d_sum;

always_ff @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		d_NaN <= 1'b0;
		d_inf <= 1'b0;
		
		d_zero <= 1'b0;
		d_sign <= 1'b0;
		
		d_exp <= 8'b0;
		d_sum <= 48'b0;
		
		d_sticky <= 1'b0;
		d_inf_sign <= 1'b0;
		
	end else begin
		d_NaN <= c_NaN;
		d_inf <= c_inf;
		d_zero <= c_zero;
		
		d_sign <= c_sign;
		
		d_exp <= c_exp;
		d_sum <= sum_ext;
		d_sticky <= c_sticky;
		d_inf_sign <= c_inf_sign;
	end
end

// stage 3 | Normalize | Round 
logic [5:0] lead_zero;
always_comb begin
	lead_zero = 6'd0;
	for (int i = 46; i >= 0; i--) begin
		if (d_sum[i]) begin
			lead_zero = 6'(46 - i);
			break;
		end
	end
end

logic [47:0] norm_sum;
logic [8:0] norm_exp;

always_comb begin
	if (d_sum[47]) begin
		norm_sum = d_sum >> 1;
		norm_exp = {1'b0, d_exp} + 9'd1;
	end else begin
		norm_sum = d_sum << lead_zero;
		norm_exp = {1'b0, d_exp} - {3'b0, lead_zero};
	end
end

logic guard, round_bit, sticky_final, round_up;

assign guard = norm_sum[22];
assign round_bit = norm_sum[21];
assign sticky_final = (|norm_sum[20:0]) | d_sticky;
assign round_up = guard && (round_bit || sticky_final || norm_sum[23]);

logic [24:0] mant_add;
logic [8:0] rounded_exp;
logic [22:0] rounded_mant;

assign mant_add = {1'b0, norm_sum[46:23]} + (round_up ? 25'd1 : 25'd0);

always_comb begin
	if (mant_add[24]) begin
		rounded_mant = mant_add[23:1];
		rounded_exp = norm_exp + 9'd1;
	end else begin
		rounded_mant = mant_add[22:0];
		rounded_exp = norm_exp;
	end
end

logic exact_zero;
assign exact_zero = (d_sum == 48'b0);

logic s3;
logic [7:0] e3;
logic [22:0] m3;

always_comb begin
	if (d_NaN) begin
		s3 = 1'b0;
		e3 = 8'hFF;
		m3 = 23'h400000;
		
	end else if (d_inf) begin
		s3 = d_inf_sign;
		e3 = 8'hFF;
		m3 = 23'b0;
		
	end else if (d_zero || exact_zero) begin
		s3 = d_sign;
		e3 = 8'b0;
		m3 = 23'b0;
		
	end else if (rounded_exp >= 9'd255) begin
		s3 = d_sign;
		e3 = 8'hFF;
		m3 = 23'b0;
		
	end else begin
		s3 = d_sign;
		e3 = rounded_exp[7:0];
		m3 = rounded_mant;
		
	end
end

assign bout = {m3, e3, s3};

endmodule
