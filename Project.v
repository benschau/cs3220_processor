module Project(
  input        CLOCK_50,
  input        RESET_N,
  input  [3:0] KEY,
  input  [9:0] SW,
  output [6:0] HEX0,
  output [6:0] HEX1,
  output [6:0] HEX2,
  output [6:0] HEX3,
  output [6:0] HEX4,
  output [6:0] HEX5,
  output [9:0] LEDR
);

  parameter DBITS     = 32;
  parameter INSTSIZE  = 32'd4;
  parameter INSTBITS  = 32;
  parameter REGNOBITS = 4;
  parameter REGWORDS  = (1 << REGNOBITS);
  parameter IMMBITS   = 16;
  parameter STARTPC   = 32'h100;
  parameter ADDRHEX   = 32'hFFFFF000;
  parameter ADDRLEDR  = 32'hFFFFF020;
  parameter ADDRKEY   = 32'hFFFFF080;
  parameter ADDRSW    = 32'hFFFFF090;
  parameter ADDRTIMER = 32'hFFFFF100;
	
  // Address for BFIH.
  parameter ADDRINTHANDLER = 32'hFFFF0000;

  // Change this to fmedian2.mif before submitting
  //parameter IMEMINITFILE = "Test.mif";
  parameter IMEMINITFILE = "fmedian2.mif";
  
  parameter IMEMADDRBITS = 16;
  parameter IMEMWORDBITS = 2;
  parameter IMEMWORDS	 = (1 << (IMEMADDRBITS - IMEMWORDBITS));
  parameter DMEMADDRBITS = 16;
  parameter DMEMWORDBITS = 2;
  parameter DMEMWORDS	 = (1 << (DMEMADDRBITS - DMEMWORDBITS));
   
  parameter OP1BITS  = 6;
  parameter OP1_ALUR = 6'b000000;
  parameter OP1_BEQ  = 6'b001000;
  parameter OP1_BLT  = 6'b001001;
  parameter OP1_BLE  = 6'b001010;
  parameter OP1_BNE  = 6'b001011;
  parameter OP1_JAL  = 6'b001100;
  parameter OP1_LW   = 6'b010010;
  parameter OP1_SW   = 6'b011010;
  parameter OP1_ADDI = 6'b100000;
  parameter OP1_ANDI = 6'b100100;
  parameter OP1_ORI  = 6'b100101;
  parameter OP1_XORI = 6'b100110;
  /* system instruction */
  parameter OP1_SYS  = 6'h3f;
  
  // Add parameters for secondary opcode values 
  /* OP2 */
  parameter OP2BITS  = 8;
  parameter OP2_EQ   = 8'b00001000;
  parameter OP2_LT   = 8'b00001001;
  parameter OP2_LE   = 8'b00001010;
  parameter OP2_NE   = 8'b00001011;
  parameter OP2_ADD  = 8'b00100000;
  parameter OP2_AND  = 8'b00100100;
  parameter OP2_OR   = 8'b00100101;
  parameter OP2_XOR  = 8'b00100110;
  parameter OP2_SUB  = 8'b00101000;
  parameter OP2_NAND = 8'b00101100;
  parameter OP2_NOR  = 8'b00101101;
  parameter OP2_NXOR = 8'b00101110;
  parameter OP2_RSHF = 8'b00110000;
  parameter OP2_LSHF = 8'b00110001;
  /* interrupt instructions */
  parameter OP2_RETI = 8'b00000001;
  parameter OP2_RSR  = 8'b00000010;
  parameter OP2_WSR  = 8'b00000011;
  
  parameter HEXBITS  = 24;
  parameter LEDRBITS = 10;
  parameter KEYBITS = 4;
 
  //*** PLL ***//
  // The reset signal comes from the reset button on the DE0-CV board
  // RESET_N is active-low, so we flip its value ("reset" is active-high)
  // The PLL is wired to produce clk and locked signals for our logic
  wire clk;
  wire locked;
  wire reset;

  Pll myPll(
    .refclk	(CLOCK_50),
    .rst     	(!RESET_N),
    .outclk_0 	(clk),
    .locked   	(locked)
  );

  assign reset = !locked;
  
  
  //*** Special system registers ***// 
  reg [(DBITS-1):0] PCS; // processor control & status
								 // PCS[0] -> Interrupt Enable bit.
								 
  reg [(DBITS-1):0] IRA; // interrupt return address
  reg [(DBITS-1):0] IHA; // interrupt handler address
  reg [(DBITS-1):0] IDN; // interrupt device ID
	
  always @ (posedge clock or posedge reset) begin
		IHA = ADDRINTHANDLER;
  end

  //*** FETCH STAGE ***//
  // The PC register and update logic
  wire [DBITS-1:0] pcplus_FE;
  wire [DBITS-1:0] pcpred_FE;
  wire [DBITS-1:0] inst_FE_w;
  wire stall_pipe;
  wire mispred_EX_w;
  // Note: used to use output of EX latch, changed to 
  // take branch during EX stage instead of after
  wire [DBITS-1:0] pcgood_EX_w;
  
  reg [DBITS-1:0] PC_FE;
  reg [INSTBITS-1:0] inst_FE;
  // I-MEM
  (* ram_init_file = IMEMINITFILE *)
  reg [DBITS-1:0] imem [IMEMWORDS-1:0];
  
  // This statement is used to initialize the I-MEM
  // during simulation using Model-Sim
  /*
  initial begin
    $readmemh("test.hex", imem);
  end
  */
    
  assign inst_FE_w = imem[PC_FE[IMEMADDRBITS-1:IMEMWORDBITS]];
  
  always @ (posedge clk or posedge reset) begin
    if(reset)
      PC_FE <= STARTPC;
    else if(mispred_EX_w)
      PC_FE <= pcgood_EX_w;
    else if(!stall_pipe)
      PC_FE <= pcpred_FE;
    else
      PC_FE <= PC_FE;
  end

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE + INSTSIZE;
  // This is the predicted value of the PC that we use to fetch the next instruction
  assign pcpred_FE = pcplus_FE;
  
  // FE_latch
  always @ (posedge clk or posedge reset) begin
    if(reset)
      inst_FE <= {INSTBITS{1'b0}};
    else if (mispred_EX_w) // DONE: set inst_FE accounting for misprediction/stalls
      inst_FE <= {INSTBITS{1'b0}};
    else if (stall_pipe)
      inst_FE <= inst_FE;
    else
      inst_FE = inst_FE_w;
  end


  //*** DECODE STAGE ***//
  wire [OP1BITS-1:0] op1_ID_w;
  wire [OP2BITS-1:0] op2_ID_w;
  wire [IMMBITS-1:0] imm_ID_w;
  wire [REGNOBITS-1:0] rd_ID_w;
  wire [REGNOBITS-1:0] rs_ID_w;
  wire [REGNOBITS-1:0] rt_ID_w;
  // Two read ports, always using rs and rt for register numbers
  wire [DBITS-1:0] regval1_ID_w;
  wire [DBITS-1:0] regval2_ID_w;
  wire [DBITS-1:0] sxt_imm_ID_w;
  wire is_br_ID_w;
  wire is_jmp_ID_w;
  wire rd_mem_ID_w;
  wire wr_mem_ID_w;
  wire wr_reg_ID_w;
  wire [4:0] ctrlsig_ID_w;
  wire [REGNOBITS-1:0] wregno_ID_w;
  wire wr_reg_EX_w;
  wire wr_reg_MEM_w;
  // Check if it is a system instr
  wire is_sys_ID_w;
  wire is_reti_ID_w;
  wire is_rsr_ID_w;
  wire is_wsr_ID_w;
  
  // Register file
  reg [DBITS-1:0] PC_ID;
  reg [DBITS-1:0] regs [REGWORDS-1:0];
  reg signed [DBITS-1:0] regval1_ID;
  reg signed [DBITS-1:0] regval2_ID;
  reg signed [DBITS-1:0] immval_ID;
  reg [OP1BITS-1:0] op1_ID;
  reg [OP2BITS-1:0] op2_ID;
  reg [6:0] ctrlsig_ID;
  reg [REGNOBITS-1:0] wregno_ID;
  // Declared here for stall check
  reg [REGNOBITS-1:0] wregno_EX;
  reg [REGNOBITS-1:0] wregno_MEM;
  reg [INSTBITS-1:0] inst_ID;

  // DONE: Specify signals such as op*_ID_w, imm_ID_w, r*_ID_w
  assign op1_ID_w = inst_FE[31:26];
  assign op2_ID_w = inst_FE[25:18];
  assign imm_ID_w = inst_FE[23:8];
  assign rd_ID_w = inst_FE[11:8];
  assign rs_ID_w = inst_FE[7:4];
  assign rt_ID_w = inst_FE[3:0];
  
  assign is_sys_ID_w = (op1_ID_w === OP1_SYS);
  assign is_reti_ID_w = is_sys_ID_w && (op2_ID_w === OP2_RETI);
  assign is_rsr_ID_w = is_sys_ID_w && (op2_ID_w === OP2_RSR);
  assign is_wsr_ID_w = is_sys_ID_w && (op2_ID_w === OP2_WSR);
 
  // Read register values
  assign regval1_ID_w = regs[rs_ID_w];
  assign regval2_ID_w = regs[rt_ID_w];

  // Sign extension
  SXT mysxt (.IN(imm_ID_w), .OUT(sxt_imm_ID_w));

  // DONE: Specify control signals such as is_br_ID_w, is_jmp_ID_w, rd_mem_ID_w, etc.
  // You may add or change control signals if needed
  assign is_br_ID_w = op1_ID_w[5:3] === 3'b001;
  assign is_jmp_ID_w = op1_ID_w === OP1_JAL;
  assign rd_mem_ID_w = op1_ID_w === OP1_LW;
  assign wr_mem_ID_w = op1_ID_w === OP1_SW;
  // Register writes occur on all instructions except non JAL branches and SW
  assign wr_reg_ID_w = !((is_br_ID_w && !is_jmp_ID_w) || wr_mem_ID_w);
  // Among instructions which write back, Rd is target for all ALUR instructions,
  // and Rt is target for all others
  assign wregno_ID_w = (op1_ID_w === OP1_ALUR) ? rd_ID_w : rt_ID_w;

  // TODO: Add system instr reti, wsr as control sig
  // RSR changes the value of regval2_ID.
  assign ctrlsig_ID_w = {is_reti_ID_w, is_wsr_ID_w, is_br_ID_w, is_jmp_ID_w, rd_mem_ID_w, wr_mem_ID_w, wr_reg_ID_w};
  
  // DONE: Specify stall condition
  wire chkRt;
  // Rt is not used only in JAL, LW, and immediate arithmetic instructions
  assign chkRt = !(op1_ID_w === OP1_JAL || op1_ID_w === OP1_LW || op1_ID_w[5:3] === 3'b100);
  // Check if one of the registers this instruction depends on is going to be written to by the instructions 
  // in EX or MEM. All instructions depend on Rs - only stall on write to Rt if this instruction actually
  // depends on it.
  wire rs_ex_dep_w;
  wire rs_mem_dep_w;
  wire rt_ex_dep_w;
  wire rt_mem_dep_w;
  
  assign rs_ex_dep_w = rs_ID_w === wregno_ID && ctrlsig_ID[0];
  assign rs_mem_dep_w = rs_ID_w === wregno_EX && ctrlsig_EX[0];
  assign rt_ex_dep_w = chkRt && rt_ID_w === wregno_ID && ctrlsig_ID[0];
  assign rt_mem_dep_w = chkRt && rt_ID_w === wregno_EX && ctrlsig_EX[0];
  assign stall_pipe = (rs_ex_dep_w || rt_ex_dep_w) && op1_ID === OP1_LW;

  
  // ID_latch
  always @ (posedge clk or posedge reset) begin
    if(reset) begin
      PC_ID	 <= {DBITS{1'b0}};
		inst_ID	 <= {INSTBITS{1'b0}};
      op1_ID	 <= {OP1BITS{1'b0}};
      op2_ID	 <= {OP2BITS{1'b0}};
		immval_ID <= {IMMBITS{1'b0}};
      regval1_ID  <= {DBITS{1'b0}};
      regval2_ID  <= {DBITS{1'b0}};
      wregno_ID	 <= {REGNOBITS{1'b0}};
      ctrlsig_ID <= 5'h0;
    end else begin
      // DONE: specify ID latches
      if (stall_pipe || mispred_EX_w) begin
        PC_ID	 <= {DBITS{1'b0}};
        inst_ID	 <= {INSTBITS{1'b0}};
        op1_ID	 <= {OP1BITS{1'b0}};
        op2_ID	 <= {OP2BITS{1'b0}};
		  immval_ID <= {IMMBITS{1'b0}};
        regval1_ID  <= {DBITS{1'b0}};
        regval2_ID  <= {DBITS{1'b0}};
        wregno_ID	 <= {REGNOBITS{1'b0}};
        ctrlsig_ID <= 5'h0;
      end else begin
        PC_ID	 <= PC_FE;
        inst_ID <= inst_FE;
        op1_ID <= op1_ID_w;
        op2_ID <= op2_ID_w;
		  immval_ID <= sxt_imm_ID_w;
		  
		  // TODO: add dependency logic for system registers
		  // temp conditional here until then, but should be integrated
		  // into the below else block (which doesn't assume system regs)
		  if (is_rsr_ID_w) begin
				case (rs_ID_w) 
					4'b0001 : regval2_ID <= IRA;
					4'b0010 : regval2_ID <= IHA;
					4'b0011 : regval2_ID <= IDN;
					4'b0100 : regval2_ID <= PCS;
				endcase
		  end else begin
				if (rs_ex_dep_w)
					regval1_ID <= aluout_EX_r;
				else if (rs_mem_dep_w)
					regval1_ID <= rd_mem_MEM_w ? rd_val_MEM_w : aluout_EX;
				else
					regval1_ID <= regval1_ID_w;

		      if (rt_ex_dep_w)
		        regval2_ID <= aluout_EX_r;
		      else if (rt_mem_dep_w)
		        regval2_ID <= rd_mem_MEM_w ? rd_val_MEM_w : aluout_EX;
		      else
			     regval2_ID <= regval2_ID_w;
		  end
			 
        wregno_ID <= wregno_ID_w;
        ctrlsig_ID <= ctrlsig_ID_w;
      end
    end
  end


  //*** AGEN/EXEC STAGE ***//

  wire is_br_EX_w;
  wire is_jmp_EX_w;
  
  wire is_reti_EX_w;
  wire is_rsr_EX_w;
  wire is_wsr_EX_w;

  reg [INSTBITS-1:0] inst_EX; /* This is for debugging */
  reg br_cond_EX;
  reg [3:0] ctrlsig_EX;
  // Note that aluout_EX_r is declared as reg, but it is output signal from combi logic
  reg signed [DBITS-1:0] aluout_EX_r;
  reg [DBITS-1:0] aluout_EX;
  reg [DBITS-1:0] regval2_EX;

  always @ (op1_ID or regval1_ID or regval2_ID) begin
    case (op1_ID)
      OP1_BEQ : br_cond_EX = (regval1_ID == regval2_ID);
      OP1_BLT : br_cond_EX = (regval1_ID < regval2_ID);
      OP1_BLE : br_cond_EX = (regval1_ID <= regval2_ID);
      OP1_BNE : br_cond_EX = (regval1_ID != regval2_ID);
      default : br_cond_EX = 1'b0;
    endcase
  end
 
 
  // TODO: add handling for OP2_RETI, OP2_RSR, OP2_WSR
  always @ (op1_ID or op2_ID or regval1_ID or regval2_ID or immval_ID) begin
    if(op1_ID == OP1_ALUR) begin
      case (op2_ID)
			OP2_EQ	 : aluout_EX_r = {31'b0, regval1_ID == regval2_ID};
			OP2_LT	 : aluout_EX_r = {31'b0, regval1_ID < regval2_ID};
			// DONE: complete OP2_*
			OP2_LE   : aluout_EX_r = {31'b0, regval1_ID <= regval2_ID};
			OP2_NE   : aluout_EX_r = {31'b0, regval1_ID !== regval2_ID};
			OP2_ADD  : aluout_EX_r = regval1_ID + regval2_ID;
			OP2_AND  : aluout_EX_r = regval1_ID & regval2_ID;
			OP2_OR   : aluout_EX_r = regval1_ID | regval2_ID;
			OP2_XOR  : aluout_EX_r = regval1_ID ^ regval2_ID;
			OP2_SUB  : aluout_EX_r = regval1_ID - regval2_ID;
			OP2_NAND : aluout_EX_r = ~(regval1_ID & regval2_ID);
			OP2_NOR  : aluout_EX_r = ~(regval1_ID | regval2_ID);
			OP2_NXOR : aluout_EX_r = regval1_ID ~^ regval2_ID;
			OP2_RSHF : aluout_EX_r = regval1_ID >> regval2_ID;
			OP2_LSHF : aluout_EX_r = regval1_ID << regval2_ID;
			default	: aluout_EX_r = {DBITS{1'b0}};
      endcase
    end else if(op1_ID == OP1_JAL)
      aluout_EX_r = PC_ID;
    else if(op1_ID == OP1_LW || op1_ID == OP1_SW || op1_ID == OP1_ADDI)
      aluout_EX_r = regval1_ID + immval_ID;
    else if(op1_ID == OP1_ANDI)
      aluout_EX_r = regval1_ID & immval_ID;
    else if(op1_ID == OP1_ORI)
      aluout_EX_r = regval1_ID | immval_ID;
    else if(op1_ID == OP1_XORI)
      aluout_EX_r = regval1_ID ^ immval_ID;
    else
      aluout_EX_r = {DBITS{1'b0}};
  end

  assign is_br_EX_w = ctrlsig_ID[4];
  assign is_jmp_EX_w = ctrlsig_ID[3];
  assign wr_reg_EX_w = ctrlsig_ID[0];
  assign is_reti_EX_w = ctrlsig_ID[6];
  
  // DONE: Specify signals such as mispred_EX_w, pcgood_EX_w
  // DONE: Modified misprediction to handle RETI.
  assign mispred_EX_w = br_cond_EX || is_jmp_EX_w || is_reti_EX_w;

  assign pcgood_EX_w = is_jmp_EX_w ? (regval1_ID + 4*immval_ID) : 
							  is_reti_EX_w ? (IRA) : 
							  (PC_ID + 4*immval_ID);

  // EX_latch
  always @ (posedge clk or posedge reset) begin
    if(reset) begin
	   inst_EX	  <= {INSTBITS{1'b0}};
      aluout_EX  <= {DBITS{1'b0}};
      wregno_EX  <= {REGNOBITS{1'b0}};
      ctrlsig_EX <= 3'h0;
		regval2_EX <= {DBITS{1'b0}};
    end else begin
		if (is_reti_EX_w) begin
			// TODO: enable IE in PCS. something something add OIE to PCS? not sure.
		end
	 
		// TODO: Specify EX latches
      inst_EX    <= inst_ID;
      aluout_EX  <= aluout_EX_r;
      wregno_EX  <= wregno_ID;
      ctrlsig_EX <= {ctrlsig_ID[5],ctrlsig_ID[2:0]};
      regval2_EX <= regval2_ID;
    end
  end
  

  //*** MEM STAGE ***//

  wire rd_mem_MEM_w;
  wire wr_mem_MEM_w;
  
  wire [DBITS-1:0] memaddr_MEM_w;
  wire [DBITS-1:0] rd_val_MEM_w;

  reg [INSTBITS-1:0] inst_MEM; /* This is for debugging */
  reg [DBITS-1:0] regval_MEM;  
  reg [1:0] ctrlsig_MEM;
  // D-MEM
  (* ram_init_file = IMEMINITFILE *)
  reg [DBITS-1:0] dmem[DMEMWORDS-1:0];

  assign memaddr_MEM_w = aluout_EX;
  assign rd_mem_MEM_w = ctrlsig_EX[2];
  assign wr_mem_MEM_w = ctrlsig_EX[1];
  assign wr_reg_MEM_w = ctrlsig_EX[0];
  // Read from D-MEM
  assign rd_val_MEM_w = (memaddr_MEM_w == ADDRKEY) ? {{(DBITS-KEYBITS){1'b0}}, ~KEY} :
									dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]];

  // Write to D-MEM
  always @ (posedge clk) begin
    if(wr_mem_MEM_w)
      dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]] <= regval2_EX;
  end

  always @ (posedge clk or posedge reset) begin
    if(reset) begin
	   inst_MEM		<= {INSTBITS{1'b0}};
      regval_MEM  <= {DBITS{1'b0}};
      wregno_MEM  <= {REGNOBITS{1'b0}};
      ctrlsig_MEM <= 1'b0;
    end else begin
		inst_MEM		<= inst_EX;
      regval_MEM  <= rd_mem_MEM_w ? rd_val_MEM_w : aluout_EX;
      wregno_MEM  <= wregno_EX;
      ctrlsig_MEM <= {ctrlsig_EX[3],ctrlsig_EX[0]};
    end
  end


  /*** WRITE BACK STAGE ***/ 

  wire wr_reg_WB_w; 
  // regs is already declared in the ID stage
  wire wr_wsr_WB_w;

  assign wr_reg_WB_w = ctrlsig_MEM[0];
  assign wr_wsr_WB_w = ctrlsig_MEM[1];
  
  always @ (negedge clk or posedge reset) begin
    if(reset) begin
		regs[0] <= {DBITS{1'b0}};
		regs[1] <= {DBITS{1'b0}};
		regs[2] <= {DBITS{1'b0}};
		regs[3] <= {DBITS{1'b0}};
		regs[4] <= {DBITS{1'b0}};
		regs[5] <= {DBITS{1'b0}};
		regs[6] <= {DBITS{1'b0}};
		regs[7] <= {DBITS{1'b0}};
		regs[8] <= {DBITS{1'b0}};
		regs[9] <= {DBITS{1'b0}};
		regs[10] <= {DBITS{1'b0}};
		regs[11] <= {DBITS{1'b0}};
		regs[12] <= {DBITS{1'b0}};
		regs[13] <= {DBITS{1'b0}};
		regs[14] <= {DBITS{1'b0}};
		regs[15] <= {DBITS{1'b0}};
	 end else if (wr_reg_WB_w) begin
		if (wr_wsr_WB_w) begin
			// interpret Sd as system register
			case (wregno_MEM) 
				4'b0001 : IRA <= regval_MEM;
				4'b0010 : IHA <= regval_MEM;
				4'b0011 : IDN <= regval_MEM;
				4'b0100 : PCS <= regval_MEM;
			endcase
		end else begin
			regs[wregno_MEM] <= regval_MEM;
		end
	 end
  end
  
  
  /*** I/O ***/
  /*
  // Create and connect HEX register
  reg [23:0] HEX_out;
  
  SevenSeg ss5(.OUT(HEX5), .IN(HEX_out[23:20]), .OFF(1'b0));
  SevenSeg ss4(.OUT(HEX4), .IN(HEX_out[19:16]), .OFF(1'b0));
  SevenSeg ss3(.OUT(HEX3), .IN(HEX_out[15:12]), .OFF(1'b0));
  SevenSeg ss2(.OUT(HEX2), .IN(HEX_out[11:8]), .OFF(1'b0));
  SevenSeg ss1(.OUT(HEX1), .IN(HEX_out[7:4]), .OFF(1'b0));
  SevenSeg ss0(.OUT(HEX0), .IN(HEX_out[3:0]), .OFF(1'b0));
  
  always @ (posedge clk or posedge reset) begin
    if(reset)
	   HEX_out <= 24'hFEDEAD;
	 else if(wr_mem_MEM_w && (memaddr_MEM_w == ADDRHEX))
      HEX_out <= regval2_EX[HEXBITS-1:0];
  end

  // TODO: Write the code for LEDR here
  reg [9:0] LEDR_out;
  
  // ...
  always @ (posedge clk or posedge reset) begin
    if(reset)
		LEDR_out <= 10'd0;
	 else if(wr_mem_MEM_w && (memaddr_MEM_w == ADDRLEDR))
	   LEDR_out <= regval2_EX[LEDRBITS-1:0];
  end

  assign LEDR = LEDR_out;
  */
  
  /*** Interrupt Handling ***/
  
  // Setup and create address/data/we buses.
  wire [(DBITS-1):0] abus;
  wire [(DBITS-1):0] dbus;
  wire 				   we; /* write enable */
  
  assign abus = memaddr_MEM_w;
  assign we   = wr_mem_MEM_w;
  assign dbus = wr_mem_MEM_w ? regval2_EX : {DBITS{1'bz}};
  
  // TODO
  wire intreq;
  
  wire intr_timer;
  wire intr_key;
  wire intr_sws;
  wire intr_ledr; // are these two necessary?
  wire intr_hex;
  
  wire init;
  wire lock;
  
  // TODO: check requests before the last stage (for RSR) and after the normal regfile read (for WSR)
  assign intreq = (!reset) && (PCS[0] && (intr_timer || intr_keys || intr_sws));
  
  // Attach devices
  // TODO do we need separate devices for HEX, LEDR?
  // TODO modules don't use intr_timer, init, or lock.
  Timer #(.BITS(DBITS), .BASE(ADDRTIMER)) timer(
	 .ABUS(abus), 
	 .DBUS(dbus),
	 .WE(we),
	 .INTR(intr_timer),
	 .CLK(clk),
	 .LOCK(lock),
	 .INIT(init),
	 .RESET(reset)
  );
  
  Key #(.BITS(DBITS), .BASE(ADDRKEY)) key(
	 .ABUS(abus), 
	 .DBUS(dbus),
	 .WE(we),
	 .INTR(intr_key),
	 .CLK(clk),
	 .LOCK(lock),
	 .INIT(init),
	 .RESET(reset)
  );
  
  Switch #(.BITS(DBITS), .BASE(ADDRSW)) switch(
	 .ABUS(abus), 
	 .DBUS(dbus),
	 .WE(we),
	 .INTR(intr_sws),
	 .CLK(clk),
	 .LOCK(lock),
	 .INIT(init),
	 .RESET(reset)
  );
  
  Ledr #(.BITS(DBITS), .BASE(ADDRLEDR)) switch(
	 .ABUS(abus), 
	 .DBUS(dbus),
	 .WE(we),
	 .INTR(intr_ledr),
	 .OUT(LEDR),
	 .CLK(clk),
	 .LOCK(lock),
	 .INIT(init),
	 .RESET(reset)
  );
  
  Hex #(.BITS(DBITS), .BASE(ADDRHEX)) switch(
	 .ABUS(abus), 
	 .DBUS(dbus),
	 .WE(we),
	 .INTR(intr_hex),
	 .OUTHEX5(HEX5),
	 .OUTHEX4(HEX4),
	 .OUTHEX3(HEX3),
	 .OUTHEX2(HEX2),
	 .OUTHEX1(HEX1),
	 .OUTHEX0(HEX0),
	 .CLK(clk),
	 .LOCK(lock),
	 .INIT(init),
	 .RESET(reset)
  );
  
endmodule

module SXT(IN, OUT);
  parameter IBITS = 16;
  parameter OBITS = 32;

  input  [IBITS-1:0] IN;
  output [OBITS-1:0] OUT;

  assign OUT = {{(OBITS-IBITS){IN[IBITS-1]}}, IN};
endmodule

// =============================================================
// I/O Devices
// =============================================================
module Key(ABUS, DBUS, KEY, WE, INTR, CLK, LOCK, INIT, RESET);
	parameter BITS;
	parameter BASE;
	
	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire [3:0] KEY;
	input wire CLK, WE, LOCK, INIT, RESET;
	output wire INTR;
	
	wire selData = (ABUS === BASE);
	wire selCtl = (ABUS === BASE + 4);
	reg [3:0] sample;
	reg [3:0] KEYDATA;
	reg [(BITS-1):0] KEYCTRL;
	reg [3:0] clockCount;
	always @ (posedge CLK or posedge RESET) begin 
		if (RESET) begin
			KEYDATA <= 4'h0;
			KEYCTRL <= {(BITS-1){1'b0}};
		end else begin
			if (selData && !WE) begin
				KEYCTRL[0] <= 0;
			end
			if (clockCount === 4'hF) begin
				if (KEY === sample && KEYDATA !== sample) begin
					KEYDATA <= sample;
					if (KEYCTRL[0]) begin
						KEYCTRL[1] <= 1;
					end else begin
						KEYCTRL[0] <= 1;
					end
				end
				sample <= KEY;
				clockCount <= 4'h0;
			end
			clockCount <= clockCount + 1;
			if (WE) begin
				if (DBUS[1] === 0) begin
					KEYCTRL[1] <= 0;
				end
				KEYCTRL[4] <= DBUS[4];
			end
		end
	end
	assign DBUS = (selData && !WE) ? {{(BITS-4){1'b0}},KEYDATA} : 
					  (selCtl && !WE) ? KEYCTRL : 
					  {BITS{1'bz}};
endmodule

// TODO; 
// just a clone of Key module, but increased register widths to 10 (10 switches on the DE0)
module Switch(ABUS, DBUS, SW, WE, INTR, CLK, LOCK, INIT, RESET);
	parameter BITS;
	parameter BASE;
	
	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire [9:0] SW;
	input wire CLK, WE, LOCK, INIT, RESET;
	output wire INTR;
	
	wire selData = (ABUS === BASE);
	wire selCtl = (ABUS === BASE + 4);
	reg [9:0] sample;
	reg [9:0] SDATA;
	reg [(BITS-1):0] SCTRL;
	reg [3:0] clockCount;
	always @ (posedge CLK or posedge RESET) begin 
		if (RESET) begin
			SDATA <= 10'h0;
			SCTRL <= {(BITS-1){1'b0}};
		end else begin
			if (selData && !WE) begin
				SCTRL[0] <= 0;
			end
			if (clockCount === 4'hF) begin
				if (SW === sample && SDATA !== sample) begin
					SDATA <= sample;
					if (SCTRL[0]) begin
						SCTRL[1] <= 1;
					end else begin
						SCTRL[0] <= 1;
					end
				end
				sample <= SW;
				clockCount <= 4'h0;
			end
			clockCount <= clockCount + 1;
			if (WE) begin
				if (DBUS[1] === 0) begin
					SCTRL[1] <= 0;
				end
				SCTRL[4] <= DBUS[4];
			end
		end
	end
	assign DBUS = (selData && !WE) ? {{(BITS-10){1'b0}},SDATA} : 
					  (selCtl && !WE) ? SCTRL : 
					  {BITS{1'bz}};
endmodule
	
// TODO
module Timer(ABUS, DBUS, WE, INTR, CLK, LOCK, INIT, RESET);
	parameter BITS;
	parameter BASE;
	
	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE, CLK, LOCK, INIT, RESET;
	output wire INTR;
	
	wire selCnt = (ABUS === BASE);
	wire selLim = (ABUS === BASE + 4);
	wire selData = selCnt || selLim; // select TCNT/TLIM
	wire selCtl = (ABUS === BASE + 8); // select TCTL
	
	wire rdCtl = (!WE) && selCtl;
	wire rdCnt = (!WE) && selCnt;
	
	reg [(BITS - 1):0] TCNT; // current value of counter
	reg [(BITS - 1):0] TLIM; // counter limit
	reg [(BITS - 1):0] TCTL; // control/status reg
	
	// increment CLK every 1ms by default
	always @ (posedge CLK or posedge RESET) begin
		if (RESET) begin 
			TCNT <= {(BITS - 1){1'b0}};
			TLIM <= {(BITS - 1){1'b0}};
			TCTL <= {(BITS - 1){1'b0}};
		end else begin 
			if (selData && !WE) begin
				TCTL[0] <= 0;
			end
		
			if (WE) begin
				if (selCnt) begin
					TCNT <= DBUS;
				end else if (selLim) begin
					TLIM <= DBUS; 
				end
				
				if (selCtl && DBUS == 0) begin
					if (ABUS === BASE + 8) begin // ready bit
						TCTL[0] <= 0;
					end
					
					if (ABUS === BASE + 9) begin // overflow bit
						TCTL[1] <= 0;
					end
				end
			end
		
			if ((TLIM != 0) && (TCNT == TLIM - 1)) begin
				//TCNT <= TCNT + 1; // commented out as I don't know what the purpose of doing this is.
				TCNT <= 0;
				TCTL[0] <= 1;
			end else begin
				TCNT <= TCNT + 1;
				
				if (TCTL[0] == 1) begin
					TCTL[1] = 1;
				end
			end
			
		end
	end
	
	assign DBUS = rdCtl ? {TCTL} :
					  rdCnt ? {TCNT} :
					  {BITS{1'bz}};
	
endmodule

// TODO
module Ledr(ABUS, DBUS, WE, INTR, OUT, CLK, LOCK, INIT, RESET);
	parameter BITS;
	parameter BASE;
	
	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE, CLK, LOCK, INIT, RESET;
	output wire OUT, INTR;
	
	reg [9:0] LEDRDATA;
	
	wire selData = (ABUS === BASE);
	
	always @ (posedge CLK or posedge RESET) begin
		if (RESET) begin
			LEDRDATA <= 10'b0;
		end else begin
			
			if (WE && selData) begin
				LEDRDATA <= DBUS[9:0];
			end
			
		end
		
	end
	
	assign OUT = LEDRDATA;
	assign DBUS = selData ? LEDRDATA :
					  {BITS{1'bz}};
	
endmodule


// TODO
// currently implemented as a single big hex thing.
// Would an individual module per hex digit be better?
module Hex(ABUS, DBUS, WE, INTR, OUTHEX5, OUTHEX4, OUTHEX3, OUTHEX2, OUTHEX1, CLK, LOCK, INIT, RESET);
	parameter BITS;
	parameter BASE;
	
	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE, CLK, LOCK, INIT, RESET;
	output wire OUTHEX5, OUTHEX4, OUTHEX3, OUTHEX2, OUTHEX1, INTR;
	
	reg [23:0] HEXDATA;
	
	wire selData = (ABUS === BASE);
	
	always @ (posedge CLK or posedge RESET) begin
		if (RESET) begin
			HEXDATA <= 24'hFFFFFF;
		end else begin
		
			if (WE && selData) begin
				HEXDATA <= DBUS[23:0];
			end 
			
		end
	end
	
	wire HEX5 = HEXDATA[23:20];
	wire HEX4 = HEXDATA[19:16];
	wire HEX3 = HEXDATA[15:12];
	wire HEX2 = HEXDATA[11:8];
	wire HEX1 = HEXDATA[7:4];
	wire HEX0 = HEXDATA[3:0];
	
	assign OUTHEX5 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX5 == 4'h0) ? 7'b1000000 :
		(HEX5 == 4'h1) ? 7'b1111001 :
		(HEX5 == 4'h2) ? 7'b0100100 :
		(HEX5 == 4'h3) ? 7'b0110000 :
		(HEX5 == 4'h4) ? 7'b0011001 :
		(HEX5 == 4'h5) ? 7'b0010010 :
		(HEX5 == 4'h6) ? 7'b0000010 :
		(HEX5 == 4'h7) ? 7'b1111000 :
		(HEX5 == 4'h8) ? 7'b0000000 :
		(HEX5 == 4'h9) ? 7'b0010000 :
		(HEX5 == 4'hA) ? 7'b0001000 :
		(HEX5 == 4'hb) ? 7'b0000011 :
		(HEX5 == 4'hc) ? 7'b1000110 :
		(HEX5 == 4'hd) ? 7'b0100001 :
		(HEX5 == 4'he) ? 7'b0000110 :
		/*HEX5 == 4'hf*/ 7'b0001110 ;
  
  assign OUTHEX4 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX4 == 4'h0) ? 7'b1000000 :
		(HEX4 == 4'h1) ? 7'b1111001 :
		(HEX4 == 4'h2) ? 7'b0100100 :
		(HEX4 == 4'h3) ? 7'b0110000 :
		(HEX4 == 4'h4) ? 7'b0011001 :
		(HEX4 == 4'h5) ? 7'b0010010 :
		(HEX4 == 4'h6) ? 7'b0000010 :
		(HEX4 == 4'h7) ? 7'b1111000 :
		(HEX4 == 4'h8) ? 7'b0000000 :
		(HEX4 == 4'h9) ? 7'b0010000 :
		(HEX4 == 4'hA) ? 7'b0001000 :
		(HEX4 == 4'hb) ? 7'b0000011 :
		(HEX4 == 4'hc) ? 7'b1000110 :
		(HEX4 == 4'hd) ? 7'b0100001 :
		(HEX4 == 4'he) ? 7'b0000110 :
		/*HEX4 == 4'hf*/ 7'b0001110 ;
		
	assign OUTHEX3 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX3 == 4'h0) ? 7'b1000000 :
		(HEX3 == 4'h1) ? 7'b1111001 :
		(HEX3 == 4'h2) ? 7'b0100100 :
		(HEX3 == 4'h3) ? 7'b0110000 :
		(HEX3 == 4'h4) ? 7'b0011001 :
		(HEX3 == 4'h5) ? 7'b0010010 :
		(HEX3 == 4'h6) ? 7'b0000010 :
		(HEX3 == 4'h7) ? 7'b1111000 :
		(HEX3 == 4'h8) ? 7'b0000000 :
		(HEX3 == 4'h9) ? 7'b0010000 :
		(HEX3 == 4'hA) ? 7'b0001000 :
		(HEX3 == 4'hb) ? 7'b0000011 :
		(HEX3 == 4'hc) ? 7'b1000110 :
		(HEX3 == 4'hd) ? 7'b0100001 :
		(HEX3 == 4'he) ? 7'b0000110 :
		/*HEX3 == 4'hf*/ 7'b0001110 ;
		
	assign OUTHEX2 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX2 == 4'h0) ? 7'b1000000 :
		(HEX2 == 4'h1) ? 7'b1111001 :
		(HEX2 == 4'h2) ? 7'b0100100 :
		(HEX2 == 4'h3) ? 7'b0110000 :
		(HEX2 == 4'h4) ? 7'b0011001 :
		(HEX2 == 4'h5) ? 7'b0010010 :
		(HEX2 == 4'h6) ? 7'b0000010 :
		(HEX2 == 4'h7) ? 7'b1111000 :
		(HEX2 == 4'h8) ? 7'b0000000 :
		(HEX2 == 4'h9) ? 7'b0010000 :
		(HEX2 == 4'hA) ? 7'b0001000 :
		(HEX2 == 4'hb) ? 7'b0000011 :
		(HEX2 == 4'hc) ? 7'b1000110 :
		(HEX2 == 4'hd) ? 7'b0100001 :
		(HEX2 == 4'he) ? 7'b0000110 :
		/*HEX2 == 4'hf*/ 7'b0001110 ;
		
	assign OUTHEX1 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX1 == 4'h0) ? 7'b1000000 :
		(HEX1 == 4'h1) ? 7'b1111001 :
		(HEX1 == 4'h2) ? 7'b0100100 :
		(HEX1 == 4'h3) ? 7'b0110000 :
		(HEX1 == 4'h4) ? 7'b0011001 :
		(HEX1 == 4'h5) ? 7'b0010010 :
		(HEX1 == 4'h6) ? 7'b0000010 :
		(HEX1 == 4'h7) ? 7'b1111000 :
		(HEX1 == 4'h8) ? 7'b0000000 :
		(HEX1 == 4'h9) ? 7'b0010000 :
		(HEX1 == 4'hA) ? 7'b0001000 :
		(HEX1 == 4'hb) ? 7'b0000011 :
		(HEX1 == 4'hc) ? 7'b1000110 :
		(HEX1 == 4'hd) ? 7'b0100001 :
		(HEX1 == 4'he) ? 7'b0000110 :
		/*HEX1 == 4'hf*/ 7'b0001110 ;
   
	assign OUTHEX0 =
		(1'b0)         ? 7'b1111111 : /* IN == OFF */
		(HEX0 == 4'h0) ? 7'b1000000 :
		(HEX0 == 4'h1) ? 7'b1111001 :
		(HEX0 == 4'h2) ? 7'b0100100 :
		(HEX0 == 4'h3) ? 7'b0110000 :
		(HEX0 == 4'h4) ? 7'b0011001 :
		(HEX0 == 4'h5) ? 7'b0010010 :
		(HEX0 == 4'h6) ? 7'b0000010 :
		(HEX0 == 4'h7) ? 7'b1111000 :
		(HEX0 == 4'h8) ? 7'b0000000 :
		(HEX0 == 4'h9) ? 7'b0010000 :
		(HEX0 == 4'hA) ? 7'b0001000 :
		(HEX0 == 4'hb) ? 7'b0000011 :
		(HEX0 == 4'hc) ? 7'b1000110 :
		(HEX0 == 4'hd) ? 7'b0100001 :
		(HEX0 == 4'he) ? 7'b0000110 :
		/*HEX0 == 4'hf*/ 7'b0001110 ;
  
	assign DBUS = selData ? HEXDATA :
					  {BITS{1'bz}};
	
endmodule
