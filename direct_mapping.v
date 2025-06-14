`timescale 1ns/1ps

module direct_mapped #( 
    parameter MAPPING     = "direct",
    parameter WRITING     = "write_through",  // or "write_back"
    parameter CACHE_SIZE  = 64
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] address,
    input  wire        is_write,
    input  wire [31:0] write_data,
    output reg         hit,
    output reg [31:0]  read_data
);

    localparam INDEX_BITS = $clog2(CACHE_SIZE);
    localparam TAG_BITS   = 32 - INDEX_BITS - 2;
    integer i;
    // Simulated main memory
    reg [31:0] main_memory [0:1023];  // 1KB memory (1024 words)

    // Cache arrays
    reg [TAG_BITS-1:0] tag_array [0:CACHE_SIZE-1];
    reg [31:0]         data_array[0:CACHE_SIZE-1];
    reg                valid     [0:CACHE_SIZE-1];
    reg                dirty     [0:CACHE_SIZE-1];  // Used only in write-back

    // Index and Tag extraction
    wire [INDEX_BITS-1:0] index = address[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   tag   = address[31:INDEX_BITS+2];
    wire [9:0]            mem_addr = address[11:2];  // For 1K memory

    reg [31:0] evict_addr;

    // Combinational read path
    always @(*) begin
        hit = valid[index] && (tag_array[index] == tag);
        read_data = hit ? data_array[index] : 32'hDEAD_BEEF;
    end

    // Sequential cache logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin

            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                valid[i]     <= 0;
                dirty[i]     <= 0;
                tag_array[i] <= 0;
                data_array[i]<= 0;
            end
            for (i = 0; i < 1024; i = i + 1) begin
                main_memory[i] <= i;
            end
        end else begin
            evict_addr = {tag_array[index], index, 2'b00};

            if (is_write) begin
                if (WRITING == "write_through") begin
                    main_memory[mem_addr] <= write_data;
                    if (hit) begin
                        data_array[index] <= write_data;
                    end else begin
                        tag_array[index]  <= tag;
                        data_array[index] <= write_data;
                        valid[index]      <= 1;
                        dirty[index]      <= 0;
                    end
                end else begin  // Write-back
                    if (hit) begin
                        data_array[index] <= write_data;
                        dirty[index]      <= 1;
                    end else begin
                        if (valid[index] && dirty[index]) begin
                            main_memory[evict_addr[11:2]] <= data_array[index];
                        end
                        tag_array[index]  <= tag;
                        data_array[index] <= write_data;
                        valid[index]      <= 1;
                        dirty[index]      <= 1;
                    end
                end
            end else begin
                if (!hit) begin
                    if (WRITING == "write_back" && valid[index] && dirty[index]) begin
                        main_memory[evict_addr[11:2]] <= data_array[index];
                    end
                    data_array[index] <= main_memory[mem_addr];
                    tag_array[index]  <= tag;
                    valid[index]      <= 1;
                    dirty[index]      <= 0;
                end
            end
        end
    end

endmodule
