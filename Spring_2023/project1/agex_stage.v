`include "define.vh" 


module AGEX_STAGE(
  input wire clk,
  input wire reset,
  input wire [`from_MEM_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX,    
  input wire [`from_WB_to_AGEX_WIDTH-1:0] from_WB_to_AGEX,   
  input wire [`DE_latch_WIDTH-1:0] from_DE_latch,
  output wire [`AGEX_latch_WIDTH-1:0] AGEX_latch_out,
  output wire [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,
  output wire [`from_AGEX_to_DE_WIDTH-1:0] from_AGEX_to_DE
);

  `UNUSED_VAR (from_MEM_to_AGEX)
  `UNUSED_VAR (from_WB_to_AGEX)

  reg [`AGEX_latch_WIDTH-1:0] AGEX_latch; 
  // wire to send the AGEX latch contents to other pipeline stages 
  assign AGEX_latch_out = AGEX_latch;
  
  wire[`AGEX_latch_WIDTH-1:0] AGEX_latch_contents; 
  
  wire valid_AGEX; 
  wire [`INSTBITS-1:0]inst_AGEX; 
  wire [`DBITS-1:0]PC_AGEX;
  wire [`DBITS-1:0] inst_count_AGEX; 
  wire [`DBITS-1:0] pcplus_AGEX; 
  wire [`IOPBITS-1:0] op_I_AGEX;
  reg br_cond_AGEX; // 1 means a branch condition is satisified. 0 means a branch condition is not satisifed 

  wire [`INSTBITS-1:0]branch_PC;
  assign from_AGEX_to_FE = {
                                br_cond_AGEX,
                                branch_PC
  };
  assign branch_PC = sxt_imm_AGEX + PC_AGEX;

 // **TODO: Complete the rest of the pipeline 
wire [`DBITS-1:0] regval1_AGEX;
wire [`DBITS-1:0] regval2_AGEX;
reg signed [`DBITS-1:0] regval1_AGEX_signed;
reg signed [`DBITS-1:0] regval2_AGEX_signed;
wire [`REGNOBITS-1:0] rd_AGEX;
wire wr_reg_AGEX;
wire [`DBITS-1:0]sxt_imm_AGEX;
  always @ (*) begin
    regval1_AGEX_signed = regval1_AGEX;
    regval2_AGEX_signed = regval2_AGEX;
    case (op_I_AGEX)
      `BEQ_I :  br_cond_AGEX = (regval1_AGEX == regval2_AGEX); // write correct code to check the branch condition. 
      
      `BNE_I : br_cond_AGEX = (regval1_AGEX != regval2_AGEX); // write correct code to check the branch condition. 

      //`BLT_I : ...
      `BGE_I : br_cond_AGEX = (regval1_AGEX_signed >= regval2_AGEX_signed);  //used the signed reg for negatives
      /*
      `BLTU_I: ..
      `BGEU_I : ...
      */
      default : br_cond_AGEX = 1'b0;
    endcase
  end

reg [`DBITS-1:0] aluout_AGEX;
reg [`from_AGEX_to_DE_WIDTH-1:0] agex_de;
assign from_AGEX_to_DE = {wr_reg_AGEX, rd_AGEX, regval1_AGEX, op_I_AGEX} ; 
 // compute ALU operations  (alu out or memory addresses)
 
  always @ (*) begin
  
  case (op_I_AGEX)
    `ADD_I: 
      aluout_AGEX = regval1_AGEX + regval2_AGEX;
    `ADDI_I: begin
      agex_de = 1;
      aluout_AGEX = regval1_AGEX + sxt_imm_AGEX;
      end
    `AUIPC_I:
      aluout_AGEX = PC_AGEX + (sxt_imm_AGEX << 12);

       //  ...

	 endcase 
   
  end 

  

// branch target needs to be computed here 
// computed branch target needs to send to other pipeline stages (pctarget_AGEX)

always @(*)begin  
/*
  if (op_I_AGEX == `JAL_I) 
  ... 
  */
end 



    assign  {                     
                                  valid_AGEX,
                                  inst_AGEX,
                                  PC_AGEX,
                                  pcplus_AGEX,
                                  op_I_AGEX,
                                  inst_count_AGEX,
                                  regval1_AGEX,
                                  regval2_AGEX,
                                  sxt_imm_AGEX,
                                  rd_AGEX,
                                  wr_reg_AGEX
                                          // more signals might need
                                  } = from_DE_latch; 
    
 
  assign AGEX_latch_contents = {
                                valid_AGEX,
                                inst_AGEX,
                                PC_AGEX,
                                op_I_AGEX,
                                aluout_AGEX,
                                rd_AGEX,
                                wr_reg_AGEX,
                                inst_count_AGEX
                                       // more signals might need
                                 }; 
 
  always @ (posedge clk ) begin
    if(reset) begin
      AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};
      // might need more code here  
        end 
    else 
        begin
      // need to complete 
            AGEX_latch <= AGEX_latch_contents ;
        end 
  end




endmodule
