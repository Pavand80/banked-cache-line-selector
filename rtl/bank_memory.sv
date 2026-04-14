`timescale 1ns/1ps

module bank #(
  parameter int DATA_BITS = 32,
  parameter int INDEX_BITS = 2   // 2 bits -> 4 lines
) (
  input  logic                      clk,
  input  logic                      rst_n,

  // request side (from scheduler)
  input  logic                      req_v,
  output logic                      req_rdy,    // bank can accept new request when idle
  input  logic [INDEX_BITS-1:0]     req_idx,
  input  logic                      req_is_write,
  input  logic [DATA_BITS-1:0]      req_wdata,

  // response side (to scheduler)
  output logic                      rsp_v,
  input  logic                      rsp_rdy,
  output logic [DATA_BITS-1:0]      rsp_rdata,
  output logic                      rsp_status
);

  // small memory
  logic [DATA_BITS-1:0] mem [0: (1<<INDEX_BITS)-1];

  typedef enum logic [1:0] {B_IDLE, B_RESP} bstate_t;
  bstate_t state, state_n;

  // latched request info
  logic [INDEX_BITS-1:0] lat_idx;
  logic lat_is_write;
  logic [DATA_BITS-1:0] lat_wdata;

  // comb outputs
  always_comb begin
    req_rdy = (state == B_IDLE);
    rsp_v   = (state == B_RESP);
    rsp_rdata = '0;
    rsp_status = 1'b0;

    if (state == B_RESP) begin
      rsp_status = 1'b1;
      // return read data (or reflect current content for write)
      rsp_rdata = mem[lat_idx];
    end
  end

  // sequential: capture requests, update memory, clear on rsp consume
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= B_IDLE;
      lat_idx <= '0;
      lat_is_write <= 1'b0;
      lat_wdata <= '0;
      // initialize small memory to zero
      for (int i = 0; i < (1<<INDEX_BITS); i++) mem[i] <= '0;
    end else begin
      state <= state_n;
      if (state == B_IDLE) begin
        if (req_v && req_rdy) begin
          // capture
          lat_idx <= req_idx;
          lat_is_write <= req_is_write;
          lat_wdata <= req_wdata;
          // synchronous write on accept
          if (req_is_write) mem[req_idx] <= req_wdata;
        end
      end else if (state == B_RESP) begin
        if (rsp_rdy) begin
          // when response consumed we will move to IDLE (handled by next-state)
        end
      end
    end
  end

  // next-state logic
  always_comb begin
    state_n = state;
    case (state)
      B_IDLE: if (req_v && req_rdy) state_n = B_RESP;
      B_RESP: if (rsp_rdy) state_n = B_IDLE;
    endcase
  end

endmodule
