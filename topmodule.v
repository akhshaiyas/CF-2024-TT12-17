`timescale 1ns / 1ps
module top_level (
    input wire clk,
    input wire reset,
    input wire [31:0] address,
    input wire is_write,
    input wire [31:0] write_data,
    output wire hit,
    output wire [31:0] read_data
);
    wire [3:0] region; // 4 bits refer to references in discord
    wire hit0 , hit1 , hit2 , hit3 ;
    wire [31:0] read_data0, read_data1, read_data2, read_data3;

    // Instantiate the direct mapped cache
    direct_mapped #(
        .MAPPING("direct"),
        .WRITING("write_through"),
        .CACHE_SIZE(64)
    ) cache_inst (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    direct_mapped #(
        .MAPPING("direct"),
        .WRITING("write_back"),
        .CACHE_SIZE(64)
    ) cache_inst2 (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    set_associative_wb #(
        .MAPPING("set_assoc"),
        .WRITING("write_back"),
        .CACHE_SIZE(64),
        .REPLACEMENT("LFU_FIFO"),
        .NOOFBLOCK(4),
	.BLOCK_SIZE_BYTES(4)
    ) cache_inst3 (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    set_associative_wt #(
        .MAPPING("set_assoc"),
        .WRITING("write_through"),
        .CACHE_SIZE(64),
        .REPLACEMENT("LFU_FIFO"),
        .NOOFBLOCK(4),
	.BLOCK_SIZE_BYTES(4)
    ) cache_inst4 (
        .clk(clk),
        .reset(reset),
        .address(address),
        .is_write(is_write),
        .write_data(write_data),
        .hit(hit),
        .read_data(read_data)
    );

    // Region selection logic
    assign region = address[31:28];  // Assuming higher 4 bits of address determine the region
    assign hit = (region == 4'b0000) ? hit0 :
                 (region == 4'b0001) ? hit1 :
                 (region == 4'b0010) ? hit2 :
                 (region == 4'b0011) ? hit3 : 1'b0;

    assign read_data = (region == 4'b0000) ? read_data0 :
                       (region == 4'b0001) ? read_data1 :
                       (region == 4'b0010) ? read_data2 :
                       (region == 4'b0011) ? read_data3 : 32'h0;

endmodule
