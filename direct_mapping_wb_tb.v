`timescale 1ns/1ps

module direct_cache_wb_tb;
    reg clk;
    reg reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    parameter CACHE_SIZE = 64;

    direct_mapped #(
        .CACHE_SIZE(CACHE_SIZE),
        .WRITING("write_back")
    ) uut (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;

    task write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            address    = addr;
            is_write   = 1;
            write_data = data;
        end
    endtask

    task read(input [31:0] addr);
        begin
            @(posedge clk);
            address    = addr;
            is_write   = 0;
            write_data = 32'h00000000;
        end
    endtask

    integer i;
    reg [31:0] addr, data;

    initial begin
        $display("==== Write-Back Cache Test ====");
        $monitor("Time=%0t Addr=%h Write=%b Data=%h -> Hit=%b Read=%h",
                 $time, address, is_write, write_data, hit, read_data);

        // Initialization
        reset = 1;
        address = 0;
        is_write = 0;
        write_data = 0;
        #20 reset = 0;

        // Fill cache - 64 different indices
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            addr = {20'hAAAAA, i[5:0], 2'b00};
            data = 32'hCD00 + i;
            write(addr, data);
        end

        // Write to existing address - should hit, mark dirty
        write({20'hAAAAA, 6'd10, 2'b00}, 32'h12345678);

        // Conflict - write different tag, same index = eviction (write back)
        write({20'hBBBBB, 6'd10, 2'b00}, 32'h87654321); // Eviction of dirty line

        // Read newly written address - should hit
        read({20'hBBBBB, 6'd10, 2'b00}); // Hit

        // Read old tag - should miss (was evicted)
        read({20'hAAAAA, 6'd10, 2'b00}); // Miss

        #100;
        $finish;
    end
endmodule
