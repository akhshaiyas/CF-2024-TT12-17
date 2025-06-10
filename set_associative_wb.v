`timescale 1ns/1ps

module set_associative_wb #(
    parameter MAPPING     = "set_assoc",
    parameter WRITING     = "write_back",
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

    // Derived parameters
    localparam integer SETS       = CACHE_SIZE / NOOFBLOCK;
    localparam integer INDEX_BITS = $clog2(SETS);
    localparam integer TAG_BITS   = 32 - INDEX_BITS - 2;

    // Simulated main memory (1K words)
    reg [31:0] main_memory [0:1023];

    // Cache arrays
    reg [TAG_BITS-1:0] tag_array [0:SETS-1][0:NOOFBLOCK-1];
    reg [31:0]         data_array[0:SETS-1][0:NOOFBLOCK-1];
    reg                valid     [0:SETS-1][0:NOOFBLOCK-1];
    reg                dirty     [0:SETS-1][0:NOOFBLOCK-1];
    reg                fifobit   [0:SETS-1][0:NOOFBLOCK-1];
    reg  [3:0]         frequency [0:SETS-1][0:NOOFBLOCK-1];

    // Address fields
    wire [INDEX_BITS-1:0] index = address[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   tag   = address[31:INDEX_BITS+2];
    wire [9:0] mem_addr = address[11:2];  // 10-bit memory address

    // Variables declared at module scope for loops and indexes
    integer i, s, w;
    integer hit_way;
    reg found;
    integer victim_way;
    integer min_freq;
    integer fifo_priority;

    reg [31:0] old_addr;
    reg [31:0] new_data;

    // Hit detection (combinational)
    always @(*) begin
        found = 0;
        hit_way = -1;
        hit = 0;
        read_data = 32'b0;
        for (i = 0; i < NOOFBLOCK; i = i + 1) begin
            if (!found && valid[index][i] && tag_array[index][i] == tag) begin
                found = 1;
                hit_way = i;
                hit = 1;
                read_data = data_array[index][i];
            end
        end
    end

    // Main sequential logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (s = 0; s < SETS; s = s + 1) begin
                for (w = 0; w < NOOFBLOCK; w = w + 1) begin
                    valid[s][w]     <= 0;
                    dirty[s][w]     <= 0;
                    frequency[s][w] <= 0;
                    fifobit[s][w]   <= 0;
                    tag_array[s][w] <= 0;
                    data_array[s][w]<= 0;
                end
            end
        end else begin
            if (found) begin
                // Cache hit
                if (is_write) begin
                    data_array[index][hit_way] <= write_data;
                    dirty[index][hit_way] <= 1;
                end
                if (frequency[index][hit_way] < 15)
                    frequency[index][hit_way] <= frequency[index][hit_way] + 1;
                fifobit[index][hit_way] <= 1;
            end else begin
                // Cache miss - find victim block for replacement
                victim_way = 0;
                min_freq = frequency[index][0];
                fifo_priority = fifobit[index][0];
                for (i = 1; i < NOOFBLOCK; i = i + 1) begin
                    if ((frequency[index][i] < min_freq) ||
                        ((frequency[index][i] == min_freq) && (fifobit[index][i] < fifo_priority))) begin
                        victim_way = i;
                        min_freq = frequency[index][i];
                        fifo_priority = fifobit[index][i];
                    end
                end

                // Write-back old data if dirty
                if (valid[index][victim_way] && dirty[index][victim_way]) begin
                    old_addr = {tag_array[index][victim_way], index, 2'b00};
                    main_memory[old_addr[11:2]] <= data_array[index][victim_way];
                end

                // Fetch new data
                new_data = is_write ? write_data : main_memory[mem_addr];

                // Update cache line
                tag_array[index][victim_way]   <= tag;
                data_array[index][victim_way]  <= new_data;
                valid[index][victim_way]       <= 1;
                dirty[index][victim_way]       <= is_write ? 1 : 0;
                frequency[index][victim_way]   <= 1;
                fifobit[index][victim_way]     <= 0;
            end
        end
    end

endmodule
