// Rojan Karn - Functional Units for Superscalar OoO

// Adder functional unit - 4 cycle delay
module adder (
	input logic clk, reset,
	// inputs
	input logic valid_instr,
	input logic [31:0] op1, op2,
	input logic [2:0] tag,
	
	// for structural hazard checking - is FU ready?
	output logic adder_ready,
	// bus output
	output logic [31:0] broadcast_val,
	output logic [2:0] broadcast_tag,
	output logic bus_trigger
);
	logic ready;
	logic [31:0] res;
	logic [3:0] cntr;
	logic [2:0] curr_tag;
	
	assign res = op1 + op2;
	
	always @(negedge clk) begin
		if (reset) begin // reset logic
			adder_ready <= 1'b1;
			broadcast_val <= 32'b0;
			broadcast_tag <= 3'b0;
			ready <= 1'b0;
			bus_trigger <= 1'b0;
			cntr <= 4'b0;
			curr_tag <= 0;
		end
		else begin
			///////////// THIS STUFF IS GLITCHY - FIX
			if (valid_instr && !ready) begin
				ready <= 1'b1;
				curr_tag <= tag;
				adder_ready <= 1'b0;
			end else if (!ready) begin
				adder_ready <= 1'b1;
				bus_trigger <= 1'b0;
			end else begin
				adder_ready <= 1'b0;
				bus_trigger <= 1'b0;
			end
			
			if (ready) begin
				$display("ADD FU: Tag: %d	Executing cycle number: %d", tag, cntr);
				cntr <= cntr + 1;
				adder_ready <= 1'b0;
			end
			
			if (ready && cntr == 4'b0011) begin
				ready <= 1'b0;
				cntr <= 4'b0; // reset counter
				adder_ready <= 1'b1;
				// broadcast the resulting tag and value
				$display("ADD FU: sending result to ROB");
				bus_trigger <= 1'b1;
				broadcast_val <= res;
				broadcast_tag <= curr_tag;
			end else if (cntr == 4'b0 && !ready) begin
				@(posedge clk);
				adder_ready <= 1'b1;
				bus_trigger <= 1'b0;
			end
			else begin
				adder_ready <= 1'b0;
				bus_trigger <= 1'b0;
			end
			
		end
	end
	
endmodule

// Multiplier functional unit - 6 cycle delay
module multiplier (
	input logic clk, reset,
	// inputs
	input logic valid_instr,
	input logic [31:0] op1, op2,
	input logic [2:0] tag,
	
	// for structural hazard checking - is FU ready?
	output logic mul_ready,
	// bus output
	output logic [31:0] broadcast_val,
	output logic [2:0] broadcast_tag,
	output logic bus_trigger
);
	logic ready;
	logic [31:0] res;
	logic [3:0] cntr;
	logic [2:0] curr_tag;
	
	assign res = op1 * op2;
	
	always @(negedge clk) begin
		if (reset) begin // reset logic
			mul_ready <= 1'b1;
			broadcast_val <= 32'b0;
			broadcast_tag <= 3'b0;
			ready <= 1'b0;
			bus_trigger <= 1'b0;
			cntr <= 4'b0;
			curr_tag <= 0;
		end
		else begin
			///////////// THIS STUFF IS GLITCHY - FIX
			if (valid_instr && !ready) begin
				ready <= 1'b1;
				curr_tag <= tag;
				mul_ready <= 1'b0;
			end else if (!ready) begin
				mul_ready <= 1'b1;
				bus_trigger <= 1'b0;
			end else begin
				mul_ready <= 1'b0;
				bus_trigger <= 1'b0;
			end
			
			if (ready) begin
				$display("MUL FU: Tag: %d	Executing cycle number: %d", tag, cntr);
				cntr <= cntr + 1;
				mul_ready <= 1'b0;
			end
			
			if (ready && cntr == 4'b0101) begin
				ready <= 1'b0;
				cntr <= 4'b0; // reset counter
				mul_ready <= 1'b1;
				// broadcast the resulting tag and value
				$display("MUL FU: sending result to ROB");
				bus_trigger <= 1'b1;
				broadcast_val <= res;
				broadcast_tag <= curr_tag;
			end else if (cntr == 4'b0 && !ready) begin
				@(posedge clk);
				mul_ready <= 1'b1;
				bus_trigger <= 1'b0;
			end
			else begin
				mul_ready <= 1'b0;
				bus_trigger <= 1'b0;
			end
			
		end
	end
	
	
endmodule


// functional unit for checking branch (beq instructions)
module branch_fu (
		input logic clk, reset,
		input logic new_branch,
		input logic [31:0] op1, op2,
		input logic [2:0] rob_tag,
		
		output logic update_rob,
		output logic mispredict,
		output logic [2:0] tag_out
);

	// send the tag output through
	assign tag_out = rob_tag;

	always @(posedge clk) begin
		if (reset) begin
			mispredict <= 0;
			update_rob <= 0;
		
		end else begin
			if (new_branch) begin
				if (op1 == op2) begin			// beq
					$display("BRANCH FU: Detected branch misprediction, updating ROB");
					mispredict <= 1;
					update_rob <= 1;
				
				end else begin
					$display("BRANCH FU: Operands were not equal. OP1 = %d	OP2 = %d", op1, op2);
					mispredict <= 0;
					update_rob <= 1;
					
				end // end if op1 == op2
			end else begin
				update_rob <= 0;
			
			end // end if new branch
		end // end if not reset
	end // end always @

endmodule



