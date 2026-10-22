`timescale 1ns / 1ps

module booth_multiplier #(
    parameter N = 8
)(
    input wire clk,
    input wire rst,
    input wire start,

    input wire signed [N-1:0] multiplicand,
    input wire signed [N-1:0] multiplier,

    output reg signed [(2*N)-1:0] product,
    output reg busy,
    output reg done
);

    // Internal registers
    reg signed [N:0] A;
    reg signed [N:0] M;
    reg signed [N-1:0] Q;
    reg Q_1;

    reg [$clog2(N+1)-1:0] count;

    // Temporary combined register for arithmetic right shift
    reg signed [(2*N)+1:0] combined;

    always @(posedge clk) begin
        if (rst) begin
            A       <= 0;
            M       <= 0;
            Q       <= 0;
            Q_1     <= 0;
            count   <= 0;
            product <= 0;
            busy    <= 0;
            done    <= 0;
        end else begin
            done <= 0;

            if (start && !busy) begin
                A     <= 0;
                M     <= {multiplicand[N-1], multiplicand};
                Q     <= multiplier;
                Q_1   <= 0;
                count <= N;
                busy  <= 1;
            end else if (busy) begin
                // Booth operation followed by arithmetic right shift
                case ({Q[0], Q_1})
                    2'b01: A <= A + M;
                    2'b10: A <= A - M;
                    default: A <= A;
                endcase

                // Build shifted value using the selected Booth operation
                case ({Q[0], Q_1})
                    2'b01: combined = { (A + M), Q, Q_1 };
                    2'b10: combined = { (A - M), Q, Q_1 };
                    default: combined = { A, Q, Q_1 };
                endcase

                combined = combined >>> 1;

                A   <= combined[(2*N)+1:N+1];
                Q   <= combined[N:1];
                Q_1 <= combined[0];

                if (count == 1) begin
                    product <= combined[(2*N)+1:1];
                    busy    <= 0;
                    done    <= 1;
                    count   <= 0;
                end else begin
                    count <= count - 1'b1;
                end
            end
        end
    end

endmodule
