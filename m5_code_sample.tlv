\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/df57c0c25435c0ddac3555df620b4fc5bd535e30/lib/risc-v_shell_lib.tlv'])

\m5
   assemble_imem(['
      # /=====================\
      # | Count to 10 Program |
      # \=====================/
      #
      # Default program for RV32I test
      # Add 1,2,3,...,9 (in that order).
      # Store incremental results in memory locations 0..9. (1, 3, 6, 10, ...)
      #
      # Regs:
      # t0: cnt
      # a2: ten
      # a0: out
      # t1: final value
      # a1: expected result
      # t2: store addr
      reset:
         ORI t2, zero, 0          #     store_addr = 0
         ORI t0, zero, 1          #     cnt = 1
         ORI a2, zero, 10         #     ten = 10
         ORI a0, zero, 0          #     out = 0
      loop:
         ADD a0, t0, a0           #  -> out += cnt
         SW a0, 0(t2)             #     store out at store_addr
         ADDI t0, t0, 1           #     cnt++
         ADDI t2, t2, 4           #     store_addr++
         BLT t0, a2, loop         #  ^- branch back if cnt < 10
      # Result should be 0x2d.
         LW t1, -4(t2)            #     load the final value
         ADDI a1, zero, 0x2d      #     expected result (0x2d)
         BEQ t1, a1, pass         #     pass if as expected

         # Branch to one of these to report pass/fail to the default testbench.
      fail:
         ADD a1, a1, zero         #     nop fail
      pass:
         ADD t1, t1, zero         #     nop pass
   '])
\SV
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
   m5_my_defs
   /* verilator lint_on WIDTH */

\TLV
   $reset = *reset;
   
   
   // ZHK added code here
   
   //PC logic
   //$pc[31:0] = >>1$next_pc;
   //$add[31:0] = $pc[31:0] + 32'h4;
   
   //moved PC logic so that next_pc can adapt for branch instructions
   //$next_pc[31:0] = 
     // $reset == 1'b0
       //  ? $pc[31:0] + 32'h4 :
      //default 
      //32'b0;

   // IMem logic
   `READONLY_MEM($pc, $$instr[31:0]);
   
   // Decode logic
   
   //opcode is in last 7 bits in instruction
   //last 2 are always 11 so they are ignored in this comparison
   
   //one way of looking at last seven bits instruction. 
   //$is_u_instr = $instr[6:2] == 5'b00101 ||
   //              $instr[6:2] == 5'b01101;
   
   //$is_i_instr = $instr[6:2] == 5'b00000 ||
   //				    $instr[6:2] == 5'b00001 ||
   //              $instr[6:2] == 5'b00100 ||
   //              $instr[6:2] == 5'b00110 ||
   //					$instr[6:2] == 5'b11001;
   
   //$is_s_instr = $instr[6:2] == 5'b01000 ||
   //				  $instr[6:2] == 5'b01001;
   
   //$is_r_instr = $instr[6:2] == 5'b01011 ||
   //				  $instr[6:2] == 5'b01100 ||
   //              $instr[6:2] == 5'b01110 ||
   //              $instr[6:2] == 5'b10100;
   
   //another more concise way of doing this
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   
   $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                 $instr[6:2] ==? 5'b001x0 ||
                 $instr[6:2] ==? 5'b11001 ;
   
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   
   $is_b_instr = $instr[6:2] ==? 5'b11000;
   
   $is_j_instr = $instr[6:2] ==? 5'b11011;
   
   $is_r_instr = $instr[6:2] ==? 5'b01011 || 
      $instr[6:2] ==? 5'b011x0 ||
                 $instr[6:2] ==? 5'b10100;
   
   //extract fields from instructions
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   $rd[4:0] = $instr[11:7];
   $opcode[6:0] = $instr[6:0];
   
   
   //when the fields are valid
   //$opcode is always valid
   //$funct3 is valid whenever rs1 is valid
   //commented out some valid check since they were unused
   //$funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr; //same as rs1_valid
   $rs1_valid =  $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   
   //logic expression for immediate
   $imm[31:0] = $is_i_instr ? {  {21{$instr[31]}},  $instr[30:20]  } : 
      $is_s_instr ? {  {21{$instr[31]}},  $instr[30:25], $instr[11:7] } :
                $is_b_instr ? {  {20{$instr[31]}}, {$instr[7]}, $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? {$instr[31], $instr[30:12], 12'b0 } :
                $is_j_instr ? {  {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0} :
                32'b0;  // Default
   
   //decode bits
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};
   $is_beq = $dec_bits ==? 11'bx_000_1100011;  //this is the same for all comparison instructions
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   
   //extend decoder to decode additional instructions
   //these allow the decoder to that the mneomic for the instruction, otherwise it appears as ILLEGAL
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_slti = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   
   $is_sub = $dec_bits ==? 11'b1_000_0110011;
   $is_sll = $dec_bits ==? 11'b0_001_0110011;
   $is_slt = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011;
   $is_xor = $dec_bits ==? 11'b0_100_0110011;
   $is_srl = $dec_bits ==? 11'b0_101_0110011;
   $is_sra = $dec_bits ==? 11'b1_101_0110011;
   $is_or = $dec_bits ==? 11'b0_110_0110011;
   $is_and = $dec_bits ==? 11'b0_111_0110011;
   
   $is_load = $dec_bits ==? 11'bx_xxx_0000011;
   
   
   //RF logic
   $rd1_en = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr; 
   $rd1_index[4:0] = $rs1[4:0];
   
   $rd2_en = $is_r_instr || $is_s_instr || $is_b_instr; 
   $rd2_index[4:0] = $rs2[4:0];
   
   
   //ALU logic
   // SLTU, SLTI (set if less than, unsigned) results:
   $sltu_rslt[31:0] = {31'b0 , ($src1_value < $src2_value)};
   $sltiu_rslt[31:0] = {31'b0, ($src1_value < $imm)};
   
   // SRA and SRAI (shift right, arthmetic) results:
   //  sign-extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
   
   // 64 bit sign extended results to be truncated
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   
   // ALU result
   $result[31:0] =
    $is_andi ? $src1_value & $imm :
    $is_ori ? $src1_value | $imm :
    $is_xori ? $src1_value ^ $imm :
    $is_addi ? $src1_value + $imm :
    $is_slli ? $src1_value << $imm[5:0] :
    $is_srli ? $src1_value >> $imm[5:0] :
    $is_and ? $src1_value & $src2_value :
    $is_or ? $src1_value | $src2_value :
    $is_xor ? $src1_value ^ $src2_value :
    $is_add ? $src1_value + $src2_value :
    $is_sub ? $src1_value - $src2_value :
    $is_sll ? $src1_value << $src2_value[4:0] :
    $is_srl ? $src1_value >> $src2_value[4:0] :
    $is_sltu ? $sltu_rslt :
    $is_sltiu ? $sltiu_rslt :
    $is_lui ? { $imm[31:12] , 12'b0} :
    $is_auipc ? $pc + $imm :
    $is_jal ? $pc + 32'd4 :
    $is_jalr ? $pc + 32'd4 :
    $is_slt ? ( ($src1_value[31] == $src2_value[31]) ? $sltu_rslt : {31'b0 , $src1_value[31]} ) :
    $is_slti ? ( ($src1_value[31] == $imm[31]) ? $sltiu_rslt : {31'b0 , $src1_value[31]} ) :
    $is_sra ? $sra_rslt[31:0] :
    $is_srai ? $srai_rslt[31:0] :
    ($is_load || $is_s_instr) ? $src1_value + $imm :
    32'b0;
   
   // RF logic to disable write to X0 and enable writes of ALU result to other registers
   $is_rd_zero = $rd_valid ? 
      $rd ==? 5'b0 ? 1 : 0 : 0;
   $wr_en = ($is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr) && !$is_rd_zero;
   $wr_index[4:0] = $rd[4:0];
   //$wr_data[31:0] = $result[31:0]; // to add logic to write from DMEM to RF when is_load
   
   
   // DMEM logic
   $wr_data[31:0] = $is_load ? $ld_data : $result[31:0];
   
   //branch logic
   $taken_br = $is_beq ? ($src1_value == $src2_value) :
               $is_bne ? ($src1_value != $src2_value) :
               $is_blt ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
               $is_bge ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
               $is_bltu ? ($src1_value >= $src2_value) :
               $is_bgeu ? ($src1_value >= $src2_value) :
               1'b0;
   
   $br_tgt_pc[31:0] = $pc[31:0] + $imm[31:0];
   
   //JUMP logic
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   
   $next_pc[31:0] = 
      $taken_br ? $br_tgt_pc :
      $is_jal ? $br_tgt_pc :
      $is_jalr ? $jalr_tgt_pc :
      $reset ? 32'b0 :
      $pc[31:0] + 32'h4;
   
   //same idea as above, from the reference solution, for testing purposes
   //$next_pc[31:0] = $reset ? 32'b0 :
     //               $taken_br ? $br_tgt_pc :
       //             $pc[31:0] + 32'd4;
   
   $pc[31:0] = >>1$next_pc;

   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rd1_en, $rd1_index[4:0], $src1_value, $rd2_en, $rd2_index[4:0], $src2_value)
   m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value, $is_load, $ld_data)
   m4+cpu_viz()

\SV
   endmodule
