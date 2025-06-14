`timescale 1ns/1ps

module tb_direct_mapped_write_back;

    reg clk = 0;
    reg reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    parameter CACHE_SIZE = 8;

    // Instantiate the cache with write_back
    direct_mapped #(
        .CACHE_SIZE(CACHE_SIZE),
        .WRITING("write_back")
    ) cache (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Write task
    task cache_write(input [31:0] addr, input [31:0] data);
        begin
            address    = addr;
            is_write   = 1;
            write_data = data;
            #10;
            $display("[WRITE] Addr = %08h | Data = %08h | Hit = %0d", addr, data, hit);
        end
    endtask

    // Read task
    task cache_read(input [31:0] addr);
        begin
            address  = addr;
            is_write = 0;
            #10;
            $display("[READ ] Addr = %08h => Data = %08h | Hit = %0d", addr, read_data, hit);
        end
    endtask

    // Dump cache content
    task dump_cache;
        integer i;
        begin
            $display("\n==== Cache Dump ====");
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                $display("Index = %0d | Valid = %0d | Dirty = %0d | Tag = 0x%h | Data = 0x%08h",
                         i, cache.valid[i], cache.dirty[i], cache.tag_array[i], cache.data_array[i]);
            end
        end
    endtask

    // Dump main memory content (first 32 locations)
    task dump_main_memory;
        integer i;
        begin
            $display("\n==== Main Memory Dump [0x00 to 0x1F] ====");
            for (i = 0; i < 32; i = i + 1) begin
                $display("Mem[%0d] = 0x%08h", i, cache.main_memory[i]);
            end
        end
    endtask

    integer i;

    initial begin
        // Initial setup
        reset = 1; address = 0; is_write = 0; write_data = 0;
        #20;
        reset = 0;

        $display("\n=== STEP 1: Fill Cache (All Unique Indexes) ===");
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            cache_write(32'h0000_1000 + (i << 2), 32'hAAAA_0000 + i);
        end

        $display("\n=== STEP 2: Replace Cache Lines (New Tags, Same Indices) ===");
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            cache_write(32'h1000_1000 + (i << 2), 32'hBBBB_0000 + i);
        end

        $display("\n=== STEP 3: Read Old Evicted Addresses ===");
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            cache_read(32'h0000_1000 + (i << 2));
        end

        $display("\n=== STEP 4: Read Recently Written Addresses ===");
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            cache_read(32'h1000_1000 + (i << 2));
        end

        #10;

        dump_cache();
        dump_main_memory();

        $finish;
    end
endmodule
