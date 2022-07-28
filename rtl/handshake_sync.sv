module handshake_sync #(
   parameter DATA_W = 16 
) (
  input  logic              clk_a_i,
  input  logic              clk_b_i,

  input  logic              srst_a_i,
  input  logic              srst_b_i,

  input  logic [DATA_W-1:0] data_a_i,
  input  logic              data_a_val_i,
  output logic              data_a_ready_o,

  output logic [DATA_W-1:0] data_b_o,
  output logic              data_b_val_o
);

logic req;
logic ack;
logic b1_req;
logic b2_req;

logic a1_ack;
logic a2_ack;

always_ff @( posedge clk_a_i )
  begin
    if( srst_a_i )
      data_a_ready_o <= 1'b1;
    else
      begin
        if( data_a_val_i )
          data_a_ready_o <= 1'b0;
      end
  end

always_ff @( posedge clk_a_i )
  begin
    if( data_a_val_i )
      req <= 1'b1;
  end

always_ff @( posedge clk_a_i )
  begin
    if( srst_a_i )
      { a1_ack, a2_ack } <= 0;
    else
      { a1_ack, a2_ack } <= { ack, a1_ack };
  end

always_ff @( posedge clk_a_i )
  begin
    if( a2_ack )
      begin
        // req <= 1'b0;
        ack          <= 1'b0;
        if( a1_ack == 1'b0 )
          data_a_ready_o <= 1'b1;
      end
  end

always_ff @( posedge clk_b_i )
  begin
    if( srst_b_i )
      { b1_req, b2_req } <= 0;
    else
      { b1_req, b2_req } <= { req, b1_req };
  end

always_ff @( posedge clk_b_i )
  begin
    if( b2_req )
      begin
        data_b_o     <= data_a_i;
        // ack          <= 1'b0;
        req <= 1'b0;
      end
  end

always_ff @( posedge clk_b_i )
  begin
    if( data_b_val_o )
      ack <= 1'b1;
  end

always_ff @( posedge clk_b_i )
  begin
    if( srst_b_i )
      data_b_val_o <= 1'b0;
    else
      begin
        if( data_b_val_o )
          data_b_val_o <= 1'b0;
        if( b2_req )
          data_b_val_o <= req && b1_req && b2_req;
      end
        
  end

endmodule
