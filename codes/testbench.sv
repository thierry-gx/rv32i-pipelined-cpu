module testbench;
    logic clk_tb;
    logic reset_tb;
    wire [31:0] WriteData_tb;
    wire [31:0] DataAdr_tb;
    wire MemWrite_tb;

    riscvpipeline dut (
        .clk(clk_tb),
        .reset(reset_tb),
        .WriteData(WriteData_tb),
        .DataAdr(DataAdr_tb),
        .MemWrite(MemWrite_tb)
    );

    localparam CLK_PERIOD = 10;

    initial begin
        clk_tb = 0;
        forever #(CLK_PERIOD/2) clk_tb = ~clk_tb;
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, dut);
        
        reset_tb = 1'b1;
        #(CLK_PERIOD * 2);

        reset_tb = 1'b0;
        #(CLK_PERIOD * 200);

        $display("Simulation: %0d clock cycles executed after the reset.", 200);
        $display("Simulation finished.");
        $finish;
    end
endmodule