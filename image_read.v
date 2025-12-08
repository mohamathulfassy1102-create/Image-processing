module image_read #(
    parameter   WIDTH = 768,
                HEIGHT = 512,
                FILE = "",
                VALUE = 100,
                START_UP_DELAY = 100,
                H_SYNC_DELAY = 150,
                DATA_WIDTH = 8,  // data width
                SIZE_OF_LENGTH = 1179648,  // image data : 1179648 bytes: 512 * 768 *3 
                THRESHOLD = 90,
                BRIGHT = 1
) (
    input clk,rst_n,
    output reg H_sync,
    output V_sync
    output [7:0] red_0,red_1,green_0,green_1,blue_0,blue_1,
    output rd_done
);
    
// state variables
    localparam		ST_IDLE 	= 2'b00,		
				    ST_VSYNC	= 2'b01,			// state for creating vsync 
				    ST_HSYNC	= 2'b10,			// state for creating hsync 
				    ST_DATA		= 2'b11;
    reg [1:0] curr_state, // y (present state)
                nxt_state;	// Y (next state)
    reg start;
    reg rst_dly;								// delayed reset signal
    reg V_sync_ctrl, H_sync_ctrl, data_ctrl; 				// control signal for vsync counter
    reg [8:0] V_sync_cnt, H_sync_cnt;
    reg [7:0]   total_memory [0 : sizeOfLengthReal-1];	// memory to store  8-bit data image
// temporary memory to save image data : size will be WIDTH*HEIGHT*3
    integer temp_bmp   [0 : WIDTH*HEIGHT*3 - 1];			
    integer Red  [0 : WIDTH*HEIGHT - 1]; 	
    integer Green  [0 : WIDTH*HEIGHT - 1];	
    integer Blue  [0 : WIDTH*HEIGHT - 1];	
    
    integer i, j;

    integer temp_r0,temp_r1,temp_g0,temp_g1,temp_b0,temp_b1; // temporary variables in contrast and brightness operation

    integer value,value1,value2,value4;
    reg [9:0] row; // row index of the image
    reg [10:0] col; // column index of the image
    reg [18:0] data_count; // data counting for entire pixels of the image

    initial begin
        $readmemh(FILE,total_memory,0,SIZE_OF_LENGTH-1)
    end

    always @(start) begin // For storing image data
        for (i = 0; i<WIDTH*HEIGHT*3 ; i = i+1) begin
            temp_bmp[i] = total_memory[i][7:0];
        end
        for (i = 0; i<HEIGHT ; i = i+1) begin
            for (j = 0; j<WIDTH ; i = i+1) begin
                Red [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+0] // save red component
                Green [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+1] // save green component
                Blue [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+2] // save blue component
            end
        end
    end

    always @(posedge clk , negedge rst_n ) begin
        if (!rst_n) begin
            start <= 0;
            rst_dly <= 0;
        end
        else begin
            rst_dly <= rst_n;
            if(rst_n == 1'b1 && rst_dly == 1'b0) begin // rising edge detection logic
                start <= 1; // start on the rising edge
            end
            else begin
                start <= 0;
            end
        end
    end

    always @ (posedge clk , negedge rst_n) begin
        if(!rst_n) begin
            curr_state <= ST_IDLE;
        end
        else begin
            curr_state <= nxt_state;
        end
    end

    always @(*) begin // state transition (IDLE -> VSYNC -> HSYNC -> DATA)
        case (curr_state)
            ST_IDLE : begin
                if (start) begin
                    nxt_state = ST_VSYNC;
                end
                else begin
                    nxt_state = ST_IDLE
                end
            end
            ST_VSYNC : begin
                if(ctrl_vsync_cnt == START_UP_DELAY) begin
                    nxt_state = ST_HSYNC
                end
                else begin
                    nxt_state = ST_VSYNC;
                end
            end
            ST_HSYNC : begin
                if(H_sync_cnt == HSYNC_DELAY) begin
                    nxt_state = ST_DATA;
                end
                else begin
                    nxt_state = ST_HSYNC;
                end
            end
            ST_DATA : begin
                if(start) begin
                    nxt_state = ST_IDLE;
                end
                else begin
                    if(col = width - 2) begin
                        nxt_state = ST_HSYNC;
                    end
                    else begin
                        nxt_state = ST_DATA;
                    end
                end
            end
            default: nxt_state = ST_IDLE;
        endcase
    end

    always @(*) begin
        if (!rst_n) begin
            H_sync_ctrl <= 0;
            V_sync_ctrl <= 0;
            data_ctrl <= 0;
        end
        else begin
            V_sync_cnt = (V_sync_ctrl) ? V_sync_cnt + 1 : 0;
            H_sync_cnt = (H_sync_ctrl) ? H_sync_cnt + 1 : 0;
        end
    end
    
    always @ (posedge clk , negedge rst_n) begin
        if(!rst_n) begin
            row <= 0;
            col <= 0;
        end
        else begin
            if (data_ctrl) begin
                if(col == WIDTH - 2) begin
                    row <= row + 1;
                    col <= 0;
                end
                else begin
                    col <= col + 2; // read 2 pixel
                end
            end
        end
    end

    always @(posedge clk , negedge rst_n) begin
        if(rst_n) begin
            data_count <= 0;
        end
        else begin
            if(data_ctrl) begin
                data_count <= data_count + 1;
            end
        end
    end
    assign V_sync = V_sync_ctrl;
    assign done = (data_count == 196607) ? 1'b1 : 1'b0;

    // Image processing
    always @(*) begin
        H_sync = 1'b0;
        red_0 = 0;
        green_0 = 0;
        blue_0 = 0;
        red_1 = 0;
        green_1 = 0;
        blue_1 = 0;
        if(data_ctrl) begin
            H_sync = 1'b1;

            `ifdef BRIGHTNESS_OP
            // Brightness addition operation
            if(BRIGHT) begin
                //red 0
                temp_r0 = Red [WIDTH*row+col] + VALUE;
                if(temp_r0 > 255) begin
                    red_0 = 255;
                end
                else begin
                    red_0 = Red [WIDTH*row+col] + VALUE;
                end
                //red 1
                temp_r1 = Red [WIDTH*row+col+1] + VALUE;
                if(temp_r1 > 255) begin
                    red_1 = 255;
                end
                else begin
                    red_1 = Red [WIDTH*row+col+1] + VALUE;
                end
                //green 0
                temp_g0 = Green [WIDTH*row+col] + VALUE;
                if(temp_g0 > 255) begin
                    green_0 = 255;
                end
                else begin
                    green_0 = Green [WIDTH*row+col] + VALUE;
                end
                //green 1
                temp_g1 = Green [WIDTH*row+col+1] + VALUE;
                if(temp_g1 > 255) begin
                    green_1 = 255;
                end
                else begin
                    green_1 = Green [WIDTH*row+col+1] + VALUE;
                end
                //blue 0 
                temp_b0 = Blue [WIDTH*row+col] + VALUE;
                if(temp_b0 > 255) begin
                    blue_0 = 255;
                end
                else begin
                    blue_0 = Blue [WIDTH*row+col] + VALUE; 
                end
                //blue 1 
                temp_b1 = Blue [WIDTH*row+col+1] + VALUE;
                if(temp_b1 > 255) begin
                    blue_1 = 255;
                end
                else begin
                    blue_1 = Blue [WIDTH*row+col+1] + VALUE; 
                end
            end
            else begin
                //brightness subtraction operation
                //red 0
                temp_r0 = Red [WIDTH*row+col] - VALUE;
                if(temp_r0 > 255) begin
                    red_0 = 255;
                end
                else begin
                    red_0 = Red [WIDTH*row+col] - VALUE;
                end
                //red 1
                temp_r1 = Red [WIDTH*row+col+1] - VALUE;
                if(temp_r1 > 255) begin
                    red_1 = 255;
                end
                else begin
                    red_1 = Red [WIDTH*row+col+1] - VALUE;
                end
                //green 0
                temp_g0 = Green [WIDTH*row+col] - VALUE;
                if(temp_g0 > 255) begin
                    green_0 = 255;
                end
                else begin
                    green_0 = Green [WIDTH*row+col] - VALUE;
                end
                //green 1
                temp_g1 = Green [WIDTH*row+col+1] - VALUE;
                if(temp_g1 > 255) begin
                    green_1 = 255;
                end
                else begin
                    green_1 = Green [WIDTH*row+col+1] - VALUE;
                end
                //blue 0 
                temp_b0 = Blue [WIDTH*row+col] - VALUE;
                if(temp_b0 > 255) begin
                    blue_0 = 255;
                end
                else begin
                    blue_0 = Blue [WIDTH*row+col] - VALUE; 
                end
                //blue 1 
                temp_b1 = Blue [WIDTH*row+col+1] - VALUE;
                if(temp_b1 > 255) begin
                    blue_1 = 255;
                end
                else begin
                    blue_1 = Blue [WIDTH*row+col+1] - VALUE; 
                end
            end
                `endif
        end
    end
endmodule