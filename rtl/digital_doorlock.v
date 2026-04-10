
module digital_doorlock (
    input clk,
    input rst_btn,
    input one_btn,
    input zero_btn, 
    output reg unlock 
);

reg [4:0] buffer;

assign unlock = (buffer==5'b01011) ? 1 : 0;
//passing 5 stages opens the door
always @(posedge clk) begin
    if (rst_btn) begin
        buffer <= 5'b00000;
    end else if (one_btn) begin
        buffer <= {buffer[3:0], 1'b1};
    end else if (zero_btn) begin
        buffer <= {buffer[3:0], 1'b0};
    end


endmodule
