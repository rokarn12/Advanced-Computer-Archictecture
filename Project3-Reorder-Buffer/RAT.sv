// register alias table
module register_file (
	input clk, reset,

	// dispatch ready signal - start operations
	input logic dispatch_ready1, dispatch_ready2,
	
	// inputs from dispatch unit 1
	input logic [2:0] du1_rd, du1_rs1, du1_rs2,
	input logic du1_multiply,
	input logic [2:0] du1_renamed_tag,
	input logic du1_branch_instr,
	
	// inputs from dispatch unit 2
	input logic [2:0] du2_rd, du2_rs1, du2_rs2,
	input logic du2_multiply,
	input logic [2:0] du2_renamed_tag,
	input logic du2_branch_instr,
	
	// output to RSs
	// first instruction output to adder RS
	output logic ADD_load_one, ADD_load_two,
	output logic [2:0] ADD_src1a_tag, ADD_src2a_tag,
	output logic [31:0] ADD_src1a_val, ADD_src2a_val,
	output logic ADD_src1a_valid, ADD_src2a_valid,
	output logic [2:0] ADD_a_RSID,
	
	// second instruction output to adder RS
	output logic [2:0] ADD_src1b_tag, ADD_src2b_tag,
	output logic [31:0] ADD_src1b_val, ADD_src2b_val,
	output logic ADD_src1b_valid, ADD_src2b_valid,
	output logic [2:0] ADD_b_RSID,
	
	// first instruction output to multiplier RS
	output logic MUL_load_one, MUL_load_two,
	output logic [2:0] MUL_src1a_tag, MUL_src2a_tag,
	output logic [31:0] MUL_src1a_val, MUL_src2a_val,
	output logic MUL_src1a_valid, MUL_src2a_valid,
	output logic [2:0] MUL_a_RSID,
	
	// second instruction output to multiplier RS
	output logic [2:0] MUL_src1b_tag, MUL_src2b_tag,
	output logic [31:0] MUL_src1b_val, MUL_src2b_val,
	output logic MUL_src1b_valid, MUL_src2b_valid,
	output logic [2:0] MUL_b_RSID,
	
	// listen on bus for update
	input logic ROB_bus_trigger,
	input logic ROB_exception_flush,
	input logic [2:0] ROB_bus_tag,
	input logic [31:0] ROB_bus_value,
	
	// output to DUs letting them know whether RAT is available to take another instruction
	output logic RAT_ready,
	
	// outputs to ROB
	// sending two instructions at a time
	output logic RF_new_instr, new_mul_a, new_mul_b,
	output logic [2:0] rd_a, rd_b,
	output logic [2:0] src1a, src2a, src1b, src2b,
	output logic src1a_valid, src2a_valid, src1b_valid, src2b_valid,
	
	// outputs to BRANCH FU
	output logic new_branch,
	output logic [31:0] branch_op1, branch_op2,
	output logic [2:0] branch_tag
);

	typedef struct {
		logic [2:0] register_id; // R1 - R7
		//logic valid; // 1 or 0
		//logic [2:0] tag; // a, b, c, d, x, y, z, k
		logic [31:0] value; // assigned numerical value in register
	} rat_line;
	
	rat_line RA_table[8]; // instantiate Register File
	
	// build mapping table: maps logical registers to ROB entries
	typedef struct {
		logic [2:0] reg_id;
		logic [2:0] tag_rob_entry;
		logic valid;					// valid is high when the translation is valid
	} map_table_line;
	
	map_table_line mapping_table[8];
	
	
	// Initialize RF and mapping table
	initial begin
		// Initialize according to OoO Machine Simulation in slides
		for (int i = 0; i < 8; i++) begin
			// Register File
			RA_table[i].register_id = i;
			//RA_table[i].valid = 1'b1;
			//RA_table[i].tag = 3'bz;
			RA_table[i].value = (i*10);
			
			// Mapping Table
			mapping_table[i].reg_id = i;
			mapping_table[i].tag_rob_entry = 0;
			mapping_table[i].valid = 0;				// if it doesnt map to a ROB entry, mark invalid
		end
		// RF and Mapping Table should be initialized now for R1 - R7
		
		// branch testing
		// make R2 == R6
		RA_table[6].value = 32'd20;
	end // end initial
	
	logic print_table;
	
	// sending instruction info straight to ROB
	assign rd_a = du1_rd;
	assign rd_b = du2_rd;
	
	// if the register's mapping is valid, send the ROB entry tag, else, send the register itself
	assign src1a = mapping_table[du1_rs1].valid ? mapping_table[du1_rs1].tag_rob_entry : du1_rs1;
	assign src2a = mapping_table[du1_rs2].valid ? mapping_table[du1_rs2].tag_rob_entry : du1_rs2;
	assign src1b = mapping_table[du2_rs1].valid ? mapping_table[du2_rs1].tag_rob_entry : du2_rs1;
	assign src2b = mapping_table[du2_rs2].valid ? mapping_table[du2_rs2].tag_rob_entry : du2_rs2;
	
	assign src1a_valid = !mapping_table[du1_rs1].valid;		// send inverse valid
	assign src2a_valid = !mapping_table[du1_rs2].valid;
	assign src1b_valid = !mapping_table[du2_rs1].valid;
	assign src2b_valid = !mapping_table[du2_rs2].valid;
	
	assign branch_tag = du1_branch_instr ? du1_renamed_tag : du2_renamed_tag;
	assign branch_op1 = du1_branch_instr ? RA_table[du1_rs1].value : RA_table[du2_rs1].value;
	assign branch_op2 = du1_branch_instr ? RA_table[du1_rs2].value : RA_table[du2_rs2].value;
	
	logic curr1_mul, curr2_mul;
	logic [2:0] d1_rename, d2_rename;
	
	// dispatch instructions logic
	always @(posedge clk) begin
		if (reset) begin
			MUL_a_RSID <= 0;
			
		end

		// update the Register Alias Table


		else if (dispatch_ready1 && dispatch_ready2) begin

			curr1_mul <= du1_multiply;
			curr2_mul <= du2_multiply;
			
			d1_rename <= du1_renamed_tag;
			d2_rename <= du2_renamed_tag;
			
			// set outputs to RSs
			// first instruction (a)
			if (du1_multiply) begin
			//if (curr1_mul) begin
				// instruction from DU1 is multiply type
				MUL_a_RSID <= du1_renamed_tag;									// need to look into RSID functionality
				MUL_src1a_tag <= mapping_table[du1_rs1].tag_rob_entry;
				MUL_src2a_tag <= mapping_table[du1_rs2].tag_rob_entry;
				MUL_src1a_val <= RA_table[du1_rs1].value;
				MUL_src2a_val <= RA_table[du1_rs2].value;
				MUL_src1a_valid <= !mapping_table[du1_rs1].valid;		// need to invert valid bit from mapping table
				MUL_src2a_valid <= !mapping_table[du1_rs2].valid;		// because valid in mapping table means that the 
				$display("RAT: DU1 is multiply");									// register is translated, meaning no data ...
			end else if (!du1_branch_instr) begin
				// instruction from DU1 is add type
				ADD_a_RSID <= du1_renamed_tag;
				ADD_src1a_tag <= mapping_table[du1_rs1].tag_rob_entry;
				ADD_src2a_tag <= mapping_table[du1_rs2].tag_rob_entry;
				ADD_src1a_val <= RA_table[du1_rs1].value;
				ADD_src2a_val <= RA_table[du1_rs2].value;
				ADD_src1a_valid <= !mapping_table[du1_rs1].valid;
				ADD_src2a_valid <= !mapping_table[du1_rs2].valid;
			end else if (!du2_multiply) begin
				// du1 is a branch and du2 is add
				ADD_a_RSID <= du2_renamed_tag;
				ADD_src1a_tag <= mapping_table[du2_rs1].tag_rob_entry;
				ADD_src2a_tag <= mapping_table[du2_rs2].tag_rob_entry;
				ADD_src1a_val <= RA_table[du2_rs1].value;
				ADD_src2a_val <= RA_table[du2_rs2].value;
				ADD_src1a_valid <= !mapping_table[du2_rs1].valid;
				ADD_src2a_valid <= !mapping_table[du2_rs2].valid;
			end
			
			// second instruction (b)
			if (du2_multiply) begin
			//if (curr2_mul) begin
				// instruction from DU2 is multiply type
				if (du1_multiply) begin	// du1 is also a multiply, so send to second port
				//if (curr1_mul) begin
					MUL_b_RSID <= du2_renamed_tag;
					MUL_src1b_tag <= mapping_table[du2_rs1].tag_rob_entry;
					MUL_src2b_tag <= mapping_table[du2_rs2].tag_rob_entry;
					MUL_src1b_val <= RA_table[du2_rs1].value;
					MUL_src2b_val <= RA_table[du2_rs2].value;
					MUL_src1b_valid <= !mapping_table[du2_rs1].valid;
					MUL_src2b_valid <= !mapping_table[du2_rs2].valid;
				end else begin	// du1 is not multiply, send this to first port
					MUL_a_RSID <= du2_renamed_tag;
					MUL_src1a_tag <= mapping_table[du2_rs1].tag_rob_entry;
					MUL_src2a_tag <= mapping_table[du2_rs2].tag_rob_entry;
					MUL_src1a_val <= RA_table[du2_rs1].value;
					MUL_src2a_val <= RA_table[du2_rs2].value;
					MUL_src1a_valid <= !mapping_table[du2_rs1].valid;
					MUL_src2a_valid <= !mapping_table[du2_rs2].valid;

				end
			end else begin
				// instruction from DU2 is add type
				// need to check whether to send this into the first or second port
				if (!du1_multiply) begin // if du1 is also an add
				//if (!curr1_mul) begin
					ADD_b_RSID <= du2_renamed_tag;
					ADD_src1b_tag <= mapping_table[du2_rs1].tag_rob_entry;
					ADD_src2b_tag <= mapping_table[du2_rs2].tag_rob_entry;
					ADD_src1b_val <= RA_table[du2_rs1].value;
					ADD_src2b_val <= RA_table[du2_rs2].value;
					ADD_src1b_valid <= !mapping_table[du2_rs1].valid;
					ADD_src2b_valid <= !mapping_table[du2_rs2].valid;
				end else begin	// du1 is multiply, so send to first port of ADD RS
					ADD_a_RSID <= du2_renamed_tag;
					ADD_src1a_tag <= mapping_table[du2_rs1].tag_rob_entry;
					ADD_src2a_tag <= mapping_table[du2_rs2].tag_rob_entry;
					ADD_src1a_val <= RA_table[du2_rs1].value;
					ADD_src2a_val <= RA_table[du2_rs2].value;
					ADD_src1a_valid <= !mapping_table[du2_rs1].valid;
					ADD_src2a_valid <= !mapping_table[du2_rs2].valid;
					$display("RAT: DU2 is add");
				end
				//$display("DU2 ADD: Src1 valid: %b	Src2 valid: %b", RA_table[du2_rs1].valid, RA_table[du2_rs2].valid);
			end
		end // end if dispatch ready
	end // end always @ clk or bus trigger
	
	always @(posedge clk) begin
		if (reset) begin
			RAT_ready <= 1'b0;
			ADD_load_two <= 1'b0;
			ADD_load_one <= 1'b0;
			MUL_load_two <= 1'b0;
			MUL_load_one <= 1'b0;
			RF_new_instr <= 1'b0;
			new_branch <= 1'b0;
		end
		// if instructions are ready for dispatch
		else if (dispatch_ready1 && dispatch_ready2) begin		// this is repeated twice - FIX
			RAT_ready <= 1'b0;
			$display("RAT: Received dispatch signals from both DUs");
			
			// place the renamed tag with the appropriate destination register
			$display("RAT: Translating Reg %d and %d", du1_rd, du2_rd);
			mapping_table[du1_rd].tag_rob_entry <= du1_renamed_tag;
			//mapping_table[du1_rd].tag_rob_entry <= d1_rename;
			mapping_table[du1_rd].valid <= 1'b1; // new valid translation
			mapping_table[du2_rd].tag_rob_entry <= du2_renamed_tag;
			//mapping_table[du2_rd].tag_rob_entry <= d2_rename;
			mapping_table[du2_rd].valid <= 1'b1; // new valid translation
			
			//@(posedge clk);
			
			// indicate to reservation station what to load
			case ({du1_multiply, du2_multiply})
			//case ({curr1_mul, curr2_mul})
			
				2'b00: begin
					// both are add
					
					// STALL LOGIC FOR BRANCHING
					if ((du1_branch_instr && mapping_table[du1_rs1].valid) || (du1_branch_instr && mapping_table[du1_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 00");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end else if ((du2_branch_instr && mapping_table[du2_rs1].valid) || (du2_branch_instr && mapping_table[du2_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 00");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end
					// END STALL LOGIC FOR BRANCHING
					else if (du1_branch_instr || du2_branch_instr) begin
						// if one of the instructions is a branch, only load one add
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b1; 	// load one add
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b1;	// send to ROB
						new_mul_a <= 1'b0;		// both are ADDs
						new_mul_b <= 1'b0;
						new_branch <= 1'b1;		// one of the instr is branch, send to branch FU
					end else begin
						ADD_load_two <= 1'b1; // load 2 adds
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b1;	// send to ROB
						new_mul_a <= 1'b0;		// both are ADDs
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end

				end
				
				2'b01: begin
					// one add one mul
					// STALL LOGIC FOR BRANCHING
					if ((du1_branch_instr && mapping_table[du1_rs1].valid) || (du1_branch_instr && mapping_table[du1_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 01");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end else if ((du2_branch_instr && mapping_table[du2_rs1].valid) || (du2_branch_instr && mapping_table[du2_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 01");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end
					// END STALL LOGIC FOR BRANCHING
					else if (du1_branch_instr || du2_branch_instr) begin
						// if one of the instructions is a branch, only load one of the instructions
						// du2 is multiply, which means du1 is branch
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0; // dont load add
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b1; // load one mul
						RF_new_instr <= 1'b1;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b1;	// du2 is multiply
						new_branch <= 1'b1;
					end else begin
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b1; // load one add
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b1; // load one mul
						RF_new_instr <= 1'b1;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b1;	// du2 is multiply
						new_branch <= 1'b0;
					end
					
				end
				
				2'b10: begin
					// one add one mul
					// STALL LOGIC FOR BRANCHING
					if ((du1_branch_instr && mapping_table[du1_rs1].valid) || (du1_branch_instr && mapping_table[du1_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 10");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end else if ((du2_branch_instr && mapping_table[du2_rs1].valid) || (du2_branch_instr && mapping_table[du2_rs2].valid)) begin
						// stall, wait for the translation to be valid before sending to FU
						$display("RAT: Stalling because translation is valid in 10");
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0;
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b0;
						RF_new_instr <= 1'b0;
						new_mul_a <= 1'b0;
						new_mul_b <= 1'b0;
						new_branch <= 1'b0;
					end
					// END STALL LOGIC FOR BRANCHING
					else if (du1_branch_instr || du2_branch_instr) begin
						// this means du1 is mul, so du2 is branch
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b0; // dont load add
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b1; // load one mul
						RF_new_instr <= 1'b1;
						new_mul_a <= 1'b1;	// this technically doesnt matter in this implementation
						new_mul_b <= 1'b0;	// du2 is add
						new_branch <= 1'b1;
					end else begin
						ADD_load_two <= 1'b0;
						ADD_load_one <= 1'b1; // load one add
						MUL_load_two <= 1'b0;
						MUL_load_one <= 1'b1; // load one mul
						RF_new_instr <= 1'b1;
						new_mul_a <= 1'b1;
						new_mul_b <= 1'b0;	// du2 is add
						new_branch <= 1'b0;
					end
					
					
				end
				
				2'b11: begin
					// both are mul
					//$display("RAT: load two muls set");
					ADD_load_two <= 1'b0;
					ADD_load_one <= 1'b0;
					MUL_load_two <= 1'b1; // load 2 muls
					MUL_load_one <= 1'b0;
					RF_new_instr <= 1'b1;
					new_mul_a <= 1'b1;
					new_mul_b <= 1'b1;	// both are multiply
					new_branch <= 1'b0;
				end
				
				default: begin
					// turn all off
					RAT_ready <= 1'b1;
					ADD_load_two <= 1'b0;
					ADD_load_one <= 1'b0;
					MUL_load_two <= 1'b0;
					MUL_load_one <= 1'b0;
					RF_new_instr <= 1'b0;
					new_branch <= 1'b0;
				end
			
			endcase
		end else begin
			//$display("RAT: dispatch ready 1 and 2 are off");
			RAT_ready <= 1'b1; // set RAT as ready
			ADD_load_two <= 1'b0;
			ADD_load_one <= 1'b0;
			MUL_load_two <= 1'b0;
			MUL_load_one <= 1'b0;
			RF_new_instr <= 1'b0;
			print_table <= 0;
			new_branch <= 1'b0;
		end
	
	end
	
	always @(negedge ROB_bus_trigger) begin
		@(posedge clk);
		@(posedge clk);
		$display("Current Register File (RF) and Mapping Table (MT)");
		for (int i = 1; i < 8; i++) begin
			$display("Reg: %d		(MT) Valid: %b		(RF) Value: %d", RA_table[i].register_id, mapping_table[i].valid, RA_table[i].value);
		end
		if (RA_table[4].value == 32'd30) $stop;
		//$stop;
		print_table <= 0;
		
	end

	
	// listen on ROB broadcast bus
	always @(posedge ROB_bus_trigger) begin
		if (ROB_bus_trigger && !ROB_exception_flush) begin
			$display("RAT: ROB bus update received");
			// iterate through the table
			for (int i = 1; i < 8; i++) begin
				// if this is a valid translation and if the tag matches the broadcasted tag
				if (mapping_table[i].valid && mapping_table[i].tag_rob_entry === ROB_bus_tag) begin
					// tag matches, update the value
					//$display("RAT: ROB bus update -> Reg %d now has the value %d", i, ROB_bus_value);
					mapping_table[i].valid = 1'b0; // invalidate the translation because data is now present
					mapping_table[i].tag_rob_entry = 3'bz; // nullify the tag
					RA_table[mapping_table[i].reg_id].value = ROB_bus_value; // update the value
					break; // end loop once found
				end
			end // end for loop
			
			print_table <= 1;
			
		end
		else if (ROB_bus_trigger && ROB_exception_flush) begin
			$display("RAT: Flushing -> Restoring Mappings");
			// iterate through the table
			for (int i = 1; i < 8; i++) begin
				// if this is a valid translation and if the tag matches the broadcasted tag
				if (mapping_table[i].valid && mapping_table[i].tag_rob_entry >= ROB_bus_tag) begin
					// tag matches, restore mapping
					
					mapping_table[i].valid = 1'b0; // invalidate the translation because data is now present
					mapping_table[i].tag_rob_entry = 3'bz; // nullify the tag
				end
			end // end for loop
			
			print_table <= 1;
			
		end
	end // end always @ ADDbus trigger
	

endmodule


// instruction queue
module instruction_queue (
	input logic clk, reset,
	// input new instructions to queue
	input logic [31:0] new_instr,
	
	input logic write_en, read_en1, read_en2,
	
	// outputs to dispatch unit
	output logic [31:0] odd_instr, // I1, I3, I5 ...
	output logic [31:0] even_instr, // I2, I4, I6 ...
	output logic result_ready
);

	// IMPLEMENTING INSTR QUEUE AS SYNCHRONOUS FIFO
	// RAM Implementation
	logic [31:0] fifo_ram [15:0];
	
	// read and write pointers
	logic [3:0] read_ptr, write_ptr;
	
	// some internal logic signals
	logic full_flg, empty_flg;
	logic [3:0] fifo_cntr;
	
	logic read_en;
	assign read_en = read_en1 && read_en2; // only issue 2 at a time
	
	// write
	always @(posedge clk) begin
		if (reset) begin
			write_ptr <= 0;
			// pre-load the instructions
			fifo_ram[0] <= 32'b0000001_00010_00001_000_00011_0110011;
			fifo_ram[1] <= 32'b0000000_00110_00100_000_00101_0110011;
			//fifo_ram[1] <= 32'b0000000_00001_00110_000_00110_0110011;		// ADD R6, R6, R1
			//fifo_ram[2] <= 32'b0000000_00010_00110_000_00111_0110011;
			fifo_ram[2] <= 32'b0000000_00010_00110_000_00111_1100011;		// BEQ R7, R2, R6
			fifo_ram[3] <= 32'b0000000_00001_00010_000_00100_0110011;
			//fifo_ram[4] <= 32'b0000001_00101_00010_000_00110_0110011;
			//fifo_ram[5] <= 32'b0000000_00010_00001_000_00010_0110011;
			$display("ALL INSTRUCTIONS PRE-LOADED");
		end else if (write_en && !full_flg) begin
			write_ptr <= write_ptr + 1'b1;
			fifo_ram[write_ptr] <= new_instr;
			$display("Loaded instruction: %b", new_instr);
		end
	end
	
	// read - OUTPUTS TWO INSTR AT A TIME (ODD & EVEN)
	always @(posedge clk) begin
		if (reset) begin
			read_ptr <= 0;
			result_ready <= 0;
		end
		else if (read_en && !empty_flg) begin
			read_ptr <= read_ptr + 2;
			odd_instr <= fifo_ram[read_ptr];
			//$display("Sent instruction: %b", fifo_ram[read_ptr]);
			if (read_ptr < 4'b1111) begin // check that there is another instruction to read, then read it into "odd_instr"
				//read_ptr <= read_ptr + 1'b1;
				even_instr <= fifo_ram[read_ptr+1];
				//$display("Sent instruction: %b", fifo_ram[read_ptr+1]);
			end
			result_ready <= 1;
		end else begin
			result_ready <= 0;
		end
	end
	
	// counter logic
	always @(posedge clk) begin
		if (reset)
			fifo_cntr <= 6;
		else
			begin
				if ((!read_en && !write_en) || (read_en && write_en))
					fifo_cntr <= fifo_cntr;
				else if (read_en && !write_en) begin
					if (fifo_cntr != 0)
						fifo_cntr <= fifo_cntr - 1'b1;
				end
				else if(!read_en && write_en) begin
					if (fifo_cntr != 4'b0110)
						fifo_cntr <= fifo_cntr + 1'b1;
				end
		end
	end
	
	// empty and full flag logic
	assign empty_flg = (!fifo_cntr) ? 1'b1 : 1'b0;
	assign full_flg = (fifo_cntr === 4'b1111) ? 1'b1 : 1'b0;



endmodule

