`timescale 1ns/1ps

module tb_set_associative_wb();
    reg clk, reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    // Explicitly list port connections (instead of .*) for Verilog compatibility
    set_associative_wb cache_inst (
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

    initial begin
        $dumpfile("cache_wb.vcd");
        $dumpvars(0, tb_set_associative_wb);

        // Initialize
        clk = 0;
        reset = 1;
        address = 0;
        is_write = 0;
        write_data = 0;
        #10 reset = 0;

        // Phase 1: Basic replacement
        $display("\n=== Phase 1: Basic Replacement ===");
        fill_set(0); // Fill set 0
        trigger_replacement(0);
        verify_eviction(0);

        // Phase 2: Dirty block write-back
        $display("\n=== Phase 2: Dirty Block Write-Back ===");
        test_dirty_writeback();

        // Phase 3: LFU-FIFO policy
        $display("\n=== Phase 3: LFU-FIFO Policy ===");
        test_lfu_fifo();

        // Phase 4: Multi-set operations
        $display("\n=== Phase 4: Multi-Set Operations ===");
        test_multi_set();

        #1000 $finish;
    end

    // Fill a cache set with unique tags
    task fill_set;
        input integer set_index;
        integer i;
        reg [23:0] tag_part; // Sufficient for 32-bit address - (INDEX_BITS + OFFSET_BITS)
        begin
            for(i=0; i<4; i=i+1) begin
                @(negedge clk);
                tag_part = i;
                // Assuming INDEX_BITS is 2 (for 4 sets) and OFFSET_BITS is 2 (for 4 bytes/block)
                // Address construction: {tag, index, offset}
                address = {tag_part, set_index[1:0], 2'b00};
                is_write = 1;
                write_data = $random;
                @(posedge clk);
                $display("Write: Addr=%h, Data=%h, Hit=%b", address, write_data, hit);
            end
        end
    endtask

    // Trigger replacement in a set
    task trigger_replacement;
        input integer set_index;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            tag_part = 24'hA0; // New tag for replacement
            address = {tag_part, set_index[1:0], 2'b00};
            is_write = 0;
            @(posedge clk);
            $display("Access: Addr=%h, Hit=%b", address, hit);
        end
    endtask

    // Verify eviction in a set
    task verify_eviction;
        input integer set_index;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            tag_part = 24'h0; // Should have been evicted (original tag 0 from fill_set)
            address = {tag_part, set_index[1:0], 2'b00};
            is_write = 0;
            @(posedge clk);
            $display("Eviction check: Addr=%h, Hit=%b", address, hit);
        end
    endtask

    // Test dirty block write-back
    task test_dirty_writeback;
        reg [23:0] tag_part;
        integer i;
        begin
            // Write to address in set 1 (create dirty block)
            @(negedge clk);
            // This address (32'h00000004) has index 01 (binary for 1) and tag 0
            address = 32'h00000004; // index=01, tag=0 (0x00000004 -> index=01, offset=00, tag=0)
            is_write = 1;
            write_data = 32'hCAFEBABE;
            @(posedge clk);
            $display("Write dirty block: Addr=%h, Data=%h, Hit=%b", address, write_data, hit);

            // Fill set 1 with 4 NEW addresses (index=01) to force eviction of the dirty block
            for (i=1; i<=4; i=i+1) begin // Loop 4 times to fill the 4 ways
                @(negedge clk);
                tag_part = 24'd160 + i; // Create new unique tags
                address = {tag_part, 2'b01, 2'b00}; // index=01
                is_write = 1;
                write_data = $random;
                @(posedge clk);
                $display("Fill set 1: Addr=%h, Data=%h, Hit=%b", address, write_data, hit);
            end

            // Wait for memory write to complete (if any delay is expected)
            #10;

            // Verify main_memory at the address corresponding to the evicted dirty block
            // The original address was 32'h00000004, which maps to main_memory[1] (address[11:2])
            @(negedge clk);
            if (cache_inst.main_memory[1] !== 32'hCAFEBABE) begin
                $error("Dirty block (Address 0x00000004) not written back! Expected 0xCAFEBABE, got %h", cache_inst.main_memory[1]);
            end else begin
                $display("Dirty write-back verified for 0x00000004. Memory[1] = %h", cache_inst.main_memory[1]);
            end
        end
    endtask

    // Test LFU-FIFO policy
    task test_lfu_fifo;
        reg [23:0] tag_part;
        begin
            // Assume initial state is empty or known. Fill set 2 first for controlled test.
            $display("\n--- Filling Set 2 for LFU-FIFO Test ---");
            fill_set(2); // Fill set 2 with tags 0, 1, 2, 3

            $display("\n--- Testing LFU-FIFO ---");
            // Access tag 0 in set 2 multiple times (increase frequency)
            @(negedge clk);
            address = {24'h0, 2'b10, 2'b00}; // index=2, tag=0
            is_write = 0;
            $display("Accessing Addr=%h (tag 0)", address);
            repeat(5) @(posedge clk); // Access 5 times, freq becomes 5

            // Access tag 1 in set 2 a few times
            @(negedge clk);
            address = {24'h1, 2'b10, 2'b00}; // index=2, tag=1
            is_write = 0;
            $display("Accessing Addr=%h (tag 1)", address);
            repeat(3) @(posedge clk); // Access 3 times, freq becomes 3

            // Access tag 2 in set 2 once
            @(negedge clk);
            address = {24'h2, 2'b10, 2'b00}; // index=2, tag=2
            is_write = 0;
            $display("Accessing Addr=%h (tag 2)", address);
            @(posedge clk); // Access 1 time, freq becomes 1

            // Access tag 3 in set 2 once
            @(negedge clk);
            address = {24'h3, 2'b10, 2'b00}; // index=2, tag=3
            is_write = 0;
            $display("Accessing Addr=%h (tag 3)", address);
            @(posedge clk); // Access 1 time, freq becomes 1

            // At this point (approximate frequencies for set 2):
            // Way 0 (tag 0): Freq 5
            // Way 1 (tag 1): Freq 3
            // Way 2 (tag 2): Freq 1 (entered earlier, so higher age)
            // Way 3 (tag 3): Freq 1 (entered later, so lower age)

            // Trigger replacement with a new address in set 2
            // Expected eviction: LFU (lowest freq) + FIFO (oldest age)
            // Between tag 2 and tag 3 (both freq 1), tag 2 should be older.
            @(negedge clk);
            tag_part = 24'd180;
            address = {tag_part, 2'b10, 2'b00}; // New tag in set 2
            is_write = 0;
            @(posedge clk);
            $display("LFU-FIFO replacement triggered for Addr=%h (new tag %h)", address, tag_part);

            // Verify if tag 2 was evicted (it should be, based on LFU-FIFO)
            @(negedge clk);
            address = {24'h2, 2'b10, 2'b00}; // Address for tag 2
            is_write = 0;
            @(posedge clk);
            if (!hit) begin
                $display("LFU-FIFO: Tag 2 (Addr %h) was evicted as expected (Lowest Freq, Oldest Age).", address);
            end else begin
                $error("LFU-FIFO: Tag 2 (Addr %h) was NOT evicted! This indicates a policy issue.", address);
            end
        end
    endtask

    // Test multi-set operations
    task test_multi_set;
        begin
            // Access set 3. Initially, it will be a miss.
            @(negedge clk);
            address = {24'hABC, 2'b11, 2'b00}; // index=3, tag=ABC
            is_write = 0;
            @(posedge clk);
            if (!hit) $display("Multi-Set Test: First access to Set 3 (Addr %h) resulted in a miss (correct).", address);
            else $error("Multi-Set Test: Unexpected hit on first access to Set 3 (Addr %h).", address);

            // Access set 3 again (should be a hit now)
            @(negedge clk);
            address = {24'hABC, 2'b11, 2'b00}; // Same address
            is_write = 0;
            @(posedge clk);
            if (hit) $display("Multi-Set Test: Second access to Set 3 (Addr %h) resulted in a hit (correct).", address);
            else $error("Multi-Set Test: Unexpected miss on second access to Set 3 (Addr %h).", address);
        end
    endtask

endmodule
