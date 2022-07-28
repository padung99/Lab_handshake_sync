module handshake_sync_tb;
parameter DWIDTH_TB             = 16;
parameter AWIDTH_TB             = 4;
parameter SHOWAHEAD_TB          = "OFF";
parameter ALMOST_FULL_VALUE_TB  = 2**AWIDTH_TB-3;
parameter ALMOST_EMPTY_VALUE_TB = 3;
parameter REGISTER_OUTPUT_TB    = "OFF";

parameter WRITE_UNTIL_FULL       = 2**AWIDTH_TB + 5;
parameter MAX_DATA_RANDOM        = 100;

parameter MANY_WRITE_REQUEST     = 100;
parameter MANY_READ_REQUEST      = 100;

parameter MAX_DATA_SEND          = WRITE_UNTIL_FULL + MANY_WRITE_REQUEST + MANY_READ_REQUEST;
parameter READ_UNTIL_EMPTY       = WRITE_UNTIL_FULL;

logic                  srst_r_i_tb;
logic                  srst_w_i_tb;

logic [DWIDTH_TB-1:0]  data_i_tb;

bit                    wrreq_i_tb;
bit                    rdreq_i_tb;

logic [DWIDTH_TB-1:0]  q_o_tb;
logic                  empty_o_tb;
logic                  full_o_tb;

logic [DWIDTH_TB-1:0]  q_o_tb2;
logic                  empty_o_tb2;
logic                  full_o_tb2;


logic [AWIDTH_TB:0]    usedw_o_tb;

logic                  almost_full_o_tb;
logic                  almost_empty_o_tb;


bit clk_wr_i_tb;
bit clk_rd_i_tb;

int cnt_wr_data;
initial
  forever
    #5 clk_wr_i_tb = !clk_wr_i_tb;

initial
  forever
    #10 clk_rd_i_tb = !clk_rd_i_tb;

default clocking cb
  @ (posedge clk_wr_i_tb);
endclocking

`define cb_rd @( posedge clk_rd_i_tb ); 

handshake_sync #(
  .DWIDTH             ( DWIDTH_TB             ),
  .AWIDTH             ( AWIDTH_TB             )
) dut1(
  .clk_wr_i          ( clk_wr_i_tb          ),
  .clk_rd_i          ( clk_rd_i_tb          ),
  .srst_w_i          ( srst_w_i_tb          ),
  .srst_r_i          ( srst_r_i_tb          ),
  .data_i            ( data_i_tb            ),

  .wrreq_i           ( wrreq_i_tb         ),
  .rdreq_i           ( rdreq_i_tb         ),
  .q_o               ( q_o_tb             ),
  .empty_o           ( empty_o_tb         ),
  .full_o            ( full_o_tb          ),
  .usedw_o           ( usedw_o_tb         ),

  .almost_full_o     ( almost_full_o_tb  ),
  .almost_empty_o    ( almost_empty_o_tb )
);


mailbox #( logic [DWIDTH_TB-1:0] ) data_gen   = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_write = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_read  = new();
mailbox #( logic [DWIDTH_TB-1:0] ) full_data_wr = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_rd_qr = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_wr_qr = new();

task gen_data( mailbox #( logic [DWIDTH_TB-1:0] ) _data,
               mailbox #( logic [DWIDTH_TB-1:0] ) _full_wr,
               mailbox #( logic [DWIDTH_TB-1:0] ) _rd,
               mailbox #( logic [DWIDTH_TB-1:0] ) _wr
             );

logic [DWIDTH_TB-1:0] data_s;

  for( int i = 0; i < WRITE_UNTIL_FULL; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TB-1,0 );
      _full_wr.put( data_s );
    end

  for( int i = 0; i < MANY_WRITE_REQUEST; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TB-1,0 );
      _wr.put( data_s );
    end

  for( int i = 0; i < MANY_READ_REQUEST; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TB-1,0 );
      _rd.put( data_s );
    end
endtask

task wr_until_full( mailbox #( logic [DWIDTH_TB-1:0] ) _full_wr,
                    mailbox #( logic [DWIDTH_TB-1:0] ) _data_wr
                  );
logic [DWIDTH_TB-1:0] data_wr;

while( _full_wr.num() != 0 )
  begin
    cnt_wr_data++;
    _full_wr.get( data_wr );
    wrreq_i_tb = 1'b1;

    if( full_o_tb == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_wr.put( data_wr );
        data_i_tb = data_wr;
      end
    ##1;
  end
wrreq_i_tb = 1'b0;
endtask

task rd_until_empty( mailbox #( logic [DWIDTH_TB-1:0] ) _data_rd );

for( int i = 0; i < READ_UNTIL_EMPTY; i++ )
  begin
    cnt_wr_data++;
    rdreq_i_tb = 1'b1;
    if( empty_o_tb == 1'b0 && rdreq_i_tb == 1'b1 )
      begin
        _data_rd.put( q_o_tb );
      end
    `cb_rd;
  end
endtask

task wr_REQUEST ( input int _lower_wr,
                        int _upper_wr, 
                  mailbox #( logic [DWIDTH_TB-1:0] ) _wr,
                  mailbox #( logic [DWIDTH_TB-1:0] ) _data_wr
                );

logic [DWIDTH_TB-1:0] data_wr;
int pause_wr;
int cnt_wr;

while( _wr.num() != 0 )
  begin

    if( pause_wr == 0 )
      begin
        cnt_wr_data++;
        _wr.get( data_wr );
        //Change _upper_wr,_lower_wr to change read frequency
        pause_wr   = $urandom_range( _upper_wr,_lower_wr );
        wrreq_i_tb = 0;
      end
    else
      begin
        wrreq_i_tb = 1;
      end

    if( full_o_tb == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_wr.put( data_wr );
        data_i_tb = data_wr;
      end
    pause_wr--;
    ##1;
  end

endtask

task rd_fifo ( input int cnt_data_rd,
                     int _lower_rd,
                     int _upper_rd,
                mailbox #( logic [DWIDTH_TB-1:0] ) _data_rd
              );

int pause_rd;
int i;
i = 0;
while( cnt_wr_data < cnt_data_rd )
  begin
    if( pause_rd == 0 )
      begin
        //Change _upper_rd,_lower_rd to change read frequency
        pause_rd   = $urandom_range( _upper_rd,_lower_rd );
        rdreq_i_tb = 0;
      end
    else
      rdreq_i_tb = 1;
   
    if( empty_o_tb == 1'b0 && rdreq_i_tb == 1'b1 )
      begin
        _data_rd.put( q_o_tb );
      end
    pause_rd--;
    `cb_rd;
  end
endtask


task testing ( mailbox #( logic [DWIDTH_TB-1:0] ) _rd_data,
               mailbox #( logic [DWIDTH_TB-1:0] ) _data_s
             );
logic [DWIDTH_TB-1:0] new_rd_data;
logic [DWIDTH_TB-1:0] new_data_s;
int total_data_send;
bit data_error;

total_data_send = _data_s.num();

while( _rd_data.num() != 0 && _data_s.num() != 0 )
  begin
    _rd_data.get( new_rd_data );
    _data_s.get( new_data_s );
    
    if( new_rd_data != new_data_s )
      begin
        data_error = 1;
        // $stop();
      end

  end

if( !data_error )
  begin
    $display( "Test completed - No error!!!\n" );
  end

$display( "Total data send: %0d", total_data_send - _data_s.num() );

if( _data_s.num() != 0 )
  begin
    $display("%0d more data in sending mailbox!!!", _data_s.num() );
    while( _data_s.num() != 0 )
      begin
        _data_s.get( new_data_s );
        $display("%x", new_data_s );
      end      
  end
else
  $display("Sending mailbox is empty!!!");

if( _rd_data.num() != 0 )
  begin
    $display("%0d more data in reading mailbox!!!", _rd_data.num() );
    while( _rd_data.num() != 0 )
      begin
        _rd_data.get( new_rd_data );
        $display("%x", new_rd_data );
      end
  end
else
  $display("Reading mailbox is empty!!!");
endtask

initial
  begin
    srst_w_i_tb <= 1'b1;
    srst_r_i_tb <= 1'b1;
    ##1;
    srst_w_i_tb <= 1'b0;
    `cb_rd; 
    srst_r_i_tb <= 1'b0;
    
    
    //Write to fifo until full
    $display("###Write data until full###");
    gen_data( data_gen, full_data_wr, data_rd_qr, data_wr_qr );

    wr_until_full( full_data_wr, data_write );
    
    cnt_wr_data = 0;
    
    //Read from fifo until empty
    $display("###Read data from fifo until empty###");

    rd_until_empty( data_read );


    cnt_wr_data = 0;
    
    //Write REQUEST more than read REQUEST
    $display("###Write REQUEST more than read REQUEST###");
    fork
      wr_REQUEST( 4,6, data_wr_qr, data_write );
      rd_fifo( MANY_WRITE_REQUEST, 1,2, data_read );
    join
  
    cnt_wr_data = 0;

    //Read REQUEST more than write REQUEST
    $display("###Read REQUEST more than write REQUEST###");
    fork
      wr_REQUEST( 1,2, data_rd_qr, data_write );
      rd_fifo( MANY_READ_REQUEST, 4,6, data_read );
    join
    
    $display("###Start testing write data and read data");
    testing( data_read, data_write );

    $display( "Test done!" );

    $stop();
  end
endmodule