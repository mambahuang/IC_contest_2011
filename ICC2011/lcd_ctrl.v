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

reg IROM_EN;
reg [5:0] IROM_A;
reg IRB_RW;
reg [7:0] IRB_D;
reg [5:0] IRB_A;
reg busy;
reg done;

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
FETCH = 4'd8,
READ_DATA = 4'd9,
IDLE = 4'd10,
SUM = 4'd11,
DONE = 4'd12;

// next state logic
always @(*)
begin
    case(curr_state)
        FETCH:
        begin
            next_state = READ_DATA;
        end
        READ_DATA:
        begin
            if (IROM_A == 6'd63)
                next_state = IDLE;
            else
                next_state = READ_DATA;
        end
        IDLE:
        begin
            if(cmd_valid)
            begin
                case(cmd)
                    3'b000:
                    begin
                        next_state = WRITE;
                    end
                    3'b001:
                    begin
                        next_state = SHIFT_UP;
                    end
                    3'b010:
                    begin
                        next_state = SHIFT_DOWN;
                    end
                    3'b011:
                    begin
                        next_state = SHIFT_LEFT;
                    end
                    3'b100:
                    begin
                        next_state = SHIFT_RIGHT;
                    end
                    3'b101:
                    begin
                        next_state = AVERAGE;
                    end
                    3'b110:
                    begin
                        next_state = MIRROR_X;
                    end
                    3'b111:
                    begin
                        next_state = MIRROR_Y;
                    end
                endcase
            end
            else
            begin
                next_state = IDLE;
            end
        end
        WRITE:
        begin
            if(IRB_A == 6'd63)
                next_state = DONE;
            else
                next_state = WRITE;
        end
        SHIFT_UP:
        begin
            next_state = IDLE;
        end
        SHIFT_DOWN:
        begin
            next_state = IDLE;
        end
        SHIFT_LEFT:
        begin
            next_state = IDLE;    
        end
        SHIFT_RIGHT:
        begin
            next_state = IDLE;
        end
        AVERAGE:
        begin
            next_state = SUM;
        end
        MIRROR_X:
        begin
            next_state = IDLE;
        end
        MIRROR_Y:
        begin
            next_state = IDLE;
        end
        SUM:
        begin
            next_state = IDLE;
        end
        DONE:
        begin
            next_state = DONE;
        end
    endcase

end

// state logic
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        busy <= 1'b1; // default
        done <= 1'b0;
        IROM_EN <= 1'b0; // start to read 
        IROM_A <= 6'd0;
        IRB_RW <= 1'b1;
        IRB_D <= 8'd0;
        IRB_A <= 6'd0;
        pos_x <= 3'd0;
        pos_y <= 3'd0;
        sum <= 10'd0;
        index_0 <= 6'd0;
        index_1 <= 6'd0;
        index_2 <= 6'd0;
        index_3 <= 6'd0;
        curr_state <= FETCH;
    end
    else
    begin
        curr_state <= next_state;

        if (next_state == IDLE)
            busy <= 1'b0;
        else
            busy <= 1'b1;

        case(curr_state)
        FETCH:
        begin
            IROM_A <= {pos_y, pos_x};
        end
        READ_DATA:
        begin
            image_reg[IROM_A] <= IROM_Q;
            if (IROM_A == 6'd63)
            begin
                IROM_EN <= 1'b1; // shut down IROM
                pos_x <= 3'd4; // initialize position
                pos_y <= 3'd4;
            end
            else
            begin
                busy <= 1'b1;
                IROM_A <= {pos_y, pos_x} + 6'd1;
            end
        end
        WRITE:
        begin
            IRB_D <= image_reg[IRB_A];
        end
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
        IDLE:
        begin

            if (next_state == WRITE)
            begin
                IRB_RW <= 1'b0;
                pos_x <= 3'd0;
                pos_y <= 3'd0;
                IRB_A <= {pos_y, pos_x};
                {pos_y, pos_x} <= {pos_y, pos_x} + 6'd1;
            end
            else
            begin
                IRB_RW <= 1'b1;
            end

            index_0 <= {pos_y - 3'd1, pos_x - 3'd1};
            index_1 <= {pos_y - 3'd1, pos_x};
            index_2 <= {pos_y, pos_x - 3'd1};
            index_3 <= {pos_y, pos_x};
            
        end
        SUM:
        begin
            sum <= image_reg[index_0] + image_reg[index_1] + image_reg[index_2] + image_reg[index_3];
        end
        DONE:
        begin
            busy <= 1'b0;
            done <= 1'b1;
        end
        endcase

    end
end

// output logic
always @(*)
begin

end

endmodule
