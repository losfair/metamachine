library IEEE;
use IEEE.std_logic_1164.all;
use work.defs.all;
package builtin_microcode is
    constant BUILTIN_MICROCODE_WORDS: microcode_t := (
        0 => x"f0000001",
        1 => x"f0020001",
        2 => x"f0041388",
        3 => x"f0640400",
        4 => x"f0660c00",
        5 => x"70e80001",
        6 => x"feb40000",
        7 => x"c3a65800",
        8 => x"42167800",
        9 => x"feb60000",
        10 => x"c1e65800",
        11 => x"41ee7800",
        12 => x"7eb80000",
        13 => x"fec9e000",
        14 => x"7ecbe800",
        15 => x"feba0000",
        16 => x"c1e64800",
        17 => x"41ee6800",
        18 => x"fec9e000",
        19 => x"7ecbe800",
        20 => x"28000740",
        21 => x"fe020000",
        22 => x"860000b0",
        23 => x"20180170",
        24 => x"28200683",
        25 => x"28000540",
        26 => x"fe040000",
        27 => x"fe061000",
        28 => x"28000740",
        29 => x"28000740",
        others => x"00000000"
    );
end package builtin_microcode;
