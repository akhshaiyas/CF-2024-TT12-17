
`timescale 1ns/1ps

module tb_set_associative_wt;

    reg clk, reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    // Instantiate the cache module
    set_associative_wt cache_inst (
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

    // Main stimulus
    initial begin
        $dumpfile("cache_wt.vcd");
        $dumpvars(0, tb_set_associative_wt);

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

        // Phase 2: Write-through verification
        $display("\n=== Phase 2: Write-Through Verification ===");
        test_write_through();

        // Phase 3: LFU-FIFO policy
        $display("\n=== Phase 3: LFU-FIFO Policy ===");
        test_lfu_fifo();

        // Phase 4: Multi-set operations
        $display("\n=== Phase 4: Multi-Set Operations ===");
        test_multi_set();

        #500 $finish;
    end

    // Task: Fill a cache set with unique tags
    task fill_set;
        input integer set_index;
        integer i;
        reg [23:0] tag_part;
        begin
            for(i = 0; i < 4; i = i + 1) begin
                @(negedge clk);
                tag_part = i;
                address = {tag_part, set_index[1:0], 2'b00}; // index=set_index, tag=i
                is_write = 1;
                write_data = $random;
                @(posedge clk);
                $display("Write: Addr=%h, Data=%h, Hit=%b", address, write_data, hit);
            end
        end
    endtask

    // Task: Trigger replacement
    task trigger_replacement;
        input integer set_index;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            tag_part = 24'hA0;
            address = {tag_part, set_index[1:0], 2'b00}; // New tag for replacement
            is_write = 0;
            @(posedge clk);
            $display("Access: Addr=%h, Hit=%b", address, hit);
        end
    endtask

    // Task: Verify eviction
    task verify_eviction;
        input integer set_index;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            tag_part = 24'h0;
            address = {tag_part, set_index[1:0], 2'b00}; // Should have been evicted
            is_write = 0;
            @(posedge clk);
            $display("Eviction check: Addr=%h, Hit=%b", address, hit);
        end
    endtask

    // Task: Write-through verification
    task test_write_through;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            address = 32'h00000004; // index=01, tag=0
            is_write = 1;
            write_data = 32'hCAFEBABE;
            @(posedge clk);

            @(negedge clk);
            if (cache_inst.main_memory[1] !== 32'hCAFEBABE)
                $display("ERROR: Write-through failed!");
            else
                $display("Write-through verified");
        end
    endtask

    // Task: LFU-FIFO testing
    task test_lfu_fifo;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            address = 32'h00000008; // index=10 (set 2), tag=0
            is_write = 0;
            repeat(5) @(posedge clk);

            @(negedge clk);
            address = {24'd1, 2'b10, 2'b00}; // index=10, tag=1
            is_write = 0;
            repeat(3) @(posedge clk);

            @(negedge clk);
            address = {24'd2, 2'b10, 2'b00}; // index=10, tag=2
            is_write = 0;
            @(posedge clk);

            @(negedge clk);
            address = {24'd3, 2'b10, 2'b00}; // index=10, tag=3
            is_write = 0;
            @(posedge clk);

            @(negedge clk);
            tag_part = 24'd180;
            address = {tag_part, 2'b10, 2'b00}; // New tag for set 2
            is_write = 0;
            @(posedge clk);
            $display("LFU-FIFO replacement triggered");
        end
    endtask

    // Task: Multi-set operations
    task test_multi_set;
        begin
            @(negedge clk);
            address = 32'h0000000C; // index=11 (set 3), tag=0
            is_write = 0;
            @(posedge clk);
            if (!hit)
                $display("Set 3 miss (expected if first access or evicted)");
            else
                $display("Set 3 hit (valid if cached earlier)");
        end
    endtask

endmodule
