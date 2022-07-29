module handshake_sync_tb;
parameter DATA_W_TB             = 16;
parameter AWIDTH_TB             = 4;

parameter MAX_DATA              = 100;

bit                    clk_a_i_tb;
bit                    clk_b_i_tb;

logic                  srst_a_i_tb;
logic                  srst_b_i_tb;

logic  [DATA_W_TB-1:0] data_a_i_tb;
logic                  data_a_val_i_tb;
logic                  data_a_ready_o_tb;

logic [DATA_W_TB-1:0]  data_b_o_tb;
logic                  data_b_val_o_tb;

bit send_done;

initial
  forever
    #16 clk_a_i_tb = !clk_a_i_tb;

initial
  forever
    #7 clk_b_i_tb = !clk_b_i_tb;

default clocking cb
  @ (posedge clk_a_i_tb);
endclocking

`define cb_b @( posedge clk_b_i_tb );

handshake_sync #(
  .DATA_W         ( DATA_W_TB         )
) handshake_inst(
  .clk_a_i        ( clk_a_i_tb        ),
  .clk_b_i        ( clk_b_i_tb        ),

  .srst_a_i       ( srst_a_i_tb       ),
  .srst_b_i       ( srst_b_i_tb       ),

  .data_a_i       ( data_a_i_tb       ),
  .data_a_val_i   ( data_a_val_i_tb   ),
  .data_a_ready_o ( data_a_ready_o_tb ),

  .data_b_o       ( data_b_o_tb       ),
  .data_b_val_o   ( data_b_val_o_tb   )
);

mailbox #( logic [DATA_W_TB-1:0] ) data_gen   = new();
mailbox #( logic [DATA_W_TB-1:0] ) valid_data_output = new();
mailbox #( logic [DATA_W_TB-1:0] ) valid_data_input = new();

task gen_data( mailbox #( logic [DATA_W_TB-1:0] ) _data_gen );

logic [DATA_W_TB-1:0] new_data;

for( int i = 0; i < MAX_DATA; i++ )
  begin
    new_data = $urandom_range( 2**DATA_W_TB-1,0 );
    _data_gen.put( new_data );
  end
endtask

task send( mailbox #( logic [DATA_W_TB-1:0] ) _data_gen,
           mailbox #( logic [DATA_W_TB-1:0] ) _data_valid_input,
           input bit _send_all_data
         );

logic [DATA_W_TB-1:0] new_data;
int pause;

while( _data_gen.num() != 0 )
  begin
    if( data_a_ready_o_tb )
      begin
        _data_gen.get( new_data );
        if( _send_all_data )
          data_a_val_i_tb = 1;
        else
          data_a_val_i_tb = $urandom_range( 1,0 );

        data_a_i_tb = new_data;

        if( data_a_val_i_tb == 1'b1 )
          _data_valid_input.put( data_a_i_tb );

        ##1;
        data_a_val_i_tb = 1'b0;
        pause = $urandom_range( 13, 20 );
        ##pause;
      end
  end

send_done = 1;

endtask

task valid_output ( mailbox #( logic [DATA_W_TB-1:0] ) _data_valid_output );

logic [DATA_W_TB-1:0] new_data_valid;


forever
  begin
    `cb_b;
    if( data_b_val_o_tb == 1'b1 )
      _data_valid_output.put( data_b_o_tb );
    if( send_done )
      break;
  end

endtask

task testing( mailbox #( logic [DATA_W_TB-1:0] ) _data_valid_input,
              mailbox #( logic [DATA_W_TB-1:0] ) _data_valid_output );

logic [DATA_W_TB-1:0] data_input;
logic [DATA_W_TB-1:0] data_output;

int num_inp_data;
int num_out_data;

num_inp_data = _data_valid_input.num();
num_out_data = _data_valid_output.num();

while( _data_valid_input.num() != 0 && _data_valid_output.num() != 0 )
  begin
    _data_valid_input.get( data_input );
    _data_valid_output.get( data_output );
    if( data_input != data_output )
      $error( "input and output mismatch --- input: %x | output: %x", data_input, data_output );
  end

if( _data_valid_input.num() != 0 )
  $display( "%0d more data in INPUT mailbox", num_inp_data- _data_valid_input.num() );
else
  $display( "INPUT mailbox is emtpty" );

if( _data_valid_output.num() != 0 )
  $display( "%0d more data in OUTPUT mailbox", num_out_data- _data_valid_output.num() );
else
  $display( "OUTPUT mailbox is emtpty" );

endtask

initial
  begin
    srst_a_i_tb <= 1'b1;
    srst_b_i_tb <= 1'b1;
    ##1;
    srst_a_i_tb <= 1'b0;
    `cb_b; 
    srst_b_i_tb <= 1'b0;

    $display( "###Sending ALL data" );
    gen_data( data_gen );

    fork
      send( data_gen, valid_data_input, 1 );
      valid_output( valid_data_output );
    join

    testing( valid_data_input, valid_data_output );

    $display( "###Sending RANDOM data" );
    data_gen   = new();
    valid_data_output = new();
    valid_data_input = new();

    gen_data( data_gen );

    fork
      send( data_gen, valid_data_input, 0 );
      valid_output( valid_data_output );
    join

    testing( valid_data_input, valid_data_output );

    $display( "Test done!" );

    $stop();
  end
endmodule