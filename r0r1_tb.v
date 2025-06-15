`timescale 1ns / 1ps

module topmodule_tb;

    reg clk, reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    top_level uut (
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
        $display("=== Region 0: Direct-Mapped Write-Through Cache Test ===");
        clk = 0;
        reset = 1;
        #10;
        reset = 0;

        // Region 0 test (address starts with 0x0...)
        address = 32'h00000000; is_write = 1; write_data = 32'hAAAA0000; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        address = 32'h00000010; is_write = 1; write_data = 32'hBBBB0000; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        // Re-access previous address
        address = 32'h00000000; is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        $display("\n=== Region 1: Direct-Mapped Write-Back Cache Test ===");

        // Region 1 test (address starts with 0x1...)
        address = 32'h10000000; is_write = 1; write_data = 32'h11110000; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        // Cause replacement
        address = 32'h10000040; is_write = 1; write_data = 32'h22220000; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        // Re-read the first address (check if it was evicted and written back if dirty)
        address = 32'h10000000; is_write = 0; #10;
        $display("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h", $time, address, is_write, write_data, hit, read_data);

        $finish;
    end

endmodule
