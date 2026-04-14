`include "bank_memory.sv"
`include "rr_scheduler.sv"
`timescale 1ns/1ps

module top_simple #(
  parameter int DATA_BITS = 32
)(
  input  logic                 clk,
  input  logic                 rst_n,

  // Port A
  input  logic                 reqA_v,
  output logic                 reqA_rdy,
  input  logic [2:0]           reqA_addr,
  input  logic                 reqA_is_write,
  input  logic [DATA_BITS-1:0] reqA_wdata,
  output logic                 rspA_v,
  input  logic                 rspA_rdy,
  output logic [DATA_BITS-1:0] rspA_rdata,
  output logic                 rspA_status,

  // Port B
  input  logic                 reqB_v,
  output logic                 reqB_rdy,
  input  logic [2:0]           reqB_addr,
  input  logic                 reqB_is_write,
  input  logic [DATA_BITS-1:0] reqB_wdata,
  output logic                 rspB_v,
  input  logic                 rspB_rdy,
  output logic [DATA_BITS-1:0] rspB_rdata,
  output logic                 rspB_status
);

  // wires between scheduler and banks (explicit)
  logic bank0_req_v, bank0_req_rdy;
  logic [1:0] bank0_req_idx;
  logic bank0_req_is_write;
  logic [DATA_BITS-1:0] bank0_req_wdata;
  logic bank0_req_owner_isA;

  logic bank1_req_v, bank1_req_rdy;
  logic [1:0] bank1_req_idx;
  logic bank1_req_is_write;
  logic [DATA_BITS-1:0] bank1_req_wdata;
  logic bank1_req_owner_isA;

  logic bank0_rsp_v;
  logic [DATA_BITS-1:0] bank0_rsp_rdata;
  logic bank0_rsp_status;

  logic bank1_rsp_v;
  logic [DATA_BITS-1:0] bank1_rsp_rdata;
  logic bank1_rsp_status;

  // scheduler instance
  scheduler_simple #(.DATA_BITS(DATA_BITS)) scheduler_inst (
    .clk(clk), .rst_n(rst_n),

    // port A
    .reqA_v(reqA_v), .reqA_rdy(reqA_rdy),
    .reqA_addr(reqA_addr), .reqA_is_write(reqA_is_write), .reqA_wdata(reqA_wdata),

    // port B
    .reqB_v(reqB_v), .reqB_rdy(reqB_rdy),
    .reqB_addr(reqB_addr), .reqB_is_write(reqB_is_write), .reqB_wdata(reqB_wdata),

    // bank0 connection
    .bank0_req_v(bank0_req_v), .bank0_req_rdy(bank0_req_rdy),
    .bank0_req_idx(bank0_req_idx), .bank0_req_is_write(bank0_req_is_write),
    .bank0_req_wdata(bank0_req_wdata), .bank0_req_owner_isA(bank0_req_owner_isA),

    // bank1 connection
    .bank1_req_v(bank1_req_v), .bank1_req_rdy(bank1_req_rdy),
    .bank1_req_idx(bank1_req_idx), .bank1_req_is_write(bank1_req_is_write),
    .bank1_req_wdata(bank1_req_wdata), .bank1_req_owner_isA(bank1_req_owner_isA),

    // bank responses
    .bank0_rsp_v(bank0_rsp_v), .bank0_rsp_rdata(bank0_rsp_rdata), .bank0_rsp_status(bank0_rsp_status),
    .bank1_rsp_v(bank1_rsp_v), .bank1_rsp_rdata(bank1_rsp_rdata), .bank1_rsp_status(bank1_rsp_status),

    // responses to ports
    .rspA_v(rspA_v), .rspA_rdy(rspA_rdy), .rspA_rdata(rspA_rdata), .rspA_status(rspA_status),
    .rspB_v(rspB_v), .rspB_rdy(rspB_rdy), .rspB_rdata(rspB_rdata), .rspB_status(rspB_status)
  );

  // instantiate bank0
  bank #(.DATA_BITS(DATA_BITS), .INDEX_BITS(2)) bank0_inst (
    .clk(clk), .rst_n(rst_n),
    .req_v(bank0_req_v), .req_rdy(bank0_req_rdy),
    .req_idx(bank0_req_idx), .req_is_write(bank0_req_is_write), .req_wdata(bank0_req_wdata),
    .rsp_v(bank0_rsp_v), .rsp_rdy(1'b1), .rsp_rdata(bank0_rsp_rdata), .rsp_status(bank0_rsp_status)
  );

  // instantiate bank1
  bank #(.DATA_BITS(DATA_BITS), .INDEX_BITS(2)) bank1_inst (
    .clk(clk), .rst_n(rst_n),
    .req_v(bank1_req_v), .req_rdy(bank1_req_rdy),
    .req_idx(bank1_req_idx), .req_is_write(bank1_req_is_write), .req_wdata(bank1_req_wdata),
    .rsp_v(bank1_rsp_v), .rsp_rdy(1'b1), .rsp_rdata(bank1_rsp_rdata), .rsp_status(bank1_rsp_status)
  );

endmodule
