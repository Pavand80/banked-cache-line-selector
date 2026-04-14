`timescale 1ns/1ps

module scheduler_simple #(
  parameter int DATA_BITS = 32
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Port A
  input  logic                   reqA_v,
  output logic                   reqA_rdy,
  input  logic [2:0]             reqA_addr,    // [bank(2) index(1:0)]
  input  logic                   reqA_is_write,
  input  logic [DATA_BITS-1:0]   reqA_wdata,

  // Port B
  input  logic                   reqB_v,
  output logic                   reqB_rdy,
  input  logic [2:0]             reqB_addr,
  input  logic                   reqB_is_write,
  input  logic [DATA_BITS-1:0]   reqB_wdata,

  // To Bank0
  output logic                   bank0_req_v,
  input  logic                   bank0_req_rdy,
  output logic [1:0]             bank0_req_idx,
  output logic                   bank0_req_is_write,
  output logic [DATA_BITS-1:0]   bank0_req_wdata,
  output logic                   bank0_req_owner_isA, // 1 => A, 0 => B

  // To Bank1
  output logic                   bank1_req_v,
  input  logic                   bank1_req_rdy,
  output logic [1:0]             bank1_req_idx,
  output logic                   bank1_req_is_write,
  output logic [DATA_BITS-1:0]   bank1_req_wdata,
  output logic                   bank1_req_owner_isA,

  // From Bank0
  input  logic                   bank0_rsp_v,
  input  logic [DATA_BITS-1:0]   bank0_rsp_rdata,
  input  logic                   bank0_rsp_status,

  // From Bank1
  input  logic                   bank1_rsp_v,
  input  logic [DATA_BITS-1:0]   bank1_rsp_rdata,
  input  logic                   bank1_rsp_status,

  // Responses to Port A
  output logic                   rspA_v,
  input  logic                   rspA_rdy,
  output logic [DATA_BITS-1:0]   rspA_rdata,
  output logic                   rspA_status,

  // Responses to Port B
  output logic                   rspB_v,
  input  logic                   rspB_rdy,
  output logic [DATA_BITS-1:0]   rspB_rdata,
  output logic                   rspB_status
);

  // internal rr pointers and owner tracking (explicit)
  logic rr0, rr1;                       // 0 -> prefer A, 1 -> prefer B
  logic [1:0] owner0;                   // 0 none, 1 A, 2 B
  logic [1:0] owner1;

  // decode which bank the ports are targeting
  logic reqA_to_b0, reqA_to_b1;
  logic reqB_to_b0, reqB_to_b1;
  logic conflict0, conflict1;

  // defaults and combinational arbitration
  always_comb begin
    // default outputs
    bank0_req_v = 1'b0;
    bank1_req_v = 1'b0;
    bank0_req_idx = 2'b00;
    bank1_req_idx = 2'b00;
    bank0_req_is_write = 1'b0;
    bank1_req_is_write = 1'b0;
    bank0_req_wdata = '0;
    bank1_req_wdata = '0;
    bank0_req_owner_isA = 1'b0;
    bank1_req_owner_isA = 1'b0;

    reqA_rdy = 1'b0;
    reqB_rdy = 1'b0;

    // decode banks (bank is MSB => bit 2)
    reqA_to_b0 = reqA_v && (reqA_addr[2] == 1'b0);
    reqA_to_b1 = reqA_v && (reqA_addr[2] == 1'b1);
    reqB_to_b0 = reqB_v && (reqB_addr[2] == 1'b0);
    reqB_to_b1 = reqB_v && (reqB_addr[2] == 1'b1);

    conflict0 = reqA_to_b0 && reqB_to_b0;
    conflict1 = reqA_to_b1 && reqB_to_b1;

    // If no conflicts, try to issue requests for free banks
    if (!conflict0 && !conflict1) begin
      // Port A
      if (reqA_v) begin
        if (reqA_to_b0 && (owner0 == 2'b00)) begin
          bank0_req_v = 1'b1;
          bank0_req_owner_isA = 1'b1;
          bank0_req_is_write = reqA_is_write;
          bank0_req_wdata = reqA_wdata;
          bank0_req_idx = reqA_addr[1:0];
          reqA_rdy = 1'b1;
        end else if (reqA_to_b1 && (owner1 == 2'b00)) begin
          bank1_req_v = 1'b1;
          bank1_req_owner_isA = 1'b1;
          bank1_req_is_write = reqA_is_write;
          bank1_req_wdata = reqA_wdata;
          bank1_req_idx = reqA_addr[1:0];
          reqA_rdy = 1'b1;
        end
      end

      // Port B
      if (reqB_v) begin
        if (reqB_to_b0 && (owner0 == 2'b00)) begin
          bank0_req_v = 1'b1;
          bank0_req_owner_isA = 1'b0;
          bank0_req_is_write = reqB_is_write;
          bank0_req_wdata = reqB_wdata;
          bank0_req_idx = reqB_addr[1:0];
          reqB_rdy = 1'b1;
        end else if (reqB_to_b1 && (owner1 == 2'b00)) begin
          bank1_req_v = 1'b1;
          bank1_req_owner_isA = 1'b0;
          bank1_req_is_write = reqB_is_write;
          bank1_req_wdata = reqB_wdata;
          bank1_req_idx = reqB_addr[1:0];
          reqB_rdy = 1'b1;
        end
      end
    end else begin
      // handle conflicts per bank using rr pointer (explicit)
      // Bank0 conflict handling
      if (conflict0) begin
        if (owner0 == 2'b00) begin
          if (rr0 == 1'b0) begin
            // grant A, stall B
            bank0_req_v = 1'b1;
            bank0_req_owner_isA = 1'b1;
            bank0_req_is_write = reqA_is_write;
            bank0_req_wdata = reqA_wdata;
            bank0_req_idx = reqA_addr[1:0];
            reqA_rdy = 1'b1;
            reqB_rdy = 1'b0;
          end else begin
            // grant B
            bank0_req_v = 1'b1;
            bank0_req_owner_isA = 1'b0;
            bank0_req_is_write = reqB_is_write;
            bank0_req_wdata = reqB_wdata;
            bank0_req_idx = reqB_addr[1:0];
            reqB_rdy = 1'b1;
            reqA_rdy = 1'b0;
          end
        end
      end

      // Bank1 conflict handling
      if (conflict1) begin
        if (owner1 == 2'b00) begin
          if (rr1 == 1'b0) begin
            bank1_req_v = 1'b1;
            bank1_req_owner_isA = 1'b1;
            bank1_req_is_write = reqA_is_write;
            bank1_req_wdata = reqA_wdata;
            bank1_req_idx = reqA_addr[1:0];
            reqA_rdy = 1'b1;
            reqB_rdy = 1'b0;
          end else begin
            bank1_req_v = 1'b1;
            bank1_req_owner_isA = 1'b0;
            bank1_req_is_write = reqB_is_write;
            bank1_req_wdata = reqB_wdata;
            bank1_req_idx = reqB_addr[1:0];
            reqB_rdy = 1'b1;
            reqA_rdy = 1'b0;
          end
        end
      end
    end
  end // always_comb

  // sequential: set owner on bank accept, toggle rr on conflict-served, route responses
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rr0 <= 1'b0; rr1 <= 1'b0;
      owner0 <= 2'b00; owner1 <= 2'b00;
      rspA_v <= 1'b0; rspB_v <= 1'b0;
      rspA_rdata <= '0; rspB_rdata <= '0;
      rspA_status <= 1'b0; rspB_status <= 1'b0;
    end else begin
      // Bank0 accepted a request?
      if (bank0_req_v && bank0_req_rdy) begin
        if (bank0_req_owner_isA) owner0 <= 2'b01; else owner0 <= 2'b10;
        if (conflict0) rr0 <= ~rr0; // toggle rr only when it was a conflict
      end

      // Bank1 accepted a request?
      if (bank1_req_v && bank1_req_rdy) begin
        if (bank1_req_owner_isA) owner1 <= 2'b01; else owner1 <= 2'b10;
        if (conflict1) rr1 <= ~rr1;
      end

      // Bank0 response routing
      if (bank0_rsp_v) begin
        if (owner0 == 2'b01) begin
          rspA_v <= 1'b1;
          rspA_rdata <= bank0_rsp_rdata;
          rspA_status <= bank0_rsp_status;
        end else if (owner0 == 2'b10) begin
          rspB_v <= 1'b1;
          rspB_rdata <= bank0_rsp_rdata;
          rspB_status <= bank0_rsp_status;
        end
        owner0 <= 2'b00; // clear owner
      end

      // Bank1 response routing
      if (bank1_rsp_v) begin
        if (owner1 == 2'b01) begin
          rspA_v <= 1'b1;
          rspA_rdata <= bank1_rsp_rdata;
          rspA_status <= bank1_rsp_status;
        end else if (owner1 == 2'b10) begin
          rspB_v <= 1'b1;
          rspB_rdata <= bank1_rsp_rdata;
          rspB_status <= bank1_rsp_status;
        end
        owner1 <= 2'b00;
      end

      // clear responses when accepted by ports
      if (rspA_v && rspA_rdy) rspA_v <= 1'b0;
      if (rspB_v && rspB_rdy) rspB_v <= 1'b0;
    end
  end

endmodule
