"""Derive the runtime-release companion while preserving the original experiment."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parents[1]
body = (ROOT/'project/experiments/timbre/fm/src/fm_voice.v').read_text()
body = body.replace('module fm_voice(', 'module playable_fm_voice(')
body = body.replace('input wire [31:0] seed,', 'input wire [31:0] seed, input wire [2:0] release_index,')
body = body.replace('localparam [13:0] RELEASE_LENGTH = 14\'d7212;\nlocalparam [28:0] RELEASE_STEP = 29\'d37226;',
'''// Sample counts at 50MHz/1040; index 3 is bit-exact legacy release.
reg [16:0] release_length;
reg [28:0] release_step,held_release_step;
always @* case(release_index)
''' + '\n'.join(f"    3'd{i}: begin release_length=17'd{n}; release_step=29'd{37226 if i==3 else (268435456+n-1)//n}; end" for i,n in enumerate([1442,2885,4808,7212,14423,28846,48077,96154])) + '''
endcase''')
body = body.replace('reg [13:0] release_left;', 'reg [16:0] release_left;')
body = body.replace('release_left <= RELEASE_LENGTH;', 'release_left <= release_length; held_release_step <= release_step;')
body = body.replace('release_gain <= ONE; release_left <= 0; releasing <= 0;', 'release_gain <= ONE; release_left <= 0; releasing <= 0; held_release_step <= 37226;')
body = body.replace('RELEASE_STEP', 'held_release_step')
# Equivalent round-to-nearest, ties away from zero, without 64-bit abs/add/negate.
# Split rounding and saturation into two clocks; the sample number is unchanged.
body = body.replace('wire signed [63:0] rounded_output = mul_p[63] ?\n    -(((-mul_p) + 64\'sd8388608) >>> 24) : ((mul_p + 64\'sd8388608) >>> 24);',
'''wire round_up = mul_p[63] ? (mul_p[23:0] > 24'h800000) : (mul_p[23:0] >= 24'h800000);
wire signed [40:0] rounded_value = $signed(mul_p[63:24]) + $signed({40'd0,round_up});
reg signed [40:0] rounded_output;''')
body = body.replace('state <= 0; phase <= 0; phase_step <= 0;', 'state <= 0; phase <= 0; phase_step <= 0; rounded_output <= 0;')
body = body.replace('16: begin\n                    if (rounded_output', '16: begin rounded_output <= rounded_value; state <= 17; end\n                17: begin\n                    if (rounded_output')
body = body.replace('16-cycle schedule.', '18-clock pipeline with registered rounding/saturation.')
(HERE/'src/playable_fm_voice.v').write_text('// Derived by tools/generate_fm.py; runtime release + sample-exact output pipeline.\n'+body)
print('Generated playable_fm_voice.v')
