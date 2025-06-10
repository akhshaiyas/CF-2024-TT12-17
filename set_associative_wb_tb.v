`timescale 1ns/1ps

module set_associative_wb_tb;

    reg clk, reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    // Instantiate cache: 64 blocks, 4-way => 16 sets
    set_associative_wb #(
        .CACHE_SIZE(64),
        .NOOFBLOCK(4)
    ) cache_inst (
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

    task do_write(input [31:0] addr, input [31:0] data);
    begin
        @(negedge clk);
        address = addr;
        is_write = 1;
        write_data = data;
        @(negedge clk);
        is_write = 0;
    end
    endtask

    task do_read(input [31:0] addr);
    begin
        @(negedge clk);
        address = addr;
        is_write = 0;
        @(negedge clk);
    end
    endtask

    initial begin
        $display("=== Set-Associative Cache Test ===");
        clk = 0;
        reset = 1;
        #10;
        reset = 0;

        // --- Fill set 0 (index = 0) with 4 blocks (fully occupied)
        do_write(32'h0000_0000, 32'hDEAD_0000); // tag 0000, set 0, way 0
        do_write(32'h0000_0010, 32'hDEAD_0010); // tag 0000, set 0, way 1
        do_write(32'h0000_0020, 32'hDEAD_0020); // tag 0000, set 0, way 2
        do_write(32'h0000_0030, 32'hDEAD_0030); // tag 0000, set 0, way 3

        // --- Read hit from one of the above
        do_read(32'h0000_0010); // HIT

        // --- New write to same set (index = 0) with different tag → replacement should occur
        do_write(32'h1000_0000, 32'hBEEF_0000); // tag differs, set 0 → cause replacement

        // --- Read back what may have been replaced (to check miss)
        do_read(32'h0000_0000); // might MISS if replaced

        // --- Read newly inserted one (should be a HIT)
        do_read(32'h1000_0000); // HIT

        #50;
        $finish;
    end

    initial begin
        $monitor("Time=%0t | Addr=0x%0h | Wr=%b | DataIn=0x%0h | Hit=%b | DataOut=0x%0h",
                 $time, address, is_write, write_data, hit, read_data);
    end

endmodule
