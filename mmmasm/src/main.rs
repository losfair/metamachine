use std::str::FromStr;
use std::collections::HashMap;
use std::io::BufRead;

#[derive(Debug, Eq, PartialEq, Ord, PartialOrd, Copy, Clone)]
struct GPR(u32);

const NUM_REGS: u32 = 64;

impl FromStr for GPR {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, String> {
        if !s.starts_with("r") {
            return Err(s.into());
        }
        Ok(GPR(match s[1..].parse() {
            Ok(x) => {
                if x < NUM_REGS {
                    x
                } else {
                    return Err(s.into());
                }
            },
            Err(_) => return Err(s.into())
        }))
    }
}

#[derive(Debug, Eq, PartialEq, Ord, PartialOrd, Copy, Clone)]
#[repr(u32)]
enum BitWidth {
    W8 = 0b00,
    W16 = 0b01,
    W32 = 0b10,
    W64 = 0b11
}

impl FromStr for BitWidth {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, String> {
        Ok(match s {
            "8" => Self::W8,
            "16" => Self::W16,
            "32" => Self::W32,
            "64" => Self::W64,
            _ => return Err(s.to_string())
        })
    }
}

struct BrReloc {
    inst_index: usize,
    bit_offset: u32,
    target: String,
}

fn main() {
    let mut labels: HashMap<String, usize> = HashMap::new();
    let mut label_br_relocs: Vec<BrReloc> = Vec::new();

    let stdin = std::io::stdin();
    let stdin = stdin.lock();

    let mut inst_index: usize = 0;

    let mut body: Vec<u32> = stdin.lines().filter_map(|line| -> Option<u32> {
        let line = line.unwrap();
        let line = line.trim();
        if line.len() == 0 || line.starts_with("#") {
            None
        } else {
            let mut parts = line.splitn(2, " ").filter(|x| x.len() > 0);
            let mut inst = parts.next().expect("expecting instruction");

            if inst.ends_with(":") {
                let label = &inst[..inst.len() - 1];
                labels.insert(label.to_string(), inst_index);
                return None;
            }

            let payload = parts.next().unwrap_or("");
            let mut payload = payload.split(",").map(|x| x.trim());

            let mut out: u32 = 0;
            if inst.chars().nth(0) == Some('@') {
                out |= 1u32 << 31; // parallel
                inst = &inst[1..];
            }

            match inst {
                "nop" => {
                    out |= 0b000001u32 << 25; // nop
                }
                "movd" | "movq" => {
                    let dst = GPR::from_str(payload.next().expect("expecting dst")).unwrap();
                    let src = GPR::from_str(payload.next().expect("expecting src")).unwrap();
                    let cond: Option<u8> = payload.next().map(|x| x.parse().expect("invalid numeric literal"));

                    out |= 0b000010u32 << 25; // mov
                    out |= (match inst {
                        "movd" => 0b10u32,
                        "movq" => 0b11u32,
                        _ => unreachable!()
                    }) << 19; // width
                    out |= dst.0 << 13; // dst
                    out |= src.0 << 7; // src

                    if let Some(cond) = cond {
                        let flag = payload.next().map(|x| GPR::from_str(x).unwrap()).expect("expecting flag register");
                        out |= ((cond as u32) & 0xf) << 21; // condition
                        out |= flag.0 << 0; // flag register
                    }
                }
                "add" | "sub" | "and" | "or" | "xor" | "shl" | "shr_u" | "shr_s" | "cmp_u" | "cmp_s" => {
                    let bw = BitWidth::from_str(payload.next().expect("expecting bitwidth")).unwrap();
                    let dst = GPR::from_str(payload.next().expect("expecting dst")).unwrap();
                    let src1 = GPR::from_str(payload.next().expect("expecting src1")).unwrap();
                    let src2 = GPR::from_str(payload.next().expect("expecting src2")).unwrap();

                    out |= (match inst {
                        "add" => 0b000011u32,
                        "sub" => 0b000100u32,
                        "and" => 0b000110u32,
                        "or" => 0b000111u32,
                        "xor" => 0b000101u32,
                        "shl" => 0b001000u32,
                        "shr_u" | "shr_s" => 0b001001u32,
                        "cmp_u" | "cmp_s" => 0b010000u32,
                        _ => unreachable!(),
                    }) << 25;
                    out |= dst.0 << 19; // dst
                    out |= src1.0 << 13; // src1
                    out |= src2.0 << 7; // src2

                    out |= (bw as u32) << 4; // width

                    if inst.ends_with("_s") {
                        out |= 1u32 << 6; // signed
                    }
                }
                "ldconst16" => {
                    let nth: u8 = payload.next().expect("expecting sub-index").parse().expect("invalid numeric literal");
                    if nth >= 4 {
                        panic!("nth must be lower than 4");
                    }
                    let dst = GPR::from_str(payload.next().expect("expecting dst")).unwrap();
                    let value: u16 = payload.next().expect("expecting value").parse().expect("invalid numeric literal");

                    out |= 0b111000u32 << 25;
                    out |= (nth as u32) << 23; // nth
                    out |= dst.0 << 17; // dst
                    out |= (value as u32) << 0; // value
                }
                "br" => {
                    let label: &str = payload.next().expect("expecting label");
                    let cond: Option<u8> = payload.next().map(|x| x.parse().expect("invalid numeric literal"));

                    label_br_relocs.push(BrReloc {
                        inst_index,
                        bit_offset: 6,
                        target: label.to_string(),
                    });
                    out |= 0b010100u32 << 25;
                    if let Some(cond) = cond {
                        let flag = payload.next().map(|x| GPR::from_str(x).unwrap()).expect("expecting flag register");
                        out |= ((cond as u32) & 0xf) << 21; // condition
                        out |= flag.0 << 0; // flag register
                    }
                }
                "br_indirect" => {
                    let predicate = GPR::from_str(payload.next().expect("expecting predicate")).unwrap();
                    let cond: Option<u8> = payload.next().map(|x| x.parse().expect("invalid numeric literal"));

                    out |= 0b010101u32 << 25;
                    out |= predicate.0 << 15; // predicate register
                    if let Some(cond) = cond {
                        let flag = payload.next().map(|x| GPR::from_str(x).unwrap()).expect("expecting flag register");
                        out |= ((cond as u32) & 0xf) << 21; // condition
                        out |= flag.0 << 0; // flag register
                    }
                }
                "adr" => {
                    let dst = GPR::from_str(payload.next().expect("expecting dst")).unwrap();
                    let label: &str = payload.next().expect("expecting label");

                    label_br_relocs.push(BrReloc {
                        inst_index,
                        bit_offset: 0,
                        target: label.to_string(),
                    });
                    out |= 0b111000u32 << 25; // ldconst16
                    out |= 0u32 << 23; // nth
                    out |= dst.0 << 17; // dst
                }
                "debug" => {
                    let hint: u8 = payload.next().expect("expecting hint").parse().expect("invalid numeric literal");
                    let src = GPR::from_str(payload.next().expect("expecting src")).unwrap();
                    out |= 0b111111u32 << 25;
                    out |= (hint as u32) << 17; // hint
                    out |= src.0 << 11; // src
                }
                _ => panic!("unknown instruction: {}", inst)
            }

            inst_index += 1;
            Some(out)
        }
    }).collect();

    for reloc in label_br_relocs {
        let target = labels.get(&reloc.target).map(|x| *x).unwrap_or_else(|| panic!("label '{}' not found", reloc.target));
        body[reloc.inst_index] |= (target as u32) << reloc.bit_offset;
    }
    let body = body.iter().enumerate()
        .map(|(i, x)| format!("        {} => x\"{:08x}\",", i, x))
        .collect::<Vec<String>>().join("\n");
    println!(
r#"library IEEE;
use IEEE.std_logic_1164.all;
use work.defs.all;
package builtin_microcode is
    constant BUILTIN_MICROCODE_WORDS: microcode_t := (
{}
        others => x"00000000"
    );
end package builtin_microcode;"#, body);
}
