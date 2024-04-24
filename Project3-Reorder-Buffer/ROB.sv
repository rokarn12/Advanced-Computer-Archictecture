// Reorder Buffer Module

module ROB (input logic clk, reset,

				// inputs from ADD FU
				input logic ADD_FU_valid,
				input logic [2:0] ADD_FU_tag,
				input logic [31:0] ADD_FU_value,
				
				
				// inputs from MUL FU
				input logic MUL_FU_valid,
				input logic [2:0] MUL_FU_tag,
				input logic [31:0] MUL_FU_value,
				
				// inputs from RAT
				input logic RAT_new_instr,								// listen to RAT signals
				input logic new_mul_a, new_mul_b,										// opcode
				input logic [2:0] rd_a, rd_b,
				input logic [2:0] src1a, src2a, src1b, src2b,
				input logic src1a_valid, src2a_valid, src1b_valid, src2b_valid,
				
				// outputs to DU
				// for renaming
				output logic [2:0] next_available,
				
				// broadcast to RS and RF logic
				output logic ROB_bus_trigger,
				output logic ROB_exception_flush,
				output logic [2:0] ROB_bus_tag,
				output logic [31:0] ROB_bus_value,
				
				// inputs from BRANCH FU
				input logic branch_update,
				input logic branch_mispredict,
				input logic [2:0] branch_tag

);

	typedef struct {
		// NEED TO CHANGE BIT WIDTHS ON SOME OF THESE
		logic [2:0] tag;
		logic busy;
		logic exec;
		logic op;	// opcode: 1 is MUL, 0 is ADD			-- may need to add another bit for "branch" instructions
		logic V1;	// valid ?
		logic [31:0] src1;
		logic V2;	// valid ?
		logic [31:0] src2;
		logic [2:0] destReg;	// destination architectural reg
		logic [31:0] value;	// last destination physical reg - last committed value of Rd register
		logic exception;
	
	} rob_line;
	
	rob_line reorder_buff[8];

	
	initial begin
		// initialize the reorder buffer
		for (int i = 0; i < 8; i++) begin
			reorder_buff[i].tag = i;			// tag should be the same as the index
			reorder_buff[i].busy = 0;
			reorder_buff[i].exec = 0;
			reorder_buff[i].op = 0;
			reorder_buff[i].V1 = 0;
			reorder_buff[i].src1 = 32'bz;		// nullify sources instead of setting to zero
			reorder_buff[i].V2 = 0;
			reorder_buff[i].src2 = 32'bz;
			reorder_buff[i].destReg = 0;
			reorder_buff[i].value = 0;
			reorder_buff[i].exception = 0;
		end
	
	end // end initial

	// RAT will send instruction information
	
	
	// head and tail pointers
	logic [2:0] head_ptr, tail_ptr;
	
	// HEAD: next to execute
	// TAIL: next available spot in ROB
	
	// ROB should make the tail_ptr available to the dispatch unit
	assign next_available = tail_ptr;
	
	// if a new instruction incoming from Register Alias Table
	always @(posedge clk) begin
		if (reset) begin
			head_ptr <= 0;
			tail_ptr <= 0;
		end else begin
			
			// check for new incoming entries
			if (RAT_new_instr) begin
				// first instruction
				reorder_buff[tail_ptr].busy <= 1;
				reorder_buff[tail_ptr].exec <= 0;
				reorder_buff[tail_ptr].op <= new_mul_a;
				reorder_buff[tail_ptr].V1 <= src1a_valid;				// check mapping table for this
				reorder_buff[tail_ptr].src1 <= src1a;
				reorder_buff[tail_ptr].V2 <= src2a_valid;				// check mapping table for this
				reorder_buff[tail_ptr].src2 <= src2a;
				reorder_buff[tail_ptr].destReg <= rd_a;
				reorder_buff[tail_ptr].value <= 0;
				reorder_buff[tail_ptr].exception <= 0;	
			
				// second instruction
				reorder_buff[tail_ptr+3'd1].busy <= 1;
				reorder_buff[tail_ptr+3'd1].exec <= 0;
				reorder_buff[tail_ptr+3'd1].op <= new_mul_b;
				reorder_buff[tail_ptr+3'd1].V1 <= src1b_valid;			// check mapping table for this
				reorder_buff[tail_ptr+3'd1].src1 <= src1b;
				reorder_buff[tail_ptr+3'd1].V2 <= src2b_valid;			// check mapping table for this
				reorder_buff[tail_ptr+3'd1].src2 <= src2b;
				reorder_buff[tail_ptr+3'd1].destReg <= rd_b;
				reorder_buff[tail_ptr+3'd1].value <= 0;		
				reorder_buff[tail_ptr+3'd1].exception <= 0;	
				
				// increment tail pointer by 2
				tail_ptr <= tail_ptr + 3'd2;
				
				$display("ROB: Adding two instructions to tags %d and %d", tail_ptr, tail_ptr+3'd1);
				
				// printing the ROB
				@(posedge clk);
				for (int i = 0; i < 8; i++) begin
					$display("Tag: %d	V1: %b	src1: %d	V2: %b	src2: %d	destReg: %d	value: %d", i, reorder_buff[i].V1, reorder_buff[i].src1, reorder_buff[i].V2, reorder_buff[i].src2, reorder_buff[i].destReg, reorder_buff[i].value);
				
				end
				
			end // end if new instr
			
			// branch update
			if (branch_update) begin
				if (branch_mispredict) begin
					// indicate an exception on the branch instruction in ROB
					reorder_buff[branch_tag].exception <= 1;
					reorder_buff[branch_tag].value <= 32'd2;
				end else begin
					reorder_buff[branch_tag].exception <= 0;
					reorder_buff[branch_tag].value <= 32'd1;
				end
			end
			
			if (ADD_FU_valid) begin
				// adder has sent a result, update the ROB according to the tag
				reorder_buff[ADD_FU_tag].value <= ADD_FU_value;
				
				
				$display("ROB: Received result from ADD FU - tag: %d	value: %d", ADD_FU_tag, ADD_FU_value);
				
				// go through the ROB to check whether any invalid sources have a matching tag
				for (int i = 0; i < 8; i++) begin
					if (!reorder_buff[i].V1 && reorder_buff[i].src1 == ADD_FU_tag) begin
						// the tag matches the source, replace with the value
						reorder_buff[i].src1 <= ADD_FU_value;
						// validate the source
						reorder_buff[i].V1 <= 1;
						
						$display("ROB: Validating src1 for ADD (Tag: %d)", ADD_FU_tag);
						
					end
					
					if (!reorder_buff[i].V2 && reorder_buff[i].src2 == ADD_FU_tag) begin
						// the tag matches the source, replace with the value
						reorder_buff[i].src2 <= ADD_FU_value;
						// validate the source
						reorder_buff[i].V2 <= 1;
						
						$display("ROB: Validating src2 for ADD (Tag: %d)", ADD_FU_tag);
						
					end
					
				end // end for loop
			
			end // end if add fu valid
			
			if (MUL_FU_valid) begin
				// adder has sent a result, update the ROB according to the tag
				reorder_buff[MUL_FU_tag].value <= MUL_FU_value;
				
				
				$display("ROB: Received result from MUL FU - tag: %d	value: %d", MUL_FU_tag, MUL_FU_value);
				
				// go through the ROB to check whether any invalid sources have a matching tag
				for (int i = 0; i < 8; i++) begin
					if (!reorder_buff[i].V1 && reorder_buff[i].src1 == MUL_FU_tag) begin
						// the tag matches the source, replace with the value
						reorder_buff[i].src1 <= MUL_FU_value;
						// validate the source
						reorder_buff[i].V1 <= 1;
						
						$display("ROB: Validating src1 for MUL");
						
					end
					
					if (!reorder_buff[i].V2 && reorder_buff[i].src2 == MUL_FU_tag) begin
						// the tag matches the source, replace with the value
						reorder_buff[i].src2 <= MUL_FU_value;
						// validate the source
						reorder_buff[i].V2 <= 1;
						
						$display("ROB: Validating src2 for MUL");
						
					end
					
				end // end for loop
			
			
			end // end if mul fu valid
			// check if the head pointer's 2 sources are valid AND there is no exception
			if (reorder_buff[head_ptr].V1 && reorder_buff[head_ptr].V2 && !reorder_buff[head_ptr].exception && reorder_buff[head_ptr].value > 0) begin
				// this instruction is ready to commit
				
				// commit logic: broadcast tag and value to RSs and Register File
				ROB_bus_trigger <= 1'b1;
				ROB_exception_flush <= 1'b0;
				ROB_bus_tag <= head_ptr;
				ROB_bus_value <= reorder_buff[head_ptr].value;
				
				$display("ROB: Broadcasting values to RF and RSs with head_ptr = %d", head_ptr);
				
				// clear ROB entry
				reorder_buff[head_ptr].busy <= 0;
				reorder_buff[head_ptr].exec <= 0;
				reorder_buff[head_ptr].op <= 0;
				reorder_buff[head_ptr].V1 <= 0;
				reorder_buff[head_ptr].src1 <= 0;
				reorder_buff[head_ptr].V2 <= 0;
				reorder_buff[head_ptr].src2 <= 0;
				reorder_buff[head_ptr].destReg <= 0;
				reorder_buff[head_ptr].value <= 0;
				reorder_buff[head_ptr].exception <= 0;
			
				// increment head pointer
				head_ptr <= head_ptr + 3'd1;
				
				@(posedge clk);
				ROB_bus_trigger <= 1'b0;
				
			end else if (reorder_buff[head_ptr].V1 && reorder_buff[head_ptr].V2 && reorder_buff[head_ptr].exception) begin
				// both sources are ready BUT
				// there is an exception that needs to be handled
				
				//$display("ROB: Exception Detected at Tag: %d", head_ptr);
			
				// FLUSH THE PIPELINE -> clear everything between head and tail
				// clear stuff in execution/decode
				
				// In RS: clear all entries with ROB tag > head_ptr
				// commit logic: broadcast tag and value to RSs and Register File
				ROB_bus_trigger <= 1'b1;
				ROB_exception_flush <= 1'b1;
				ROB_bus_tag <= head_ptr;
				ROB_bus_value <= reorder_buff[head_ptr].value;
				
				while (tail_ptr != head_ptr) begin
					$display("ROB: Flushing instruction with ROB tag: %d", head_ptr);
					// clear ROB entry
					reorder_buff[head_ptr].busy = 0;
					reorder_buff[head_ptr].exec = 0;
					reorder_buff[head_ptr].op = 0;
					reorder_buff[head_ptr].V1 = 0;
					reorder_buff[head_ptr].src1 = 0;
					reorder_buff[head_ptr].V2 = 0;
					reorder_buff[head_ptr].src2 = 0;
					reorder_buff[head_ptr].destReg = 0;
					reorder_buff[head_ptr].value = 0;
					reorder_buff[head_ptr].exception = 0;
					
					head_ptr = head_ptr + 1;
				end
				
				
				@(posedge clk);
				ROB_bus_trigger <= 1'b0;
			
			end else begin
				//$display("ROB ELSE: head_ptr: %d	V1: %b	V2: %b	exception: %b	value: %d", head_ptr, reorder_buff[head_ptr].V1, reorder_buff[head_ptr].V2, reorder_buff[head_ptr].exception, reorder_buff[head_ptr].value);
				ROB_bus_trigger <= 1'b0;
				ROB_exception_flush <= 1'b0;
				ROB_bus_tag <= 0;
				ROB_bus_value <= 0;
			
			end
			
			

		end // end if/else reset
	end // end always @ clk
	


endmodule



