library IEEE;
use IEEE.std_logic_1164.all;
use work.defs.all;
package builtin_microcode is
    constant BUILTIN_MICROCODE_WORDS: microcode_t := (
        0 => x"f0000001",
        1 => x"f0020001",
        2 => x"70041388",
        3 => x"fe020000",
        4 => x"860000b0",
        5 => x"20180170",
        6 => x"28200203",
        7 => x"280000c0",
        8 => x"fe040000",
        9 => x"fe061000",
        10 => x"280002c0",
        11 => x"280002c0",
        others => x"00000000"
    );
end package builtin_microcode;
