`timescale 1ns/1ps

module tb_set_associative_wb;
    reg clk, reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    // Explicit port mapping for Verilog
    set_associative_wb cache_inst (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

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
        reg [23:0] tag_part;
        begin
            for(i=0; i<4; i=i+1) begin
                @(negedge clk);
                tag_part = i;
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
            tag_part = 24'hA0;
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
            tag_part = 24'h0;
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
            @(negedge clk);
            address = 32'h00000004;
            is_write = 1;
            write_data = 32'hCAFEBABE;
            @(posedge clk);

            for (i=1; i<=4; i=i+1) begin
                @(negedge clk);
                tag_part = 24'd160 + i;
                address = {tag_part, 2'b01, 2'b00};
                is_write = 1;
                write_data = $random;
                @(posedge clk);
                $display("Write: Addr=%h, Data=%h, Hit=%b", address, write_data, hit);
            end

            @(negedge clk);
            if (cache_inst.main_memory[1] !== 32'hCAFEBABE)
                $display("ERROR: Dirty block not written back!");
            else
                $display("Dirty write-back verified");
        end
    endtask

    // Test LFU-FIFO policy
    task test_lfu_fifo;
        reg [23:0] tag_part;
        begin
            @(negedge clk);
            address = 32'h00000008;
            is_write = 0;
            repeat(5) @(posedge clk);

            @(negedge clk);
            address = 32'h0000000C;
            is_write = 0;
            repeat(3) @(posedge clk);

            @(negedge clk);
            address = 32'h00000010;
            is_write = 0;
            @(posedge clk);

            @(negedge clk);
            address = 32'h00000014;
            is_write = 0;
            @(posedge clk);

            @(negedge clk);
            tag_part = 24'd180;
            address = {tag_part, 2'b10, 2'b00};
            is_write = 0;
            @(posedge clk);
            $display("LFU-FIFO replacement triggered");
        end
    endtask

    // Test multi-set operations
    task test_multi_set;
        begin
            @(negedge clk);
            address = 32'h0000000C;
            is_write = 0;
            @(posedge clk);
            if (!hit)
                $display("Set 3 miss (correct first access)");
        end
    endtask

endmodule
