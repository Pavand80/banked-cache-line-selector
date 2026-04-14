`timescale 1ns/1ps
module tb_simple;
  parameter DATA_BITS = 32;

  logic clk;
  logic rst_n;

  // DUT port signals
  logic reqA_v; logic reqA_rdy;
  logic [2:0] reqA_addr; logic reqA_is_write;
  logic [DATA_BITS-1:0] reqA_wdata;
  logic rspA_v; logic rspA_rdy; logic [DATA_BITS-1:0] rspA_rdata;
  logic rspA_status;

  logic reqB_v; logic reqB_rdy;
  logic [2:0] reqB_addr; logic reqB_is_write;
  logic [DATA_BITS-1:0] reqB_wdata;
  logic rspB_v; logic rspB_rdy; logic [DATA_BITS-1:0] rspB_rdata; 
  logic rspB_status;

  // instantiate DUT
  top_simple #(.DATA_BITS(DATA_BITS)) dut (
    .clk(clk), .rst_n(rst_n),

    .reqA_v(reqA_v), .reqA_rdy(reqA_rdy),
    .reqA_addr(reqA_addr), .reqA_is_write(reqA_is_write), .reqA_wdata(reqA_wdata),

    .rspA_v(rspA_v), .rspA_rdy(rspA_rdy),
    .rspA_rdata(rspA_rdata), .rspA_status(rspA_status),

    .reqB_v(reqB_v), .reqB_rdy(reqB_rdy),
    .reqB_addr(reqB_addr), .reqB_is_write(reqB_is_write), .reqB_wdata(reqB_wdata),

    .rspB_v(rspB_v), .rspB_rdy(rspB_rdy),
    .rspB_rdata(rspB_rdata), .rspB_status(rspB_status)
  );

  // clock generation
  initial clk = 0;
  always #5 clk = ~clk; // 10ns

  // VCD DUMP
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_simple);
  end

  // tick helper
  task tick(input int n = 1);
    repeat(n) @(posedge clk);
  endtask

  // MAIN TEST SEQUENCE
  initial begin
    // RESET
    rst_n = 0;
    reqA_v = 0; reqB_v = 0;
    rspA_rdy = 1; rspB_rdy = 1;
    tick(5);   // extra gap for clean waveform
    rst_n = 1;
    tick(5);   // wait extra cycles after reset

    // TEST 1 — NO CONFLICT
    reqA_v = 1; 
    reqA_addr = 3'b010;
    reqA_is_write = 1; 
    reqA_wdata = 32'hA0A0;

    reqB_v = 1; 
    reqB_addr = 3'b101;
    reqB_is_write = 1; 
    reqB_wdata = 32'hB1B1;

    tick(2);  // extra 1 tick
    reqA_v = 0; reqB_v = 0;
    tick(6);  // extra spacing so waveform looks clean

    // TEST 2 — RR CONFLICT (same bank, different line)
    reqA_v = 1; 
    reqA_addr = 3'b000;
    reqA_is_write = 1;
    reqA_wdata = 32'h1111;

    reqB_v = 1;
    reqB_addr = 3'b011;
    reqB_is_write = 1;
    reqB_wdata = 32'h2222;

    tick(2); // 1 more tick for clarity

    // A was accepted first → drop A
    reqA_v = 0;
    tick(6);   // let B stay alive longer in waveform

    reqB_v = 0;
    tick(6);

    // TEST 3 — SAME BANK SAME LINE
    reqA_v = 1; 
    reqA_addr = 3'b110;
    reqA_is_write = 1;
    reqA_wdata = 32'hAAAA;

    reqB_v = 1;
    reqB_addr = 3'b110;
    reqB_is_write = 1;
    reqB_wdata = 32'hBBBB;

    tick(2);
    reqA_v = 0;
    tick(6);
    reqB_v = 0;
    tick(6);

    // TEST 4 — READ BACK BANK0
    for (int i = 0; i < 4; i++) begin
      reqA_v = 1;
      reqA_addr = {1'b0, i[1:0]};
      reqA_is_write = 0;
      tick(2);
      reqA_v = 0;
      tick(4);  
    end

    // TEST 4 — READ BACK BANK1
    for (int i = 0; i < 4; i++) begin
      reqB_v = 1;
      reqB_addr = {1'b1, i[1:0]};
      reqB_is_write = 0;
      tick(2);
      reqB_v = 0;
      tick(4);
    end

    tick(10);
    $finish;
  end

endmodule
