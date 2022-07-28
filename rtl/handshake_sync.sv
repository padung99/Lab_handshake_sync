module handshake_sync #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 8
) (
  input  logic              clk_rd_i,
  input  logic              clk_wr_i,
  input  logic              srst_r_i,
  input  logic              srst_w_i,
  input  logic [DWIDTH-1:0] data_i,

  input  logic              wrreq_i,
  input  logic              rdreq_i,
  output logic [DWIDTH-1:0] q_o,
  output logic              empty_o,
  output logic              full_o,
  output logic [AWIDTH:0]   usedw_o,

  output logic              almost_full_o,
  output logic              almost_empty_o
);

logic [AWIDTH:0] raddr;
logic [AWIDTH:0] waddr;

logic [AWIDTH:0] next_raddr;
logic [AWIDTH:0] next_waddr;

logic            valid_rd;
logic            valid_wr;

logic            ack;
logic            req;

logic            wq1_ack;
logic            wq2_ack;

logic            rq1_req;
logic            rq2_req;

logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];

assign valid_rd = rq2_req && rdreq_i && !empty_o;
assign valid_wr = wq2_ack && wrreq_i && !full_o;

assign next_raddr = raddr + 1;
assign next_waddr = waddr + 1;

always_ff @( posedge clk_wr_i )
  begin
    if( srst_w_i )
      req <= 1;
    else
      begin
        if( wq2_ack )
          req <= 1;
        else if( rq2_req )
          req <= 0;

        { wq1_ack , wq2_ack } <= { ack, wq1_ack };
      end
  end

always_ff @( posedge clk_rd_i )
  begin
    if( srst_r_i )
      ack <= 0;
    else
      begin
        if( rq2_req )
          ack <= 1;
        else if( wq2_ack )
          ack <= 0;

        { rq1_req , rq2_req } <= { req, rq1_req };
      end
  end

always_ff @( posedge clk_rd_i )
  begin
    if( srst_r_i )
        raddr <= 0;
    else
      if( valid_rd )
        raddr <= next_raddr;
  end

always_ff @( posedge clk_wr_i )
  begin
    if( srst_w_i )
        waddr <= 0;
    else
      if( valid_wr )
        waddr <= next_waddr;
  end

always_ff @( posedge clk_wr_i )
  begin
    if( valid_wr )
      mem[waddr[AWIDTH-1:0]] <= data_i;
  end

always_ff @( posedge clk_rd_i )
  begin
    if( valid_rd )
      q_o <= mem[raddr[AWIDTH-1:0]];
  end

assign empty_o = ( raddr == waddr );
assign full_o  = ( raddr[AWIDTH] != waddr[AWIDTH] ) &&
                 ( raddr[AWIDTH-1:0] == waddr[AWIDTH-1:0] );

endmodule
