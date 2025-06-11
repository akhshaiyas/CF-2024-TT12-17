`timescale 1ns/1ps

module set_associative_wt #( 
    parameter MAPPING     = "set_assoc",
    parameter WRITING     = "write_through",  // write-through policy
    parameter REPLACEMENT = "LFU_FIFO",
    parameter CACHE_SIZE  = 64,
    parameter NOOFBLOCK   = 4
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] address,
    input  wire        is_write,
    input  wire [31:0] write_data,
    output reg         hit,
    output reg [31:0]  read_data
);

    localparam SETS       = CACHE_SIZE / NOOFBLOCK;
    localparam INDEX_BITS = $clog2(SETS);
    localparam TAG_BITS   = 32 - INDEX_BITS - 2;

    // Simulated main memory
    reg [31:0] main_memory [0:1023];

    // Cache storage
    reg [TAG_BITS-1:0] tag_array [0:SETS-1][0:NOOFBLOCK-1];
    reg [31:0]         data_array[0:SETS-1][0:NOOFBLOCK-1];
    reg                valid     [0:SETS-1][0:NOOFBLOCK-1];
    reg                fifobit   [0:SETS-1][0:NOOFBLOCK-1];
    reg [3:0]          frequency [0:SETS-1][0:NOOFBLOCK-1];

    wire [INDEX_BITS-1:0] index     = address[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   tag       = address[31:INDEX_BITS+2];
    wire [9:0]            mem_addr  = address[11:2];

    integer i, s, w;
    reg found;
    integer hit_way;
    integer victim_way;
    integer min_freq;
    integer fifo_p;

    // Hit Detection
    always @(*) begin
        hit      = 0;
        read_data= 32'hDEADBEEF;
        found    = 0;
        hit_way  = -1;

        for (i = 0; i < NOOFBLOCK; i = i + 1) begin
            if (!found && valid[index][i] && tag_array[index][i] == tag) begin
                found   = 1;
                hit     = 1;
                hit_way = i;
                read_data = data_array[index][i];
            end
        end
    end

    // LFU + FIFO Victim Selection
    always @(*) begin
        victim_way = 0;
        min_freq = frequency[index][0];
        fifo_p = fifobit[index][0];

        for (i = 1; i < NOOFBLOCK; i = i + 1) begin
            if ((frequency[index][i] < min_freq) || 
                ((frequency[index][i] == min_freq) && (fifobit[index][i] < fifo_p))) begin
                victim_way = i;
                min_freq = frequency[index][i];
                fifo_p = fifobit[index][i];
            end
        end
    end

    // Main Sequential Cache Behavior
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (s = 0; s < SETS; s = s + 1) begin
                for (w = 0; w < NOOFBLOCK; w = w + 1) begin
                    valid[s][w]     <= 0;
                    frequency[s][w] <= 0;
                    fifobit[s][w]   <= 0;
                    tag_array[s][w] <= 0;
                    data_array[s][w]<= 0;
                end
            end
        end else begin
            if (found) begin
                if (is_write) begin
                    data_array[index][hit_way] <= write_data;
                    main_memory[mem_addr] <= write_data;
                end
                if (frequency[index][hit_way] < 15)
                    frequency[index][hit_way] <= frequency[index][hit_way] + 1;
                fifobit[index][hit_way] <= 1;
            end else begin
                if (is_write) begin
                    main_memory[mem_addr] <= write_data;
                end else begin
                    tag_array[index][victim_way]   <= tag;
                    data_array[index][victim_way]  <= main_memory[mem_addr];
                    valid[index][victim_way]       <= 1;
                    frequency[index][victim_way]   <= 1;
                    fifobit[index][victim_way]     <= 0;
                end
            end
        end
    end

endmodule
