`timescale 1ns / 1ps

module top_level_tb;

    reg clk;
    reg reset;
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
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to perform write
    task write_to(input [31:0] addr, input [31:0] data);
        begin
            address = addr;
            write_data = data;
            is_write = 1;
            #10;
            is_write = 0;
            #10;
        end
    endtask

    // Helper task to perform read
    task read_from(input [31:0] addr);
        begin
            address = addr;
            is_write = 0;
            #10;
        end
    endtask

    initial begin
        $display("=== Testbench with Replacement ===");
        $monitor("T=%0t | Addr=0x%h | W=%b | WData=0x%h | Hit=%b | RData=0x%h",
                  $time, address, is_write, write_data, hit, read_data);

        reset = 1; address = 0; is_write = 0; write_data = 0;
        #20; reset = 0;

        // ------------------ Region 2: Set-Associative Write-Back ------------------
        $display("\n--- Region 2 (Set-Associative Write-Back) Replacement Test ---");

        // Fill 4 blocks
        write_to(32'h20000000, 32'h1111_0000);
        write_to(32'h20000010, 32'h2222_0000);
        write_to(32'h20000020, 32'h3333_0000);
        write_to(32'h20000030, 32'h4444_0000);

        // Trigger replacement
        write_to(32'h20000040, 32'h5555_0000);  // This should evict one block

        // Read all 5 and check hits
        read_from(32'h20000000);  // Possibly evicted
        read_from(32'h20000010);
        read_from(32'h20000020);
        read_from(32'h20000030);
        read_from(32'h20000040);  // Recently added

        // ------------------ Region 3: Set-Associative Write-Through ------------------
        $display("\n--- Region 3 (Set-Associative Write-Through) Replacement Test ---");

        write_to(32'h30000000, 32'hAAAA_0000);
        write_to(32'h30000010, 32'hBBBB_0000);
        write_to(32'h30000020, 32'hCCCC_0000);
        write_to(32'h30000030, 32'hDDDD_0000);

        write_to(32'h30000040, 32'hEEEE_0000);  // Replacement expected

        read_from(32'h30000000);  // Possibly evicted
        read_from(32'h30000010);
        read_from(32'h30000020);
        read_from(32'h30000030);
        read_from(32'h30000040);  // Recently written

        $finish;
    end

endmodule
