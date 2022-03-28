## MBE

### MBE_I

| b_2i+1 | b_2i | b_2i-1 | code | operation | neg | one | two |     p    |
| ------ | ---- | ------ | ---- | --------- | --- | --- | --- | -------- |
|    0   |   0  |    0   |  +0  |    +0     |  0  |  0  |  0  | 0        |
|    0   |   0  |    1   |  +1  |    +A     |  0  |  1  |  0  | a_j      |
|    0   |   1  |    0   |  +1  |    +A     |  0  |  1  |  0  | a_j      |
|    0   |   1  |    1   |  +2  |    +2A    |  0  |  0  |  1  | a_j-1    |
|    1   |   0  |    0   |  -2  |    -2A    |  1  |  0  |  1  | ~(a_j-1) |
|    1   |   0  |    1   |  -1  |    -A     |  1  |  1  |  0  | ~a_j     |
|    1   |   1  |    0   |  -1  |    -A     |  1  |  1  |  0  | ~a_j     |
|    1   |   1  |    1   |  -0  |    +0     |  0  |  0  |  0  | 0        |

From the truth table,

**encoder**:

$$neg_i=b_{2i+1}\cdot(\overline{b_{2i}}+\overline{b_{2i-1}})$$
$$one_i=b_{2i} \oplus b_{2i-1}$$
$$two_i=\overline{b_{2i+1}}\cdot b_{2i}\cdot b_{2i-1}+b_{2i+1}\cdot\overline{b_{2i}}\cdot\overline{b_{2i-1}}$$

**decoder**:

$$p_{ij}=one_i\cdot(neg_i\oplus a_j) + two_i\cdot(neg_i\oplus a_{j-1})$$
