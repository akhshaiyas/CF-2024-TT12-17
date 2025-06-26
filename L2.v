`timescale 1ns/1ps
module L2#(
    parameter CACHE_SIZE  = 256
    parameter INDEX_BITS   = 8,
    parameter OFFSET_BITS  = 2,
    parameter TAG_BITS     = 22,
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32
)(
    input wire clk,
    input wire reset,
    //L1 cache interface
    input wire l1_valid, //valid request from L1 cache
    input wire [31:0] addr, // access address from L1 cache
    input wire l1_is_write, //write/read request from L1 cache
    input wire [31:0] l1_w_data, //write data from L1 cache

    output reg valid_out,  // response valid to L1 cache by L2 cache
    output reg l1_hit, //data hit in L2 cache (response to L1 cache request)
    output reg [31:0] r_data, //read data from L2 cache to L1 cache

    //L2 cache interface
    input wire l2_ready, //L2 cache is ready to accept request
    input wire [31:0] l2_r_data, //read data from L2 cache to memory
    output reg l2_valid, //valid request from L2 cache
    output reg [31:0] l2_wb_data, //write data from L2 cache to memory
    output reg [31:0] l2_addr, //address to L2 cache
    output reg l2_is_write //write/read request to L2 cache
);

    reg [31:0] tag_array [0:CACHE_SIZE-1] ;
    reg [31:0] data_array [0:CACHE_SIZE-1];
    reg valid_array [0:CACHE_SIZE-1];
    reg dirty_array [0:CACHE_SIZE-1];

    reg [2:0] state; // FSM state
    localparam IDLE = 3'd0; // idle state - waiting for request from L1 cache
    localparam TAG_CHECK = 3'd1;    // check for hit/miss in L2
    localparam HIT = 3'd2; // read/write hit in L2 cache
    localparam MISS = 3'd3; // choose victim block and possibly write back
    localparam WRITE_BACK = 3'd4; //evict dirty block to memory
    localparam MEM_READ = 3'd5; // fetch data from memory
    localparam REFILL = 3'd6; // update L2 with fetch block
    localparam RESPOND = 3'd7; // send data back to L1 cache


    wire [21:0] tag = addr[31:10]; // tag for the address
    wire [7:0]  index = addr[9:2]; // index for the cache
    wire [1:0]  offset = addr[1:0]; // offset for the cache

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid_out <= 0;
            l1_hit <= 0;
            r_data <= 0;
            l2_valid <= 0;
            l2_wb_data <= 0;
            l2_addr <= 0;
            l2_is_write <= 0;
        end else begin
            // Default signal reset
            valid_out <= 0;
            l2_valid <= 0;
            l2_is_write <= 0;

            case (state)
                IDLE: begin
                    if (l1_valid && l2_ready) begin
                        state <= TAG_CHECK;
                    end
                end

                TAG_CHECK: begin
                    if (valid_array[index] && tag_array[index] == tag) begin
                        // Hit in L2
                        l1_hit <= 1;
                        if (l1_is_write) begin
                            data_array[index] <= l1_w_data;
                            dirty_array[index] <= 1;
                        end
                        r_data <= data_array[index];
                        state <= HIT;
                    end else begin
                        // Miss in L2
                        l1_hit <= 0;
                        state <= MISS;
                    end
                end

                HIT: begin
                    valid_out <= 1;
                    state <= IDLE;
                end

                MISS: begin
                    if (dirty_array[index]) begin
                        l2_valid <= 1;
                        l2_wb_data <= data_array[index];
                        l2_addr <= {tag_array[index], index, 2'b00};
                        l2_is_write <= 1;
                        state <= WRITE_BACK;
                    end else begin
                        state <= MEM_READ;
                    end
                end

                WRITE_BACK: begin
                    if (l2_ready) begin
                        state <= MEM_READ;
                    end
                end

                MEM_READ: begin
                    l2_valid <= 1;
                    l2_addr <= {tag, index, 2'b00};
                    l2_is_write <= 0;
                    state <= REFILL;
                end

                REFILL: begin
                    data_array[index] <= l2_r_data;
                    tag_array[index] <= tag;
                    valid_array[index] <= 1;
                    dirty_array[index] <= l1_is_write; // mark dirty if this was a write
                    if (l1_is_write) begin
                        data_array[index] <= l1_w_data; // write incoming data
                    end
                    state <= RESPOND;
                end

                RESPOND: begin
                    r_data <= data_array[index];
                    valid_out <= 1;
                    l1_hit <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
