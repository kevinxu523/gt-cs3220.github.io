  `include "define.vh" 


module FE_STAGE(
  input wire clk,
  input wire reset,
  input wire [`from_DE_to_FE_WIDTH-1:0] from_DE_to_FE,
  input wire [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,   
  input wire [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,   
  input wire [`from_WB_to_FE_WIDTH-1:0] from_WB_to_FE, 
  output wire [`FE_latch_WIDTH-1:0] FE_latch_out
);

  `UNUSED_VAR (from_MEM_to_FE)
  `UNUSED_VAR (from_WB_to_FE)

  // I-MEM
  (* ram_init_file = `IDMEMINITFILE *)
  reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];
 
  initial begin
      $readmemh(`IDMEMINITFILE , imem);
  end

  // Display memory contents with verilator 
  /*
  always @(posedge clk) begin
    for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
        $display("%h", imem[i]);
    end
  end
  */

  /* pipeline latch */ 
  reg [`FE_latch_WIDTH-1:0] FE_latch;  // FE latch 
  wire valid_FE;
   
  `UNUSED_VAR(valid_FE)
  reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 
  
  reg [`DBITS-1:0] inst_count_FE; /* for debugging purpose */ 
  
  wire [`DBITS-1:0] inst_count_AGEX; /* for debugging purpose. resent the instruction counter */ 

  wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage 
  wire [`DBITS-1:0] pcplus_FE;  // pc plus value in the FE stage 
  wire stall_pipe_FE; // signal to indicate when a front-end needs to be stall
  
  wire [`FE_latch_WIDTH-1:0] FE_latch_contents;  // the signals that will be FE latch contents 
  
  // reading instruction from imem 
  assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];  // this code works. imem is stored 4B together 
  
  // wire to send the FE latch contents to the DE stage 
  assign FE_latch_out = FE_latch; 
 

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE_latch + `INSTSIZE;
  
   
   // the order of latch contents should be matched in the decode stage when we extract the contents. 
  assign FE_latch_contents = {
                                valid_FE, 
                                inst_FE, 
                                PC_FE_latch, 
                                pcplus_FE, // please feel free to add more signals such as valid bits etc. 
                                inst_count_FE,
                                BHR_Index,
                                PHT_Counter,
                                PC_FE_latch,
                                hit
                                 // if you add more bits here, please increase the width of latch in VX_define.vh 
                                
                                };


  wire br_cond_AGEX;
  wire [`INSTBITS-1:0]branch_PC;
  wire BHR_update;         // 8 bit BHR
  wire [3:0] BTB_Index_update;
  wire [31:0] tag_update;
  wire valid_update;
  wire [31:0] target_update;
  wire [7:0] PHT_Index_update;
  reg mispredict = mispredict;
  reg [`DBITS-1:0] mispredict_instr = mispredict_instr;
  assign {
                                br_cond_AGEX,
                                branch_PC,
                                BHR_update,
                                BTB_Index_update,
                                tag_update,
                                valid_update,
                                target_update,
                                PHT_Index_update,
                                mispredict,
                                mispredict_instr
                        

  } = from_AGEX_to_FE;
  //every clock, update the AGEX computed changes
  reg [31:0] nextInstr;
  always @ (posedge clk) begin
    

    if (reset) begin 
      PC_FE_latch <= `STARTPC;
      inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */ 
      end 
      else if(mispredict) begin
        PC_FE_latch <= mispredict_instr;
      end
     else if(!stall_pipe_FE && !hit) begin 
      PC_FE_latch <= pcplus_FE;
      inst_count_FE <= inst_count_FE + 1; 
      end 
      else if(hit) begin
        //counter greater than 2 == buffer the target to nextInstr
        if (PHT_Counter >= 2) begin
          if(nextInstr == 0) begin
            nextInstr <= BTB[BTB_Index][31:0];
            PC_FE_latch <= pcplus_FE;          // + PC_FE_latch;
          end
          else begin
            PC_FE_latch <=  nextInstr;
          end
          inst_count_FE <= inst_count_FE + 1; 
        end
        //counter less than 2 == proceed normally
        else begin
          PC_FE_latch <= pcplus_FE; // + PC_FE_latch;
          inst_count_FE <= inst_count_FE + 1; 
        end
      end
      else if(br_cond_AGEX) begin
        PC_FE_latch <= branch_PC;// + PC_FE_latch;
        inst_count_FE <= inst_count_FE + 1; 
      end
      else 
        PC_FE_latch <= PC_FE_latch;

    //reset nextInstr to clean our buffer for next hits
    nextInstr <= 0;

    //Post Exec stage updates
    if(target_update != 0) begin
      //update BTB
      BTB[BTB_Index_update] <= {tag_update, valid_update, target_update};
      //update PHT State Machine
      if(BHR_update == 1) begin
        if(PHT[PHT_Index_update] == 'b11) begin
          PHT[PHT_Index_update] = 'b11;
        end
        else if(PHT[PHT_Index_update] == 'b10) begin
          PHT[PHT_Index_update] = 'b11;
        end

        else if(PHT[PHT_Index_update] == 'b01) begin
          PHT[PHT_Index_update] = 'b10;
        end

        else if(PHT[PHT_Index_update] == 'b00) begin
          PHT[PHT_Index_update] = 'b01;
        end
      end
      else if(BHR_update == 0) begin
        if(PHT[PHT_Index_update] == 'b11) begin
          PHT[PHT_Index_update] = 'b10;
        end
        else if(PHT[PHT_Index_update] == 'b10) begin
          PHT[PHT_Index_update] = 'b01;
        end

        else if(PHT[PHT_Index_update] == 'b01) begin
          PHT[PHT_Index_update] = 'b00;
        end

        else if(PHT[PHT_Index_update] == 'b00) begin
          PHT[PHT_Index_update] = 'b00;
        end
      end

      //update BHR
      BHR <= BHR << 1 | {7'b0 ,BHR_update};
    end

  end

  // **TODO: Complete the rest of the pipeline 
  assign stall_pipe_FE = {from_DE_to_FE}; //|| stall_AGEX || from_MEM_to_FE || from_WB_to_FE};  // you need to modify this line for your design 


  
  // INSERT BTB, PHT, BHR
  reg [7:0] BHR;         // 8 bit BHR
  reg [1:0] PHT [255:0]; // 256 rows of 2 bit counter PHT
  reg [64:0] BTB [15:0];     //16 rows of 59 bits, 32 tag, 1 valid, 32 target
  reg hit;
  reg [7:0] BHR_Index;
  reg [3:0] BTB_Index;
  assign BHR_Index = PC_FE_latch[9:2] ^ BHR;
  assign BTB_Index = PC_FE_latch[5:2];
  assign hit = BTB[BTB_Index][64:33] == PC_FE_latch && BTB[BTB_Index][32] == 1;
  reg [1:0] PHT_Counter;
  assign PHT_Counter = PHT[BHR_Index];
  //Not Sure if HIT is computed correctly

  always @ (posedge clk) begin
    if(reset) 
        begin 
            // INIT DATA STRUCTS
            BHR <= {8{1'b0}};
            for(int j = 0; j < 256; j = j + 1)
              PHT[j] = {{2'b10}};               //weekly taken
            for(int i = 0; i < 16; i = i + 1)
              BTB[i] = {65{1'b0}};

            FE_latch <= {`FE_latch_WIDTH{1'b0}}; 
            inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */ 
            // ...
        end 
     else  
        begin 
         // this is just an example. you need to expand the contents of if/else
         if (PC_FE_latch >= `IMEMWORDS) begin
          PC_FE_latch <= PC_FE_latch; 
        end
        else if  (stall_pipe_FE && br_cond_AGEX || mispredict) begin //the first stall needs the PC-->FE latch to be firmly latched on branch
          //FE_latch <= FE_latch_contents;
            FE_latch <= {`FE_latch_WIDTH{1'b0}};
         end
         else 
         if (stall_pipe_FE)
         begin 
            FE_latch <= FE_latch; 
            inst_count_FE <= inst_count_FE + 1;
            end  
          else 
            FE_latch <= FE_latch_contents; 
        end  
  end

endmodule
