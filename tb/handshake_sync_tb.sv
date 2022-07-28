module handshake_sync_tb;
parameter DATA_W_TB             = 16;
parameter AWIDTH_TB             = 4;

parameter MAX_DATA              = 100;

parameter WRITE_UNTIL_FULL       = 2**AWIDTH_TB + 5;
parameter MAX_DATA_RANDOM        = 100;

parameter MANY_WRITE_REQUEST     = 100;
parameter MANY_READ_REQUEST      = 100;

parameter MAX_DATA_SEND          = WRITE_UNTIL_FULL + MANY_WRITE_REQUEST + MANY_READ_REQUEST;
parameter READ_UNTIL_EMPTY       = WRITE_UNTIL_FULL;

bit               clk_a_i_tb;
bit               clk_b_i_tb;

logic               srst_a_i_tb;
logic               srst_b_i_tb;

logic  [DATA_W_TB-1:0] data_a_i_tb;
logic               data_a_val_i_tb;
logic              data_a_ready_o_tb;

logic [DATA_W_TB-1:0] data_b_o_tb;
logic             data_b_val_o_tb;


initial
  forever
    #10 clk_a_i_tb = !clk_a_i_tb;

initial
  forever
    #5 clk_b_i_tb = !clk_b_i_tb;

default clocking cb
  @ (posedge clk_a_i_tb);
endclocking

`define cb_b @( posedge clk_b_i_tb );

handshake_sync #(
  .DATA_W ( DATA_W_TB )
) handshake_inst(
  .clk_a_i ( clk_a_i_tb ),
  .clk_b_i ( clk_b_i_tb ),

  .srst_a_i ( srst_a_i_tb ),
  .srst_b_i ( srst_b_i_tb ),

  .data_a_i ( data_a_i_tb ),
  .data_a_val_i ( data_a_val_i_tb ),
  .data_a_ready_o ( data_a_ready_o_tb ),

  .data_b_o ( data_b_o_tb ),
  .data_b_val_o ( data_b_val_o_tb )
);


mailbox #( logic [DATA_W_TB-1:0] ) data_gen   = new();
// mailbox #( logic [DWIDTH_TB-1:0] ) data_write = new();
// mailbox #( logic [DWIDTH_TB-1:0] ) data_read  = new();
// mailbox #( logic [DWIDTH_TB-1:0] ) full_data_wr = new();
// mailbox #( logic [DWIDTH_TB-1:0] ) data_rd_qr = new();
// mailbox #( logic [DWIDTH_TB-1:0] ) data_wr_qr = new();

task gen_data( mailbox #( logic [DATA_W_TB-1:0] ) _data_gen );

logic [DATA_W_TB-1:0] new_data;

for( int i = 0; i < MAX_DATA; i++ )
  begin
    new_data = $urandom_range( 2**DATA_W_TB-1,0 );
    _data_gen.put( new_data );
  end
endtask

task send( mailbox #( logic [DATA_W_TB-1:0] ) _data_gen );

logic [DATA_W_TB-1:0] new_data;

while( _data_gen.num() != 0 )
  begin
    if( data_a_ready_o_tb )
      begin
        _data_gen.get( new_data );
        data_a_val_i_tb = 1'b1;
        data_a_i_tb = new_data;
        ##1;
        data_a_val_i_tb = 1'b0;
        ##15;
      end
  end

endtask


initial
  begin
    srst_a_i_tb <= 1'b1;
    srst_b_i_tb <= 1'b1;
    ##1;
    srst_a_i_tb <= 1'b0;
    `cb_b; 
    srst_b_i_tb <= 1'b0;
    
    gen_data( data_gen );
    send( data_gen );
    // ##2;
    // data_a_i_tb <= 16'h1;
    // data_a_val_i_tb <= 1'b1;
    // ##1;
    // data_a_val_i_tb <= 1'b0;

    // ##12;
    // data_a_i_tb <= 16'h5;
    // data_a_val_i_tb <= 1'b1;
    // ##1;
    // data_a_val_i_tb <= 1'b0;

    // ##15;
    // data_a_i_tb <= 16'h15;
    // data_a_val_i_tb <= 1'b1;
    // ##1;
    // data_a_val_i_tb <= 1'b0;

    // ##20;
    
    $display( "Test done!" );

    $stop();
  end
endmodule