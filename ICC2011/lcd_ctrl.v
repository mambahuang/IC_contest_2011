module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
input clk;
input reset;
input [7:0] IROM_Q;
input [2:0] cmd;
input cmd_valid;
output IROM_EN;
output [5:0] IROM_A;
output IRB_RW;
output [7:0] IRB_D;
output [5:0] IRB_A;
output busy;
output done;

reg [3:0] curr_state, next_state;
reg [7:0] image_reg [0:63];
reg [2:0] pos_x, pos_y;
reg [5:0] counter;

wire [5:0] index_0, index_1, index_2, index_3;
wire [9:0] sum;

parameter
WRITE = 4'd0,
SHIFT_UP = 4'd1,
SHIFT_DOWN = 4'd2,
SHIFT_LEFT = 4'd3,
SHIFT_RIGHT = 4'd4,
AVERAGE = 4'd5,
MIRROR_X = 4'd6,
MIRROR_Y = 4'd7,
READ_DATA = 4'd8,
IDLE = 4'd9,
DONE = 4'd10,
STANDBY = 4'd11;

// index for 4 pixels with pos_x, pos_y as the center
assign index_0 = {pos_y - 3'd1, pos_x - 3'd1};
assign index_1 = {pos_y - 3'd1, pos_x};
assign index_2 = {pos_y, pos_x - 3'd1};
assign index_3 = {pos_y, pos_x};

assign sum = image_reg[index_0] + image_reg[index_1] + image_reg[index_2] + image_reg[index_3];

// curr_state logic
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        curr_state <= READ_DATA;
    end
    else if (cmd_valid && !busy)
    begin
        curr_state <= cmd;
    end
    else
    begin
        curr_state <= next_state;
    end
end

// next_state logic
always @(*)
begin
    case(curr_state)
    READ_DATA:
    begin
        if (counter == 6'd63)
        begin
            next_state <= IDLE;
        end
        else
        begin
            next_state <= READ_DATA;
        end
    end
    WRITE:
    begin
        if (counter == 6'd63)
        begin
            next_state <= DONE;
        end
        else
        begin
            next_state <= WRITE;
        end
    end
    default: next_state <= STANDBY; // STANDBY means no operation
    endcase

end

// counter for 64 pixels
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        counter <= 6'd0;
    end
    else
    begin
        if (curr_state == READ_DATA || curr_state == WRITE)
        begin
            counter <= counter + 6'd1;
        end
        else
        begin
            counter <= 6'd0;
        end
    end

end

// Do the operation
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        pos_x <= 3'd4;
        pos_y <= 3'd4;
    end
    else
    begin
        case(curr_state)
        SHIFT_UP:
        begin
            if (pos_y > 3'd1)
                pos_y <= pos_y - 3'd1;
        end
        SHIFT_DOWN:
        begin
            if (pos_y < 3'd7)
                pos_y <= pos_y + 3'd1;
        end
        SHIFT_LEFT:
        begin
            if (pos_x > 3'd1)
                pos_x <= pos_x - 3'd1;
        end
        SHIFT_RIGHT:
        begin
            if (pos_x < 3'd7)
                pos_x <= pos_x + 3'd1;
        end
        AVERAGE:
        begin
            image_reg[index_0] <= sum[9:2];
            image_reg[index_1] <= sum[9:2];
            image_reg[index_2] <= sum[9:2];
            image_reg[index_3] <= sum[9:2];
        end
        MIRROR_X:
        begin
            image_reg[index_0] <= image_reg[index_2];
            image_reg[index_1] <= image_reg[index_3];
            image_reg[index_2] <= image_reg[index_0];
            image_reg[index_3] <= image_reg[index_1];
        end
        MIRROR_Y:
        begin
            image_reg[index_0] <= image_reg[index_1];
            image_reg[index_1] <= image_reg[index_0];
            image_reg[index_2] <= image_reg[index_3];
            image_reg[index_3] <= image_reg[index_2];
        end
        endcase
    end
end

// IROM_EN and IROM_A
assign IROM_EN = (curr_state == READ_DATA) ? 1'b0 : 1'b1;
assign IROM_A = counter;

// Read image_reg
always @(posedge clk)
begin
    case(curr_state)
    READ_DATA:
    begin
        image_reg[counter - 1] <= IROM_Q;
    end
    IDLE:
    begin
        image_reg[63] <= IROM_Q;
    end
    endcase

end

// IRB_RW, IRB_D, IRB_A, busy, done
assign IRB_RW = (curr_state == WRITE) ? 1'b0 : 1'b1;
assign IRB_D = image_reg[counter]; // write data
assign IRB_A = counter;
assign busy = (curr_state == STANDBY) ? 1'b0 : 1'b1;
assign done = (curr_state == DONE) ? 1'b1 : 1'b0;

endmodule
