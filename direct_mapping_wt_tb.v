`timescale 1ns/1ps

module direct_cache_tb;

    reg clk;
    reg reset;
    reg [31:0] address;
    reg is_write;
    reg [31:0] write_data;
    wire hit;
    wire [31:0] read_data;

    parameter CACHE_SIZE = 64;

    direct_mapped_wt #(
        .CACHE_SIZE(CACHE_SIZE),
        .WRITING("write_through")
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
        $display("==== Direct Mapped Cache Write-Through Test ====");
        $monitor("Time=%0t Addr=%h Write=%b Data=%h -> Hit=%b Read=%h",
                 $time, address, is_write, write_data, hit, read_data);

        // Initialization
        reset = 1;
        address = 0;
        is_write = 0;
        write_data = 0;
        #20 reset = 0;

        // Fill cache - each index once
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            addr = {20'hAAAAA, i[5:0], 2'b00};  // unique tag, index = i
            data = 32'hAB00 + i;
            write(addr, data);
        end

        // Hit test
        read({20'hAAAAA, 6'd5, 2'b00}); // Should hit

        // Conflict: different tag, same index (index 5)
        read({20'hBBBBB, 6'd5, 2'b00}); // Should miss (replace old)

        // Hit for new tag
        read({20'hBBBBB, 6'd5, 2'b00}); // Should hit

        // Another replacement at index 5
        write({20'hCCCCC, 6'd5, 2'b00}, 32'hCC55); // Replace again

        // Confirm replacement
        read({20'hCCCCC, 6'd5, 2'b00}); // Hit
        read({20'hBBBBB, 6'd5, 2'b00}); // Miss (evicted)

        #100;
        $finish;
    end

endmodule
