`timescale 1ns/10ps
// architectural register files
// don't need load/store buffers
// parameter for priority
module dispatch_unit #(parameter logic priorityDU = 1'b0) (
	input logic clk, reset,
	
	// request instruction from instruction queue
	output logic iq_read_en,
	
	// inputs from instruction queue
	input logic [31:0] instr_in,
	input logic result_ready,
	
	// inputs from RSs
	input logic [3:0] ADD_avail_IDs,
	input logic [3:0] MUL_avail_IDs,
	
	// outputs to Register Alias Table
	output logic dispatch_ready,
	output logic [2:0] rd, rs1, rs2,
	output logic multiply,
	output logic [2:0] renamed_tag,
	
	// communication between 2 dispatch units
	// inputs from other DU
	input logic multiply_in,
	input logic [2:0] rd_in, rs1_in, rs2_in,
	
	// outputs to other DU
	output logic multiply_out,
	output logic [2:0] rd_out, rs1_out, rs2_out,
	
	// input from RAT indicating if it is ready
	input logic RAT_ready,
	
	// input from ROB
	input logic [2:0] next_available
);

	// check priority, if 1 and RAW hazard, then send tag to other DU
	// other DU will wait for tag to be sent, then rename register
	
	// internal logic
	logic ADD_one_spot_avail, ADD_two_spots_avail;
	logic MUL_one_spot_avail, MUL_two_spots_avail;
	
	// checks that there is at least one spot available in the RS
	assign ADD_one_spot_avail = ADD_avail_IDs[3] || ADD_avail_IDs[2] || ADD_avail_IDs[1] || ADD_avail_IDs[0];
	assign MUL_one_spot_avail = MUL_avail_IDs[3] || MUL_avail_IDs[2] || MUL_avail_IDs[1] || MUL_avail_IDs[0];
	
	// checks that there are at least two spots available in the RS
	assign ADD_two_spots_avail = (ADD_avail_IDs[3] && ADD_avail_IDs[2]) || (ADD_avail_IDs[3] && ADD_avail_IDs[1]) ||
											(ADD_avail_IDs[3] && ADD_avail_IDs[0]) || (ADD_avail_IDs[0] && ADD_avail_IDs[1]) ||
											(ADD_avail_IDs[0] && ADD_avail_IDs[2]) || (ADD_avail_IDs[1] && ADD_avail_IDs[2]);
											
	assign MUL_two_spots_avail = (MUL_avail_IDs[3] && MUL_avail_IDs[2]) || (MUL_avail_IDs[3] && MUL_avail_IDs[1]) ||
											(MUL_avail_IDs[3] && MUL_avail_IDs[0]) || (MUL_avail_IDs[0] && MUL_avail_IDs[1]) ||
											(MUL_avail_IDs[0] && MUL_avail_IDs[2]) || (MUL_avail_IDs[1] && MUL_avail_IDs[2]);
	
	logic [31:0] curr_instr;
	logic in_process, proc_complete; // use proc_complete to reset the in_process signal
	
	logic [2:0] num_instr;
	
	logic already_dispatched;
	
	// read new instruction logic
	always @(posedge clk) begin
		if (reset) begin
			iq_read_en <= 1'b0;
			in_process <= 1'b0;
			curr_instr <= 32'b0;
			//proc_complete <= 1'b1;
			//already_dispatched <= 1'b0;
			num_instr <= 3'b0;
			$display("Dispatch unit in reset");
		end else if (!in_process) begin
			//$display("Setting iq_read_en");
			if (num_instr < 3'b010) begin
				iq_read_en <= 1'b1; // request a new instruction from the IQ
				in_process <= 1'b1; // indicate that the DU is processing
				num_instr <= num_instr + 2;
				//already_dispatched <= 1'b0;
			end else begin
				iq_read_en <= 1'b0;
				//in_process <= 1'b0;
			end
		end else begin
			iq_read_en <= 1'b0; // don't read a new instruction
		end
		
		if (result_ready) begin
			curr_instr <= instr_in; // read the incoming instruction
			//#10;
			if (num_instr < 3'b101) begin
				if (priorityDU) $display("DU1: Received instruction: %b", instr_in);
				else $display("DU2: Received instruction: %b", instr_in);
			end
		end
		
		if (proc_complete) begin
			in_process <= 1'b0; // reset in_process signal so that a new instruction can be read
		end
		
		// check if the instruction is add or multiply
		if (curr_instr[6:0] == 7'b0110011 && curr_instr[31:25] == 7'b0000000 && curr_instr[14:12] == 3'b000) begin
			// ADD instruction
			multiply <= 1'b0;
			multiply_out <= 1'b0;
		end else if (curr_instr[6:0] == 7'b0110011 && curr_instr[31:25] == 7'b0000001 && curr_instr[14:12] == 3'b000) begin
			// MULTIPLY instruction
			multiply <= 1'b1;
			multiply_out <= 1'b1;
		end else begin
			// NOP instruction, stall
			multiply <= 1'bz;				// multiply == 1'bz means NOP
			multiply_out <= 1'bz;
		end
	
	end // end read new instruction logic
	
	// extract information from the instruction
	assign rs1 = curr_instr[19:15];
	assign rs2 = curr_instr[24:20];
	assign rd = curr_instr[11:7];
	
	// send to other DU
	assign rs1_out = curr_instr[19:15];
	assign rs2_out = curr_instr[24:20];
	assign rd_out = curr_instr[11:7];
				
	// check structural hazard
	// make sure that there is available space for instructions
	
	logic mul;
	assign mul = multiply;
	
	// ROB renaming
	// gets whatever the "tail" pointer is pointing at
	
	/////////////////////////////	COME BACK HERE
	
	// first check the types of instructions for both dispatch units
	always @(posedge clk) begin
		// reset dispatch ready signal
		
		if (reset) begin
			dispatch_ready <= 1'b0;
			proc_complete <= 1'b0;
		
		end
		
		//if (!priorityDU) $display("DU2: this mul: %b	multiply_in: %b", mul, multiply_in);
		else if (RAT_ready && !already_dispatched) begin
		
			// RENAMING LOGIC
			// dont need to rename to RS ID anymore
			// instead, rename to next available ROB entries
			
			// operation type does not matter
			
			// check that there are two spots available in the corresponding RSs
			// check for this operation and other operation
			case ({mul, multiply_in})

				// both are add
				2'b00: begin
					// check if 2 spots available in add RS
					if (ADD_two_spots_avail) begin
						// 2 spots are available, dispatch the instr
						
						if (priorityDU) begin
							renamed_tag <= next_available;
						end else begin
							renamed_tag <= next_available + 1;
						end
						
						dispatch_ready <= 1'b1;
						proc_complete <= 1'b1;
						already_dispatched <= 1'b1;
						
//						// find tag to rename rd
//						case (ADD_avail_IDs)
//							
//							// c and d are available
//							4'b0011: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b010; // c
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b011; // d
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// b and d are available
//							4'b0101: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b001; // b
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b011; // d
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// b and c are available
//							4'b0110: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b001; // b
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b010; // c
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// a and d are available
//							4'b1001: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b000; // a
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b011; // d
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// a and c are available
//							4'b1010: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b000; // a
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b010; // c
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// a and b are available
//							4'b1100: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b000; // a
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b001; // b
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// default
//							default: begin
//								renamed_tag <= 3'b0;
//								dispatch_ready <= 1'b0;
//								proc_complete <= 1'b0;
//							end
//						
//						endcase // end 2 spots avail case statement
					
					end // end add 2 spots avail
					else begin
						renamed_tag <= 3'b0;
						dispatch_ready <= 1'b0; // outputs are NOT sent to RAT
						proc_complete <= 1'b0;
					end
				end
				
				// this is add, other is mul
				2'b01: begin
					// check if 1 spot available in each RS
					if (ADD_one_spot_avail && MUL_one_spot_avail) begin
						// spots available for both instructions
						
						if (priorityDU) begin
							renamed_tag <= next_available;
						end else begin
							renamed_tag <= next_available + 1;
						end
						
						dispatch_ready <= 1'b1;
						proc_complete <= 1'b1;
						already_dispatched <= 1'b1;
						
//						// no "priority" logic needed, find rename tag
//						if (priorityDU) $display("This is add, other is mul");
//						// rename tag for ADD
//						if (ADD_avail_IDs[3] && !mul) renamed_tag <= 3'b000; // a
//						else if (ADD_avail_IDs[2] && !mul) renamed_tag <= 3'b001; // b
//						else if (ADD_avail_IDs[1] && !mul) renamed_tag <= 3'b010; // c
//						else if (ADD_avail_IDs[0] && !mul) renamed_tag <= 3'b011; // d
//						
//						// rename tag for MUL
//						if (MUL_avail_IDs[3] && mul) renamed_tag <= 3'b100; // x
//						else if (MUL_avail_IDs[2] && mul) renamed_tag <= 3'b101; // y
//						else if (MUL_avail_IDs[1] && mul) renamed_tag <= 3'b110; // z
//						else if (MUL_avail_IDs[0] && mul) renamed_tag <= 3'b111; // k
//						
//						//if (priorityDU) $display("DU1: dispatch ready");
//						//else $display("DU2: dispatch ready");
//						dispatch_ready <= 1'b1; // outputs are sent to RAT
//						proc_complete <= 1'b1;
//						already_dispatched <= 1'b1;
					
					end
					else begin
						renamed_tag <= 3'b0;
						dispatch_ready <= 1'b0; // outputs are NOT sent to RAT
						proc_complete <= 1'b0;
					end
				end
				
				// other is add, this is mul
				2'b10: begin
					// check if 1 spot available in each RS
					if (ADD_one_spot_avail && MUL_one_spot_avail) begin
						// spots available for both instructions
						
						if (priorityDU) begin
							renamed_tag <= next_available;
						end else begin
							renamed_tag <= next_available + 1;
						end
						
						dispatch_ready <= 1'b1;
						proc_complete <= 1'b1;
						already_dispatched <= 1'b1;
						
//						// no "priority" logic needed, find rename tag
//						if (priorityDU) $display("This is mul, other is add");
//						// rename tag for ADD
//						if (ADD_avail_IDs[3] && !mul) renamed_tag <= 3'b000; // a
//						else if (ADD_avail_IDs[2] && !mul) renamed_tag <= 3'b001; // b
//						else if (ADD_avail_IDs[1] && !mul) renamed_tag <= 3'b010; // c
//						else if (ADD_avail_IDs[0] && !mul) renamed_tag <= 3'b011; // d
//						
//						// rename tag for MUL
//						if (MUL_avail_IDs[3] && mul) renamed_tag <= 3'b100; // x
//						else if (MUL_avail_IDs[2] && mul) renamed_tag <= 3'b101; // y
//						else if (MUL_avail_IDs[1] && mul) renamed_tag <= 3'b110; // z
//						else if (MUL_avail_IDs[0] && mul) renamed_tag <= 3'b111; // k
//						
//						//if (priorityDU) $display("DU1: dispatch ready");
//						//else $display("DU2: dispatch ready");
//						dispatch_ready <= 1'b1; // outputs are sent to RAT
//						proc_complete <= 1'b1;
//						already_dispatched <= 1'b1;
					end
					else begin
						renamed_tag <= 3'b0;
						dispatch_ready <= 1'b0; // outputs are NOT sent to RAT
						proc_complete <= 1'b0;
					end
				end
				
				// both are mul
				2'b11: begin
					// check if 2 spots available in mul RS
					if (MUL_two_spots_avail) begin
						
						if (priorityDU) begin
							renamed_tag <= next_available;
						end else begin
							renamed_tag <= next_available + 1;
						end
						
						dispatch_ready <= 1'b1;
						proc_complete <= 1'b1;
						already_dispatched <= 1'b1;
						
//						// find tag to rename rd
//						case (MUL_avail_IDs)
//							
//							// z and k are available
//							4'b0011: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b110; // z
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b111; // k
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//								already_dispatched <= 1'b1;
//							end
//							
//							// y and k are available
//							4'b0101: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b101; // y
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b111; // k
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//							end
//							
//							// y and z are available
//							4'b0110: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b101; // y
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b110; // z
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//							end
//							
//							// x and k are available
//							4'b1001: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b100; // x
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b111; // k
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//							end
//							
//							// x and z are available
//							4'b1010: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b100; // x
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b110; // z
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//							end
//							
//							// x and y are available
//							4'b1100: begin
//								// if this is the priority DU, it gets the first available spot
//								if (priorityDU) begin
//									renamed_tag <= 3'b100; // x
//								end else begin // if not priority, get the second available spot
//									renamed_tag <= 3'b101; // y
//								end
//								
//								dispatch_ready <= 1'b1; // outputs are sent to RAT
//								proc_complete <= 1'b1;
//							end
//						
//						
//						endcase // end 2 spots avail case statement
					
					end // end add 2 spots avail
					else begin
						renamed_tag <= 3'bz;
						dispatch_ready <= 1'b0; // outputs are NOT sent to RAT
						proc_complete <= 1'b0;
					end
				end
				
				// NOP
				2'bzx: begin
					// one or both of the DUs have a NOP
					dispatch_ready <= 1'b0; // stall
				end
				
				// NOP
				2'bxz: begin
					// one or both of the DUs have a NOP
					dispatch_ready <= 1'b0; // stall
				end
				
				default: begin
					already_dispatched <= 1'b0;
					renamed_tag <= 3'bz;
					dispatch_ready <= 1'b0; // outputs are NOT sent to RAT
					proc_complete <= 1'b0;
				end
			
			
			endcase
	
		end // end if RAT_ready
		else begin
			dispatch_ready <= 1'b0;
			proc_complete <= 1'b0;
		end
	
	end
	

endmodule
