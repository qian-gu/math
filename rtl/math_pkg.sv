package math_pkg;

  // different modified booth encoding
  typedef enum integer {
      MBE_I   = 0,
      MBE_II  = 1,
      MBE_III = 2,
      MBE_IV  = 3
  } mbe_e;

  //  | sh_mode_i  | shift mode | function               |
  //  | ---------- | ---------- | ---------------------- |
  //  |    3'b000  |     sll    | shift left logic       |
  //  |    3'b100  |     srl    | shift right logic      |
  //  |    3'b101  |     sra    | shift right arithmetic |
  //  |    3'b011  |     slb    | shift left barrel      |
  //  |    3'b111  |     srb    | shift right barrel     |
  typedef enum logic [2 : 0] {
    SLL = 3'b000,
    SRL = 3'b100,
    SRA = 3'b101,
    SLB = 3'b011,
    SRB = 3'b111
  } shift_mode_e;

  //  | round_mode_i   | round mode          |
  //  | -------------- | ------------------- |
  //  |     4'b0000    |   DIRECT_UP         |
  //  |     4'b0001    |   DIRECT_DOWN       |
  //  |     4'b0010    |   DIRECT_TO_ZERO    |
  //  |     4'b0011    |   DIRECT_AWAY_ZERO  |
  //  |     4'b1000    |   NEAREST_UP        |
  //  |     4'b1001    |   NEAREST_DOWN      |
  //  |     4'b1010    |   NEAREST_TO_ZERO   |
  //  |     4'b1011    |   NEAREST_AWAY_ZERO |
  //  |     4'b1100    |   NEAREST_EVEN      |
  //  |     4'b1101    |   NEAREST_ODD       |
  typedef enum logic [3 : 0] {
    DIRECT_UP         = 4'b0000,
    DIRECT_DOWN       = 4'b0001,
    DIRECT_TO_ZERO    = 4'b0010,
    DIRECT_AWAY_ZERO  = 4'b0011,
    NEAREST_UP        = 4'b1000,
    NEAREST_DOWN      = 4'b1001,
    NEAREST_TO_ZERO   = 4'b1010,
    NEAREST_AWAY_ZERO = 4'b1011,
    NEAREST_EVEN      = 4'b1100,
    NEAREST_ODD       = 4'b1101
  } round_mode_e;

endpackage
