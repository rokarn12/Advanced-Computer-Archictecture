// Rojan Karn - Reservation Stations for Superscalar OoO

// reservation stations - physical register files
// 1 for adder, 1 for multiplier
module mul_rs (
	input clk, reset,
	// input from functional unit
	input logic mul_ready,
	
	// inputs from RAT
	// first instruction input to multiplier RS
	input logic load_one, load_two,
	input logic [2:0] src1a_tag, src2a_tag,
	input logic [31:0] src1a_val, src2a_val,
	input logic src1a_valid, src2a_valid,
	input logic [2:0] a_RSID,
	
	// second instruction input to multiplier RS
	input logic [2:0] src1b_tag, src2b_tag,
	input logic [31:0] src1b_val, src2b_val,
	input logic src1b_valid, src2b_valid,
	input logic [2:0] b_RSID,
	
	// notify FU to execute operations
	output logic valid_instr,
	output logic [31:0] op1, op2,
	output logic [2:0] tag_out,
	
	// output to dispatch units
	output logic [3:0] avail_IDs, // indicates which ID is available for renaming
	// input from bus
	input logic ROB_bus_trigger,
	input logic ROB_exception_flush,
	input logic [2:0] ROB_bus_tag,
	input logic [31:0] ROB_bus_value
);

	typedef struct {
		logic valid; // 1 or 0
		logic [2:0] tag; // a, b, c, d, x, y, z, k
		logic [31:0] value; // actual value assigned to register
	} rs_source;

	typedef struct {
		logic [2:0] ID; // x, y, z, k
		rs_source src[1:0]; // source 1 and source 2
		
		// for ROB stuff - does RS need to store tag of ROB entry?
		logic [2:0] tag_rob;
		
	} rs_line;
	
	rs_line res_station[4];
	
	// Initialize Reservation Station
	initial begin
		// IDs: x (100), y (101), z (110), k (111)
		res_station[0].ID = 3'b100; // x
		res_station[1].ID = 3'b101; // y
		res_station[2].ID = 3'b110; // z
		res_station[3].ID = 3'b111; // k
	
		// Initialize according to OoO Machine Simulation in slides
		for (int i = 0; i < 4; i++) begin
			res_station[i].src[0].valid = 1'b0;
			res_station[i].src[1].valid = 1'b0;
			res_station[i].src[0].tag = 3'bz;
			res_station[i].src[1].tag = 3'bz;
			res_station[i].src[0].value = 32'b0;
			res_station[i].src[1].value = 32'b0;
		end
		// Reservation Station initialized for Multiplier
		
	end
	
	
	// Assign the "available IDs" output to indicate to dispatch units which resources are available
	// INVALID and TAG = 0 indicates that the spot is available
	// x
	assign avail_IDs[3] = !res_station[0].src[0].valid && !res_station[0].src[1].valid &&
								 res_station[0].src[0].tag === 3'bz && res_station[0].src[1].tag === 3'bz;
	// y
	assign avail_IDs[2] = !res_station[1].src[0].valid && !res_station[1].src[1].valid &&
								 res_station[1].src[0].tag === 3'bz && res_station[1].src[1].tag === 3'bz;		 
	// z
	assign avail_IDs[1] = !res_station[2].src[0].valid && !res_station[2].src[1].valid &&
								 res_station[2].src[0].tag === 3'bz && res_station[2].src[1].tag === 3'bz;
	// k
	assign avail_IDs[0] = !res_station[3].src[0].valid && !res_station[3].src[1].valid &&
								 res_station[3].src[0].tag === 3'bz && res_station[3].src[1].tag === 3'bz;
	
	logic [1:0] a_index, b_index;
	
	// pointers to next available entry in RS
	assign a_index = avail_IDs[3] ? 2'd0 : (avail_IDs[2] ? 2'd1 : (avail_IDs[1] ? 2'd2 : (avail_IDs[0] ? 2'd3 : 2'bz)));
	assign b_index = a_index + 2'd1;			// does this need its own logic?

	// if a new instruction incoming from Register Alias Table
	always @(posedge clk) begin
		// set the valid, tag, and value fields for each source from the instruction

		if (load_two) begin
			$display("MUL RS: loading 2 instructions from RAT");
			// load both a and b stuff
			
			// get the a_instr ROB entry tag
			res_station[a_index].tag_rob <= a_RSID;
			// src1a
			res_station[a_index].src[0].valid <= src1a_valid;
			res_station[a_index].src[0].value <= src1a_val;
			res_station[a_index].src[0].tag <= src1a_tag;
			// src2a
			res_station[a_index].src[1].valid <= src2a_valid;
			res_station[a_index].src[1].value <= src2a_val;
			res_station[a_index].src[1].tag <= src2a_tag;
			
			// get the a_instr ROB entry tag
			res_station[b_index].tag_rob <= b_RSID;
			// src1b
			res_station[b_index].src[0].valid <= src1b_valid;
			res_station[b_index].src[0].value <= src1b_val;
			res_station[b_index].src[0].tag <= src1b_tag;
			// src2b
			res_station[b_index].src[1].valid <= src2b_valid;
			res_station[b_index].src[1].value <= src2b_val;
			res_station[b_index].src[1].tag <= src2b_tag;
			
		end else if (load_one) begin
			$display("MUL RS: loading 1 instruction from RAT");
			// load only a stuff
			// get the a_instr ROB entry tag
			res_station[a_index].tag_rob <= a_RSID;
			// src1a
			res_station[a_index].src[0].valid <= src1a_valid;
			res_station[a_index].src[0].value <= src1a_val;
			res_station[a_index].src[0].tag <= src1a_tag;
			// src2a
			res_station[a_index].src[1].valid <= src2a_valid;
			res_station[a_index].src[1].value <= src2a_val;
			res_station[a_index].src[1].tag <= src2a_tag;
			
		end // end load_two/load_one
		else begin
			//valid_instr <= 1'b0;
			// check for the next spot in the RS whose sources are both valid
			for (int i = 0; i < 4; i++) begin
				if (res_station[i].src[0].valid && res_station[i].src[1].valid && mul_ready) begin
					$display("MUL RS: sending values to FU for execution: tag: %d	op1: %d	op2: %d", res_station[i].tag_rob, res_station[i].src[0].value, res_station[i].src[1].value);
					// set outputs for FU to execute
					tag_out <= res_station[i].tag_rob;
					op1 <= res_station[i].src[0].value;
					op2 <= res_station[i].src[1].value;
					valid_instr <= 1'b1;
					
					// clear this entry of the RS
					res_station[i].src[0].valid = 1'b0;
					res_station[i].src[1].valid = 1'b0;
					res_station[i].src[0].tag = 3'bz;
					res_station[i].src[1].tag = 3'bz;
					res_station[i].src[0].value = 32'b0;
					res_station[i].src[1].value = 32'b0;
					break;
				end // end if
				else if (i == 3) begin
					valid_instr <= 1'b0;
				
				end
			end // end for loop
		end
	
	end // end always @ clk or bus_trigger
	

	// reading ROB bus logic
	always @(posedge ROB_bus_trigger) begin
	
		if (ROB_bus_trigger && !ROB_exception_flush) begin
			$display("MUL RS: ROB bus update received");
			// iterate through each of the 4
			// check if a source is invalid and tags match
			for (int i = 0; i < 4; i++) begin
				if (!res_station[i].src[0].valid && res_station[i].src[0].tag === ROB_bus_tag) begin
					// source 1 matches, set the new value
					res_station[i].src[0].value <= ROB_bus_value;
					
				end else if (!res_station[i].src[1].valid && res_station[i].src[1].tag === ROB_bus_tag) begin
					// source 2 matches, set the new value
					res_station[i].src[1].value <= ROB_bus_value;
					
				end // end ifs
			end // end for loop
		end // end if ROB_bus_trigger
		else if (ROB_bus_trigger && ROB_exception_flush) begin
			$display("MUL RS: Flushing");
			// iterate through each of the 4
			for (int i = 0; i < 4; i++) begin
				// if the tag is greater than the head pointer, flush
				if (res_station[i].tag_rob > ROB_bus_tag) begin
					// clear this entry of the RS
					res_station[i].src[0].valid = 1'b0;
					res_station[i].src[1].valid = 1'b0;
					res_station[i].src[0].tag = 3'bz;
					res_station[i].src[1].tag = 3'bz;
					res_station[i].src[0].value = 32'b0;
					res_station[i].src[1].value = 32'b0;
				end
			end // end for loop
		end // end if ROB_bus_trigger
	
	end // end always @ ROB bus trigger


endmodule


// ADDER RESERVATION STATION
module adder_rs (
	input clk, reset,
	// input from functional unit
	input logic adder_ready,
	
	// inputs from RAT
	// first instruction input to multiplier RS
	input logic load_one, load_two,
	input logic [2:0] src1a_tag, src2a_tag,
	input logic [31:0] src1a_val, src2a_val,
	input logic src1a_valid, src2a_valid,
	input logic [2:0] a_RSID,
	
	// second instruction input to multiplier RS
	input logic [2:0] src1b_tag, src2b_tag,
	input logic [31:0] src1b_val, src2b_val,
	input logic src1b_valid, src2b_valid,
	input logic [2:0] b_RSID,
	
	// notify FU to execute operations
	output logic valid_instr,
	output logic [31:0] op1, op2,
	output logic [2:0] tag_out,
	
	// output to dispatch units
	output logic [3:0] avail_IDs, // indicates which ID is available for renaming
	// input from bus
	input logic ROB_bus_trigger,
	input logic ROB_exception_flush,
	input logic [2:0] ROB_bus_tag,
	input logic [31:0] ROB_bus_value
);

	typedef struct {
		logic valid; // 1 or 0
		logic [2:0] tag; // a, b, c, d, x, y, z, k
		logic [31:0] value; // actual value assigned to register
	} rs_source;

	typedef struct {
		logic [2:0] ID; // a, b, c, d
		rs_source src[1:0]; // source 1 and source 2
		
		logic [2:0] tag_rob;
	} rs_line;
	
	rs_line res_station[4];
	
	// Initialize Reservation Station
	initial begin
		// IDs: a (000), b (001), c (010), d (011)
		res_station[0].ID = 3'b000; // a
		res_station[1].ID = 3'b001; // b
		res_station[2].ID = 3'b010; // c
		res_station[3].ID = 3'b011; // d
	
		// Initialize according to OoO Machine Simulation in slides
		for (int i = 0; i < 4; i++) begin
			res_station[i].src[0].valid = 1'b0;
			res_station[i].src[1].valid = 1'b0;
			res_station[i].src[0].tag = 3'bz;
			res_station[i].src[1].tag = 3'bz;
			res_station[i].src[0].value = 32'b0;
			res_station[i].src[1].value = 32'b0;
			//avail_IDs[i] = 1'b1;
		end
		// Reservation Station initialized for Adder
		
	end
	
	
	// Assign the "available IDs" output to indicate to dispatch units which resources are available
	// INVALID and TAG = 0 indicates that the spot is available
	// a
	assign avail_IDs[3] = (!res_station[0].src[0].valid) && (!res_station[0].src[1].valid) &&
								 (res_station[0].src[0].tag === 3'bz) && (res_station[0].src[1].tag === 3'bz);
	// b
	assign avail_IDs[2] = !res_station[1].src[0].valid && !res_station[1].src[1].valid &&
								 res_station[1].src[0].tag === 3'bz && res_station[1].src[1].tag === 3'bz;		 
	// c
	assign avail_IDs[1] = !res_station[2].src[0].valid && !res_station[2].src[1].valid &&
								 res_station[2].src[0].tag === 3'bz && res_station[2].src[1].tag === 3'bz;
	// d
	assign avail_IDs[0] = !res_station[3].src[0].valid && !res_station[3].src[1].valid &&
								 res_station[3].src[0].tag === 3'bz && res_station[3].src[1].tag === 3'bz;
								 
	logic [1:0] a_index, b_index;
	
	assign a_index = avail_IDs[3] ? 2'd0 : (avail_IDs[2] ? 2'd1 : (avail_IDs[1] ? 2'd2 : (avail_IDs[0] ? 2'd3 : 2'bz)));
	assign b_index = a_index + 1;			// does this need its own logic?
	
	// NEED "NEXT AVAILABLE" POINTERS FOR RESERVATION STATION ENTRIES
	
	// if a new instruction incoming from Register Alias Table
	always @(posedge clk) begin
		// set the valid, tag, and value fields for each source from the instruction
		
		if (load_two) begin
			$display("ADD RS: loading 2 instructions from RAT");
			// load both a and b stuff
			res_station[a_index].tag_rob <= a_RSID;
			// src1a
			res_station[a_index].src[0].valid <= src1a_valid;		// a_RSID -> a_index
			res_station[a_index].src[0].value <= src1a_val;
			res_station[a_index].src[0].tag <= src1a_tag;
			// src2a
			res_station[a_index].src[1].valid <= src2a_valid;
			res_station[a_index].src[1].value <= src2a_val;
			res_station[a_index].src[1].tag <= src2a_tag;
			
			res_station[b_index].tag_rob <= b_RSID;
			// src1b
			res_station[b_index].src[0].valid <= src1b_valid;
			res_station[b_index].src[0].value <= src1b_val;
			res_station[b_index].src[0].tag <= src1b_tag;
			// src2b
			res_station[b_index].src[1].valid <= src2b_valid;
			res_station[b_index].src[1].value <= src2b_val;
			res_station[b_index].src[1].tag <= src2b_tag;
			
		end else if (load_one) begin
			$display("ADD RS: loading 1 instruction from RAT.	S1 val: %d	S2 val: %d", src1a_val, src2a_val);
			// load only a stuff
			res_station[a_index].tag_rob <= a_RSID;
			// src1a
			res_station[a_index].src[0].valid <= src1a_valid;
			res_station[a_index].src[0].value <= src1a_val;
			res_station[a_index].src[0].tag <= src1a_tag;
			// src2a
			res_station[a_index].src[1].valid <= src2a_valid;
			res_station[a_index].src[1].value <= src2a_val;
			res_station[a_index].src[1].tag <= src2a_tag;
			
		end // end load_two/load_one
		else begin
			//valid_instr <= 1'b0;
			// check for the next spot in the RS whose sources are both valid
			for (int i = 0; i < 4; i++) begin
				//$display("ADD RS: Src0 Valid: %b		Src1 Valid: %b		adder_ready: %b", res_station[i].src[0].valid, res_station[i].src[1].valid, adder_ready);
				if (res_station[i].src[0].valid && res_station[i].src[1].valid && adder_ready) begin
					$display("ADD RS: sending values to FU for execution: tag: %d	op1: %d	op2: %d", res_station[i].tag_rob, res_station[i].src[0].value, res_station[i].src[1].value);
					// set outputs for FU to execute
					tag_out <= res_station[i].tag_rob;
					op1 <= res_station[i].src[0].value;
					op2 <= res_station[i].src[1].value;
					valid_instr <= 1'b1;
					
					// clear this entry of the RS
					res_station[i].src[0].valid = 1'b0;
					res_station[i].src[1].valid = 1'b0;
					res_station[i].src[0].tag = 3'bz;
					res_station[i].src[1].tag = 3'bz;
					res_station[i].src[0].value = 32'b0;
					res_station[i].src[1].value = 32'b0;
					break;
				end else if (i == 3) begin	// reached last entry of RS
					valid_instr <= 1'b0;
				
				end

			end // end for loop

		end
	end // end always @ clk or bus_trigger
	
	
	// reading ROB bus logic
	always @(posedge ROB_bus_trigger) begin
	
		if (ROB_bus_trigger && !ROB_exception_flush) begin
			$display("ADD RS: ROB bus update received");
			// iterate through each of the 4
			// check if a source is invalid and tags match
			for (int i = 0; i < 4; i++) begin
				if (!res_station[i].src[0].valid && res_station[i].src[0].tag === ROB_bus_tag) begin
					// source 1 matches, set the new value
					res_station[i].src[0].value <= ROB_bus_value;
					
				end else if (!res_station[i].src[1].valid && res_station[i].src[1].tag === ROB_bus_tag) begin
					// source 2 matches, set the new value
					res_station[i].src[1].value <= ROB_bus_value;
					
				end // end ifs
			end // end for loop
		end // end if ROB_bus_trigger
		else if (ROB_bus_trigger && ROB_exception_flush) begin
			$display("ADD RS: Flushing");
			// iterate through each of the 4
			for (int i = 0; i < 4; i++) begin
				// if the tag is greater than the head pointer, flush
				if (res_station[i].tag_rob > ROB_bus_tag) begin
					// clear this entry of the RS
					res_station[i].src[0].valid = 1'b0;
					res_station[i].src[1].valid = 1'b0;
					res_station[i].src[0].tag = 3'bz;
					res_station[i].src[1].tag = 3'bz;
					res_station[i].src[0].value = 32'b0;
					res_station[i].src[1].value = 32'b0;
				end
			end // end for loop
		end // end if ROB_bus_trigger
	
	end // end always @ ROB bus trigger

endmodule
