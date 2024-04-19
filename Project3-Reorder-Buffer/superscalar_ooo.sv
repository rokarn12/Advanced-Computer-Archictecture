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
	
	assign res = op1 + op2;
	
	always @(posedge clk) begin
		if (reset) begin // reset logic
			adder_ready <= 1'b1;
			broadcast_val <= 32'b0;
			broadcast_tag <= 3'b0;
			ready <= 1'b0;
			bus_trigger <= 1'b0;
			cntr <= 4'b0;
		end

		if (valid_instr) begin
			ready <= 1'b1;
			adder_ready <= 1'b0;
		end else if (!ready) begin
			adder_ready <= 1'b1;
			bus_trigger <= 1'b0;
		end else begin
			bus_trigger <= 1'b0;
		end
		
		if (ready) begin
			$display("ADD FU: Executing cycle number: %d", cntr);
			cntr <= cntr + 1;
		end
		
		if (ready && cntr == 4'b0011) begin
			ready <= 1'b0;
			cntr <= 4'b0; // reset counter
			adder_ready <= 1'b1;
			// broadcast the resulting tag and value
			$display("ADD FU: broadcasting on bus");
			bus_trigger <= 1'b1;
			broadcast_val <= res;
			broadcast_tag <= tag;
		end else if (cntr == 4'b0) begin
			adder_ready <= 1'b1;
			//bus_trigger <= 1'b0;
		end else begin
			adder_ready <= 1'b0;
			bus_trigger <= 1'b0;
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
	
	assign res = op1 * op2;
	
	always @(posedge clk) begin
		if (reset) begin // reset logic
			mul_ready <= 1'b1;
			broadcast_val <= 32'b0;
			broadcast_tag <= 3'b0;
			ready <= 1'b0;
			bus_trigger <= 1'b0;
			cntr <= 4'b0;
		end
		
		if (valid_instr) begin
			ready <= 1'b1;
			mul_ready <= 1'b0;
		end else if (!ready) begin
			mul_ready <= 1'b1;
			bus_trigger <= 1'b0;
		end else begin
			bus_trigger <= 1'b0;
		end
		
		if (ready) begin
			$display("MUL FU: Executing cycle number: %d", cntr);
			cntr <= cntr + 1;
		end
		
		if (ready && cntr == 4'b0101) begin
			ready <= 1'b0;
			cntr <= 4'b0; // reset counter
			mul_ready <= 1'b1;
			// broadcast the resulting tag and value
			$display("MUL FU: broadcasting on bus");
			bus_trigger <= 1'b1;
			broadcast_val <= res;
			broadcast_tag <= tag;
		end else if (cntr == 4'b0) begin
			mul_ready <= 1'b1;
		end else begin
			mul_ready <= 1'b0;
			bus_trigger <= 1'b0;
		end
	end
	
endmodule
