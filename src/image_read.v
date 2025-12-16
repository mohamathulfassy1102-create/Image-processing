// Choose the operation of code by delete // in the beginning of the selected line


//`define BRIGHTNESS_OP
`define INVERSION_OP
//`define THRESHOLD_OP 
//`define BLUR_OP
//`define SHARPEN_OP
//`define EDGE_H_OP
//`define CONTRAST_OP

module image_read #(
    parameter   WIDTH = 768,
                HEIGHT = 512,
                FILE = "input_image.hex",
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
    output V_sync,
    output reg [7:0] red_0,red_1,green_0,green_1,blue_0,blue_1,
    output rd_done
);
    //for blur
    integer sumR0, sumG0, sumB0;
    integer sumR1, sumG1, sumB1;
    
    //for contrast
    integer cR0, cG0, cB0;
    integer cR1, cG1, cB1;
    integer tmp;
    
    // for edge
    integer eR0, eG0, eB0;
    integer eR1, eG1, eB1;
            
    //for sharpen
    integer sR0, sG0, sB0;
    integer sR1, sG1, sB1;

    integer idx_c0, idx_c1;
    integer idx_c0_left, idx_c0_right;
    integer idx_c1_left, idx_c1_right;
    
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
    reg [7:0] total_memory [0:SIZE_OF_LENGTH-1];	// memory to store  8-bit data image
// temporary memoryto save image data : size will be WIDTH*HEIGHT*3
    integer temp_bmp   [0:WIDTH*HEIGHT*3-1];			
    integer Red  [0:WIDTH*HEIGHT-1]; 	
    integer Green  [0:WIDTH*HEIGHT-1];	
    integer Blue  [0:WIDTH*HEIGHT-1];	
    
    integer i, j;

    integer temp_r0,temp_r1,temp_g0,temp_g1,temp_b0,temp_b1; // temporary variables in contrast and brightness operation

    integer value,value1,value2,value4;
    reg [9:0] row; // row index of the image
    reg [10:0] col; // column index of the image
    reg [18:0] data_count; // data counting for entire pixels of the image

    initial begin
        $readmemh(FILE,total_memory,0,SIZE_OF_LENGTH-1);
    end

    always @(start) begin // For storing image data
        if(start == 1'b1 ) begin
            for (i = 0; i<WIDTH*HEIGHT*3 ; i = i+1) begin
                temp_bmp[i] = total_memory[i][7:0];
            end
            for (i = 0; i<HEIGHT ; i = i+1) begin
                for (j = 0; j<WIDTH ; j = j+1) begin
                    Red [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+0]; // save red component
                    Green [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+1]; // save green component
                    Blue [WIDTH*i+j] = temp_bmp [WIDTH*3*(HEIGHT-i-1)+3*j+2]; // save blue component
                end
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
                    nxt_state = ST_IDLE;
                end
            end
            ST_VSYNC : begin
                if(V_sync_cnt == START_UP_DELAY) begin
                    nxt_state = ST_HSYNC;
                end
                else begin
                    nxt_state = ST_VSYNC;
                end
            end
            ST_HSYNC : begin
                if(H_sync_cnt == H_SYNC_DELAY) begin
                    nxt_state = ST_DATA;
                end
                else begin
                    nxt_state = ST_HSYNC;
                end
            end
            ST_DATA : begin
                if(rd_done) begin
                    nxt_state = ST_IDLE;
                end
                else begin
                    if(col == WIDTH - 2) begin
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
        V_sync_ctrl = 0;
        H_sync_ctrl = 0;
        data_ctrl = 0;
        case (curr_state)
            ST_VSYNC : begin V_sync_ctrl = 1; end
            ST_HSYNC : begin H_sync_ctrl = 1; end
            ST_DATA : begin data_ctrl = 1; end 
        endcase
    end

    always @(posedge clk , negedge rst_n) begin
        if (!rst_n) begin
            H_sync_cnt <= 0;
            V_sync_cnt <= 0;
        end
        else begin
            if(V_sync_ctrl) begin
			    V_sync_cnt <= V_sync_cnt + 1; // counting for vsync
            end
		    else begin
			    V_sync_cnt <= 0;
            end	
            if(H_sync_ctrl) begin
			    H_sync_cnt <= H_sync_cnt + 1;	// counting for hsync
            end		
		    else begin
			    H_sync_cnt <= 0;
            end
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
        if(!rst_n) begin
            data_count <= 0;
        end
        else begin
            if(data_ctrl) begin
                data_count <= data_count + 1;
            end
        end
    end
    assign V_sync = V_sync_ctrl;
    assign rd_done = (data_count == 196607) ? 1'b1 : 1'b0;

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
            // center indices
            idx_c0 = WIDTH * row + col;       // center pixel for DATA_*0
            idx_c1 = WIDTH * row + (col + 1); // center pixel for DATA_*1

            // left/right with boundary checks for pixel0
            if (col == 0) idx_c0_left = idx_c0;
            else idx_c0_left = idx_c0 - 1;
            if (col + 1 >= WIDTH) idx_c0_right = idx_c0; // shouldn't happen for col range, safe guard
            else idx_c0_right = idx_c0 + 1;

            // left/right with boundary checks for pixel1
            if ((col + 1) == 0) idx_c1_left = idx_c1;
            else idx_c1_left = idx_c1 - 1;
            if ((col + 1) >= (WIDTH - 1)) idx_c1_right = idx_c1; // if at last column replicate
            else idx_c1_right = idx_c1 + 1;

            `ifdef BRIGHTNESS_OP
            // Brightness addition operation
            if(BRIGHT) begin
                //red 0
                temp_r0 = Red [idx_c0] + VALUE;
                if(temp_r0 > 255) begin
                    red_0 = 255;
                end
                else begin
                    red_0 = Red [idx_c0] + VALUE;
                end
                //red 1
                temp_r1 = Red [idx_c1] + VALUE;
                if(temp_r1 > 255) begin
                    red_1 = 255;
                end
                else begin
                    red_1 = Red [idx_c1] + VALUE;
                end
                //green 0
                temp_g0 = Green [idx_c0] + VALUE;
                if(temp_g0 > 255) begin
                    green_0 = 255;
                end
                else begin
                    green_0 = Green [idx_c0] + VALUE;
                end
                //green 1
                temp_g1 = Green [idx_c1] + VALUE;
                if(temp_g1 > 255) begin
                    green_1 = 255;
                end
                else begin
                    green_1 = Green [idx_c1] + VALUE;
                end
                //blue 0 
                temp_b0 = Blue [idx_c0] + VALUE;
                if(temp_b0 > 255) begin
                    blue_0 = 255;
                end
                else begin
                    blue_0 = Blue [idx_c0] + VALUE; 
                end
                //blue 1 
                temp_b1 = Blue [idx_c1] + VALUE;
                if(temp_b1 > 255) begin
                    blue_1 = 255;
                end
                else begin
                    blue_1 = Blue [idx_c1] + VALUE; 
                end
            end
            else begin
                //brightness subtraction operation
                //red 0
                temp_r0 = Red [idx_c0] - VALUE;
                if(temp_r0 < 0) begin
                    red_0 = 0;
                end
                else begin
                    red_0 = Red [idx_c0] - VALUE;
                end
                //red 1
                temp_r1 = Red [idx_c1] - VALUE;
                if(temp_r1 < 0) begin
                    red_1 = 0;
                end
                else begin
                    red_1 = Red [idx_c1] - VALUE;
                end
                //green 0
                temp_g0 = Green [idx_c0] - VALUE;
                if(temp_g0 < 0 ) begin
                    green_0 = 0;
                end
                else begin
                    green_0 = Green [idx_c0] - VALUE;
                end
                //green 1
                temp_g1 = Green [idx_c1] - VALUE;
                if(temp_g1 < 0) begin
                    green_1 = 0;
                end
                else begin
                    green_1 = Green [idx_c1] - VALUE;
                end
                //blue 0 
                temp_b0 = Blue [idx_c0] - VALUE;
                if(temp_b0 < 0) begin
                    blue_0 = 0;
                end
                else begin
                    blue_0 = Blue [idx_c0] - VALUE; 
                end
                //blue 1 
                temp_b1 = Blue [idx_c1] - VALUE;
                if(temp_b1 < 0) begin
                    blue_1 = 0;
                end
                else begin
                    blue_1 = Blue [idx_c1] - VALUE; 
                end
            end
            `endif

            // Inversion Operation
            `ifdef INVERSION_OP
                value2 = (Blue[idx_c0]+Red[idx_c0]+Green[idx_c0])/3;
                red_0 = 255 - value2;
                green_0 = 255 - value2;
                blue_0 = 255 - value2;
                value4 = (Blue[idx_c1]+Red[idx_c1]+Green[idx_c1])/3;
                red_1 = 255 - value4;
                green_1 = 255 - value4;
                blue_1 = 255 - value4;
            `endif
        
            // Threshold Operation
            `ifdef THRESHOLD_OP
                value = (Blue[idx_c0]+Red[idx_c0]+Green[idx_c0])/3;
                if (value > THRESHOLD) begin
                    red_0 = 255;
                    green_0 = 255;
                    blue_0 = 255;
                end
                else begin
                    red_0 = 0;
                    green_0 = 0;
                    blue_0 = 0;
                end
                value1 = (Blue[idx_c1]+Red[idx_c1]+Green[idx_c1])/3;
                if (value1 > THRESHOLD) begin
                    red_1 = 255;
                    green_1 = 255;
                    blue_1 = 255;
                end
                else begin
                    red_1 = 0;
                    green_1 = 0;
                    blue_1 = 0;
                end
            `endif 

            // BLUR operation
            `ifdef BLUR_OP
         
                sumR0 = Red[idx_c0_left] + Red[idx_c0] + Red[idx_c0_right];
                sumG0 = Green[idx_c0_left] + Green[idx_c0] + Green[idx_c0_right];
                sumB0 = Blue[idx_c0_left] + Blue[idx_c0] + Blue[idx_c0_right];

                sumR1 = Red[idx_c1_left] + Red[idx_c1] + Red[idx_c1_right];
                sumG1 = Green[idx_c1_left] + Green[idx_c1] + Green[idx_c1_right];
                sumB1 = Blue[idx_c1_left] + Blue[idx_c1] + Blue[idx_c1_right];

                red_0 = (sumR0 / 3) > 255 ? 8'd255 : (sumR0 / 3);
                green_0 = (sumG0 / 3) > 255 ? 8'd255 : (sumG0 / 3);
                blue_0 = (sumB0 / 3) > 255 ? 8'd255 : (sumB0 / 3);

                red_1 = (sumR1 / 3) > 255 ? 8'd255 : (sumR1 / 3);
                green_1 = (sumG1 / 3) > 255 ? 8'd255 : (sumG1 / 3);
                blue_1 = (sumB1 / 3) > 255 ? 8'd255 : (sumB1 / 3);
            `endif

            // SHARPEN Operation
            `ifdef SHARPEN_OP

                sR0 = 5 * Red[idx_c0] - Red[idx_c0_left] - Red[idx_c0_right];
                sG0 = 5 * Green[idx_c0] - Green[idx_c0_left] - Green[idx_c0_right];
                sB0 = 5 * Blue[idx_c0] - Blue[idx_c0_left] - Blue[idx_c0_right];

                sR1 = 5 * Red[idx_c1] - Red[idx_c1_left] - Red[idx_c1_right];
                sG1 = 5 * Green[idx_c1] - Green[idx_c1_left] - Green[idx_c1_right];
                sB1 = 5 * Blue[idx_c1] - Blue[idx_c1_left] - Blue[idx_c1_right];

                // clamp to 0..255
                red_0 = (sR0 > 255) ? 8'd255 : ((sR0 < 0) ? 8'd0 : sR0);
                green_0 = (sG0 > 255) ? 8'd255 : ((sG0 < 0) ? 8'd0 : sG0);
                blue_0 = (sB0 > 255) ? 8'd255 : ((sB0 < 0) ? 8'd0 : sB0);

                red_1 = (sR1 > 255) ? 8'd255 : ((sR1 < 0) ? 8'd0 : sR1);
                green_1 = (sG1 > 255) ? 8'd255 : ((sG1 < 0) ? 8'd0 : sG1);
                blue_1 = (sB1 > 255) ? 8'd255 : ((sB1 < 0) ? 8'd0 : sB1);
            `endif

            // EDGE Operation 
            `ifdef EDGE_H_OP

                eR0 = Red[idx_c0_right] - Red[idx_c0_left];
                eG0 = Green[idx_c0_right] - Green[idx_c0_left];
                eB0 = Blue[idx_c0_right] - Blue[idx_c0_left];

                eR1 = Red[idx_c1_right] - Red[idx_c1_left];
                eG1 = Green[idx_c1_right] - Green[idx_c1_left];
                eB1 = Blue[idx_c1_right] - Blue[idx_c1_left];

                // magnitude (abs) and clamp
                eR0 = (eR0 < 0) ? -eR0 : eR0; if (eR0 > 255) eR0 = 255;
                eG0 = (eG0 < 0) ? -eG0 : eG0; if (eG0 > 255) eG0 = 255;
                eB0 = (eB0 < 0) ? -eB0 : eB0; if (eB0 > 255) eB0 = 255;

                eR1 = (eR1 < 0) ? -eR1 : eR1; if (eR1 > 255) eR1 = 255;
                eG1 = (eG1 < 0) ? -eG1 : eG1; if (eG1 > 255) eG1 = 255;
                eB1 = (eB1 < 0) ? -eB1 : eB1; if (eB1 > 255) eB1 = 255;

                red_0 = eR0;
                green_0 = eG0;
                blue_0 = eB0;

                red_1 = eR1;
                green_1 = eG1;
                blue_1 = eB1;
            `endif

            // CONTRAST Operation
            `ifdef CONTRAST_OP

                tmp = (Red[idx_c0] - 128) * CONTRAST_GAIN + 128;
                cR0 = tmp; if (cR0 < 0) cR0 = 0; else if (cR0 > 255) cR0 = 255;
                tmp = (Green[idx_c0] - 128) * CONTRAST_GAIN + 128;
                cG0 = tmp; if (cG0 < 0) cG0 = 0; else if (cG0 > 255) cG0 = 255;
                tmp = (Blue[idx_c0] - 128) * CONTRAST_GAIN + 128;
                cB0 = tmp; if (cB0 < 0) cB0 = 0; else if (cB0 > 255) cB0 = 255;

                tmp = (Red[idx_c1] - 128) * CONTRAST_GAIN + 128;
                cR1 = tmp; if (cR1 < 0) cR1 = 0; else if (cR1 > 255) cR1 = 255;
                tmp = (Green[idx_c1] - 128) * CONTRAST_GAIN + 128;
                cG1 = tmp; if (cG1 < 0) cG1 = 0; else if (cG1 > 255) cG1 = 255;
                tmp = (Blue[idx_c1] - 128) * CONTRAST_GAIN + 128;
                cB1 = tmp; if (cB1 < 0) cB1 = 0; else if (cB1 > 255) cB1 = 255;

                red_0 = cR0[7:0];
                green_0 = cG0[7:0];
                blue_0 = cB0[7:0];

                red_1 = cR1[7:0];
                green_1 = cG1[7:0];
                blue_1 = cB1[7:0];
            `endif
        end 
    end
endmodule