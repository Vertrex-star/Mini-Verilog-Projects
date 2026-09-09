module FPU_multiply #(parameter int unsigned WIDTH = 32
)(	
	input logic clk,
	input logic rst_n,
	
	input logic[WIDTH-1:0] bin1,
	input logic[WIDTH-1:0] bin2,
	
	output logic[WIDTH-1:0] bout
);

logic [7:0] be1, be2;
logic [22:0] bm1, bm2;

assign be1 = bin1[8:1];
assign be2 = bin2[8:1];
assign bm1 = bin1[31:9];
assign bm2 = bin2[31:9];

logic zero1_c, zero2_c;
logic inf1_c, inf2_c;
logic nan1_c, nan2_c;

assign zero1_c = (be1 == 0) && (bm1 == 0);
assign zero2_c = (be2 == 0) && (bm2 == 0);
assign inf1_c = (be1 == '1) && (bm1 == 0);
assign inf2_c = (be2 == '1) && (bm2 == 0);
assign nan1_c = (be1 == '1) && (bm1 != 0);
assign nan2_c = (be2 == '1) && (bm2 != 0);

logic nanin_c, zeroinf_c, zero_op_c, inf_op_c;

assign nanin_c = nan1_c || nan2_c;
assign zeroinf_c = (zero1_c && inf2_c) || (zero2_c && inf1_c);
assign zero_op_c = zero1_c || zero2_c;
assign inf_op_c = inf1_c || inf2_c;

logic NaN_c, inf_c, zero_c;

assign NaN_c = nanin_c || zeroinf_c;
assign inf_c = inf_op_c && !NaN_c;
assign zero_c = zero_op_c && !NaN_c;

logic NaN;
logic inf;
logic zero;

logic s1; 
logic s2;

logic[7:0] e1; 
logic[7:0] e2; 

logic[22:0] m1; 
logic[22:0] m2;

logic s3; 
logic[7:0] e3; 
logic[22:0] m3;

logic special_flag;
logic signed [9:0] exp_raw;

logic s3_s3; 
logic[7:0] e3_s3; 
logic[22:0] m3_s3;

logic[47:0] product; 

function automatic void csa_reduce(
	input logic [47:0] a,
	input logic [47:0] b,
	input logic [47:0] c,
	output logic [47:0] sum,
	output logic [47:0] carry
);
	logic [47:0] carry_raw;
	for (int i = 0; i < 48; i++) begin
		sum[i] = a[i] ^ b[i] ^ c[i];
		carry_raw[i] = (a[i] & b[i]) | (a[i] & c[i]) | (b[i] & c[i]);
	end
	carry = carry_raw << 1;
endfunction

function automatic void wallace_layer(
	input logic [47:0] rows_in [$],
	output logic [47:0] rows_out [$]
);
	int n;
	int idx;
	logic [47:0] s, c;

	rows_out.delete();
	n = rows_in.size();
	idx = 0;

	while (idx + 3 <= n) begin
		csa_reduce(rows_in[idx], rows_in[idx+1], rows_in[idx+2], s, c);
		rows_out.push_back(s);
		rows_out.push_back(c);
		idx += 3;
	end

	while (idx < n) begin
		rows_out.push_back(rows_in[idx]);
		idx++;
	end
endfunction

function automatic logic [47:0] wallace_multiply(
	input logic [22:0] mant_a,
	input logic [22:0] mant_b
);
	logic [23:0] sig_a, sig_b;
	logic [47:0] pp [$];
	logic [47:0] stage_in [$];
	logic [47:0] stage_out [$];

	sig_a = {1'b1, mant_a};
	sig_b = {1'b1, mant_b};

	pp.delete();
	for (int i = 0; i < 24; i++) begin
		if (sig_b[i])
			pp.push_back({24'b0, sig_a} << i);
		else
			pp.push_back(48'b0);
	end

	stage_in = pp;
	while (stage_in.size() > 2) begin
		wallace_layer(stage_in, stage_out);
		stage_in = stage_out;
	end

	return stage_in[0] + stage_in[1];
endfunction

always_ff @(posedge clk or negedge rst_n) begin 
	if (!rst_n) begin 
		s1 <= '0;
		s2 <= '0;
		e1 <= '0;
		e2 <= '0; 
		m1 <= '0;
		m2 <= '0;
		NaN <= '0;
		inf <= '0;
		zero <= '0;
	end else begin 
		s1 <= bin1[0];
		s2 <= bin2[0];
		e1 <= be1;
		e2 <= be2; 
		m1 <= bm1;
		m2 <= bm2;
		
		NaN <= NaN_c;
		inf <= inf_c;
		zero <= zero_c;
	end
end

always_ff @(posedge clk or negedge rst_n) begin 
	if (!rst_n) begin
		s3 <= '0;
		e3 <= '0;
		m3 <= '0;
		product <= '0;
		exp_raw <= '0;
		special_flag <= '0;
	end else begin 
		if (NaN) begin 
			s3 <= '0;
			e3 <= '1;
			m3 <= '1;
			product <= product;
			exp_raw <= exp_raw;
			special_flag <= '1;
		end else if (inf) begin 
			s3 <= s1 ^ s2;
			e3 <= '1;
			m3 <= '0;
			product <= product;
			exp_raw <= exp_raw;
			special_flag <= '1;
		end else if (zero) begin 
			s3 <= s1 ^ s2;
			e3 <= '0;
			m3 <= '0;
			product <= product;
			exp_raw <= exp_raw;
			special_flag <= '1;
		end else begin
			automatic logic signed [9:0] exp_sum;
			exp_sum = {2'b00, e1} + {2'b00, e2} - 10'sd127;

			s3 <= s1 ^ s2;
			e3 <= '0;
			m3 <= '0;
			product <= wallace_multiply(m1, m2);
			exp_raw <= exp_sum;
			special_flag <= '0;
		end
	end
end

always_ff @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
		m3_s3 <= 0;
		e3_s3 <= 0;
		s3_s3 <= 0;
	end else begin 
		if (special_flag) begin
			m3_s3 <= m3;
			e3_s3 <= e3;
			s3_s3 <= s3;
		end else begin
			automatic logic shift_needed;
			automatic logic [47:0] norm_product;
			automatic logic signed [9:0] exp_adj;
			automatic logic [22:0] mant_candidate;
			automatic logic guard, round_bit, sticky, round_up;
			automatic logic [23:0] mant_rounded;
			automatic logic signed [9:0] exp_final;

			shift_needed = product[47];
			norm_product = shift_needed ? (product >> 1) : product;
			exp_adj = exp_raw + (shift_needed ? 10'sd1 : 10'sd0);

			mant_candidate = norm_product[45:23];
			guard = norm_product[22];
			round_bit = norm_product[21];
			sticky = |norm_product[20:0];

			round_up = guard && (round_bit || sticky || mant_candidate[0]);
			mant_rounded = {1'b0, mant_candidate} + {23'b0, round_up};

			exp_final = exp_adj + (mant_rounded[23] ? 10'sd1 : 10'sd0);

			if (exp_final >= 10'sd255) begin
				s3_s3 <= s3;
				e3_s3 <= '1;
				m3_s3 <= '0;
			end else if (exp_final <= 10'sd0) begin
				s3_s3 <= s3;
				e3_s3 <= '0;
				m3_s3 <= '0;
			end else begin
				s3_s3 <= s3;
				e3_s3 <= exp_final[7:0];
				m3_s3 <= mant_rounded[22:0];
			end
		end
	end
end 

assign bout = {m3_s3, e3_s3, s3_s3};
	
endmodule
