// Rojan Karn
// Top-level file for Project 3 - Reorder Buffer

module proj3_ROB (
		input logic clk, reset,
		input logic write_instr,
		input logic [31:0] new_instr,
		output logic done
);

	// connect all modules here
	
	// BUS SIGNALS
	logic [31:0] ROB_bus_value;
	logic [2:0] ROB_bus_tag;
	logic ROB_bus_trigger;
	
	// instruction queue
	// iq signals
	logic du1_read_en, du2_read_en;
	logic [31:0] odd_instr, even_instr;
	logic result_ready;
	
	// write enable and new_instr need to come from the testbench
	instruction_queue iq (.clk(clk), .reset(reset), .new_instr(new_instr), .write_en(write_instr),
									.read_en1(du1_read_en), .read_en2(du2_read_en), .odd_instr(odd_instr), .even_instr(even_instr),
									.result_ready(result_ready));
	
	// dispatch unit 1 - this will get the odd instructions (I1, I3, I5, ...)
	// du1 signals
	logic [3:0] ADD_avail_IDs, MUL_avail_IDs;
	logic du1_dispatch_ready;
	logic [2:0] du1_rat_rd, du1_rat_rs1, du1_rat_rs2, du1_rat_renamed_tag;
	logic du1_rat_multiply;
	logic du1_du2_multiply, du2_du1_multiply;
	logic [2:0] du2_du1_rd, du2_du1_rs1, du2_du1_rs2;
	logic [2:0] du1_du2_rd, du1_du2_rs1, du1_du2_rs2;
	
	// Ready signal for RAT
	logic RAT_ready;
	
	// ROB
	logic [2:0] next_available;
	
	dispatch_unit #(1'b1) du1 (.clk(clk), .reset(reset), .iq_read_en(du1_read_en), .instr_in(odd_instr), .result_ready(result_ready),
										.ADD_avail_IDs(ADD_avail_IDs), .MUL_avail_IDs(MUL_avail_IDs),
										.dispatch_ready(du1_dispatch_ready), .rd(du1_rat_rd), .rs1(du1_rat_rs1),
										.rs2(du1_rat_rs2), .multiply(du1_rat_multiply), .renamed_tag(du1_rat_renamed_tag),
										.multiply_in(du2_du1_multiply), .rd_in(du2_du1_rd), .rs1_in(du2_du1_rs1),
										.rs2_in(du2_du1_rs2), .multiply_out(du1_du2_multiply), .rd_out(du1_du2_rd),
										.rs1_out(du1_du2_rs1), .rs2_out(du1_du2_rs2), .RAT_ready(RAT_ready), .next_available(next_available));
	
	// dispatch unit 2 - gets even instructions
	logic du2_dispatch_ready;
	logic [2:0] du2_rat_rd, du2_rat_rs1, du2_rat_rs2, du2_rat_renamed_tag;
	logic du2_rat_multiply;
	
	dispatch_unit #(1'b0) du2 (.clk(clk), .reset(reset), .iq_read_en(du2_read_en), .instr_in(even_instr), .result_ready(result_ready),
										.ADD_avail_IDs(ADD_avail_IDs), .MUL_avail_IDs(MUL_avail_IDs),
										.dispatch_ready(du2_dispatch_ready), .rd(du2_rat_rd), .rs1(du2_rat_rs1),
										.rs2(du2_rat_rs2), .multiply(du2_rat_multiply), .renamed_tag(du2_rat_renamed_tag),
										.multiply_in(du1_du2_multiply), .rd_in(du1_du2_rd), .rs1_in(du1_du2_rs1),
										.rs2_in(du1_du2_rs2), .multiply_out(du2_du1_multiply), .rd_out(du2_du1_rd),
										.rs1_out(du2_du1_rs1), .rs2_out(du2_du1_rs2), .RAT_ready(RAT_ready), .next_available(next_available));
	
	
	
	// Register File (register alias table)
	// rat signals
	logic ADD_load_one, ADD_load_two, MUL_load_one, MUL_load_two;
	logic [2:0] ADD_a_RSID, ADD_b_RSID, MUL_a_RSID, MUL_b_RSID;
	// ADDs
	logic [2:0] ADD_src1a_tag, ADD_src2a_tag, ADD_src1b_tag, ADD_src2b_tag;
	logic [31:0] ADD_src1a_val, ADD_src2a_val, ADD_src1b_val, ADD_src2b_val;
	logic ADD_src1a_valid, ADD_src2a_valid, ADD_src1b_valid, ADD_src2b_valid;
	
	// MULs
	logic [2:0] MUL_src1a_tag, MUL_src2a_tag, MUL_src1b_tag, MUL_src2b_tag;
	logic [31:0] MUL_src1a_val, MUL_src2a_val, MUL_src1b_val, MUL_src2b_val;
	logic MUL_src1a_valid, MUL_src2a_valid, MUL_src1b_valid, MUL_src2b_valid;
	
	// ROB signals
	logic RF_new_instr, new_mul_a, new_mul_b;
	logic [2:0] rd_a, rd_b, src1a, src2a, src1b, src2b;
	logic src1a_valid, src2a_valid, src1b_valid, src2b_valid;
	
	register_file RF (.clk(clk), .reset(reset), .dispatch_ready1(du1_dispatch_ready), .dispatch_ready2(du2_dispatch_ready),
							  .du1_rd(du1_rat_rd), .du1_rs1(du1_rat_rs1), .du1_rs2(du1_rat_rs2), .du1_multiply(du1_rat_multiply),
							  .du1_renamed_tag(du1_rat_renamed_tag), .du2_rd(du2_rat_rd), .du2_rs1(du2_rat_rs1), .du2_rs2(du2_rat_rs2),
							  .du2_multiply(du2_rat_multiply), .du2_renamed_tag(du2_rat_renamed_tag),
							  // outputs to RSs
							  // first instr to adder
							  .ADD_load_one(ADD_load_one), .ADD_load_two(ADD_load_two), .ADD_src1a_tag(ADD_src1a_tag),
							  .ADD_src2a_tag(ADD_src2a_tag), .ADD_src1a_val(ADD_src1a_val), .ADD_src2a_val(ADD_src2a_val),
							  .ADD_src1a_valid(ADD_src1a_valid), .ADD_src2a_valid(ADD_src2a_valid), .ADD_a_RSID(ADD_a_RSID),
							  // second instr to adder
							  .ADD_src1b_tag(ADD_src1b_tag), .ADD_src2b_tag(ADD_src2b_tag), .ADD_src1b_val(ADD_src1b_val),
							  .ADD_src2b_val(ADD_src2b_val), .ADD_src1b_valid(ADD_src1b_valid), .ADD_src2b_valid(ADD_src2b_valid),
							  .ADD_b_RSID(ADD_b_RSID),
							  // first instr to multiplier
							  .MUL_load_one(MUL_load_one), .MUL_load_two(MUL_load_two), .MUL_src1a_tag(MUL_src1a_tag),
							  .MUL_src2a_tag(MUL_src2a_tag), .MUL_src1a_val(MUL_src1a_val), .MUL_src2a_val(MUL_src2a_val),
							  .MUL_src1a_valid(MUL_src1a_valid), .MUL_src2a_valid(MUL_src2a_valid), .MUL_a_RSID(MUL_a_RSID),
							  // second instr to multiplier
							  .MUL_src1b_tag(MUL_src1b_tag), .MUL_src2b_tag(MUL_src2b_tag), .MUL_src1b_val(MUL_src1b_val),
							  .MUL_src2b_val(MUL_src2b_val), .MUL_src1b_valid(MUL_src1b_valid), .MUL_src2b_valid(MUL_src2b_valid),
							  .MUL_b_RSID(MUL_b_RSID),
							  // bus signals
							  .ROB_bus_trigger(ROB_bus_trigger), .ROB_bus_tag(ROB_bus_tag), .ROB_bus_value(ROB_bus_value),
							  // RAT ready
							  .RAT_ready(RAT_ready),
							  // outputs to ROB
							  .RF_new_instr(RF_new_instr), .new_mul_a(new_mul_a), .new_mul_b(new_mul_b), .rd_a(rd_a), .rd_b(rd_b),
							  .src1a(src1a), .src2a(src2a), .src1b(src1b), .src2b(src2b), .src1a_valid(src1a_valid), .src2a_valid(src2a_valid),
							  .src1b_valid(src1b_valid), .src2b_valid(src2b_valid)
							  );
	
	// adder RS
	// ADD_RS signals
	logic adder_ready;
	logic add_valid_instr;
	logic [31:0] add_op1, add_op2;
	logic [2:0] add_tag_out;
	
	adder_rs ADD_RS (.clk(clk), .reset(reset), .adder_ready(adder_ready), .load_one(ADD_load_one), .load_two(ADD_load_two),
						  .src1a_tag(ADD_src1a_tag), .src2a_tag(ADD_src2a_tag), .src1a_val(ADD_src1a_val), .src2a_val(ADD_src2a_val),
						  .src1a_valid(ADD_src1a_valid), .src2a_valid(ADD_src2a_valid), .a_RSID(ADD_a_RSID),
						  // second instruction
						  .src1b_tag(ADD_src1b_tag), .src2b_tag(ADD_src2b_tag), .src1b_val(ADD_src1b_val), .src2b_val(ADD_src2b_val),
						  .src1b_valid(ADD_src1b_valid), .src2b_valid(ADD_src2b_valid), .b_RSID(ADD_b_RSID),
						  // FU logic
						  .valid_instr(add_valid_instr), .op1(add_op1), .op2(add_op2), .tag_out(add_tag_out), .avail_IDs(ADD_avail_IDs),
						  .ROB_bus_trigger(ROB_bus_trigger), .ROB_bus_tag(ROB_bus_tag), .ROB_bus_value(ROB_bus_value));

	// multiplier RS
	// MUL_RS signals
	logic mul_ready;
	logic mul_valid_instr;
	logic [31:0] MUL_op1, MUL_op2;
	logic [2:0] MUL_tag_out;
	
	mul_rs MUL_RS (.clk(clk), .reset(reset), .mul_ready(mul_ready), .load_one(MUL_load_one), .load_two(MUL_load_two),
					  .src1a_tag(MUL_src1a_tag), .src2a_tag(MUL_src2a_tag), .src1a_val(MUL_src1a_val), .src2a_val(MUL_src2a_val),
					  .src1a_valid(MUL_src1a_valid), .src2a_valid(MUL_src2a_valid), .a_RSID(MUL_a_RSID),
					  // second instruction
					  .src1b_tag(MUL_src1b_tag), .src2b_tag(MUL_src2b_tag), .src1b_val(MUL_src1b_val), .src2b_val(MUL_src2b_val),
					  .src1b_valid(MUL_src1b_valid), .src2b_valid(MUL_src2b_valid), .b_RSID(MUL_b_RSID),
					  // FU logic
					  .valid_instr(mul_valid_instr), .op1(MUL_op1), .op2(MUL_op2), .tag_out(MUL_tag_out), .avail_IDs(MUL_avail_IDs),
					  .ROB_bus_trigger(ROB_bus_trigger), .ROB_bus_tag(ROB_bus_tag), .ROB_bus_value(ROB_bus_value));
	
	// FU to ROB signals
	logic add_fu_valid, mul_fu_valid;
	logic [2:0] add_fu_tag, mul_fu_tag;
	logic [31:0] add_fu_value, mul_fu_value;
	
	// adder FU
	adder ADD_FU (.clk(clk), .reset(reset), .valid_instr(add_valid_instr), .op1(add_op1), .op2(add_op2), .tag(add_tag_out),
					  .adder_ready(adder_ready), .broadcast_val(add_fu_value), .broadcast_tag(add_fu_tag), .bus_trigger(add_fu_valid));

	// multiplier FU
	multiplier MUL_FU (.clk(clk), .reset(reset), .valid_instr(mul_valid_instr), .op1(MUL_op1), .op2(MUL_op2), .tag(MUL_tag_out),
					  .mul_ready(mul_ready), .broadcast_val(mul_fu_value), .broadcast_tag(mul_fu_tag), .bus_trigger(mul_fu_valid));

	// Reorder Buffer
	ROB REORDER_BUFF (.clk(clk), .reset(reset), .ADD_FU_valid(add_fu_valid), .ADD_FU_tag(add_fu_tag), .ADD_FU_value(add_fu_value),
							.MUL_FU_valid(mul_fu_valid), .MUL_FU_tag(mul_fu_tag), .MUL_FU_value(mul_fu_value), .RAT_new_instr(RF_new_instr),
							.new_mul_a(new_mul_a), .new_mul_b(new_mul_b), .rd_a(rd_a), .rd_b(rd_b), .src1a(src1a), .src2a(src2a),
							.src1b(src1b), .src2b(src2b), .src1a_valid(src1a_valid), .src2a_valid(src2a_valid), .src1b_valid(src1b_valid),
							.src2b_valid(src2b_valid), .next_available(next_available), 
							.ROB_bus_trigger(ROB_bus_trigger), .ROB_bus_tag(ROB_bus_tag), .ROB_bus_value(ROB_bus_value)
							);

endmodule
