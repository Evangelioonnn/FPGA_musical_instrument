"""Simulation acceleration, verified against the literal production quarter ROM."""
from pathlib import Path
import subprocess,re,hashlib,tempfile,json
def prepare(lab,modelsim):
    lab=Path(lab);root=lab.parents[1];source=lab/'src/refinement_sine.v'
    values=re.findall(r"10'd(\d+): magnitude<=16'h([0-9a-fA-F]+);",source.read_text())
    if len(values)!=1024 or [int(i) for i,v in values]!=list(range(1024)):raise ValueError('Quarter ROM shape')
    parent=lab/'sim/work_compact_data';parent.mkdir(parents=True,exist_ok=True)
    work=Path(tempfile.mkdtemp(prefix='check-',dir=parent));data=work/'quarter.hex'
    data.write_text('\n'.join(v for i,v in values)+'\n')
    array=work/'refinement_sine_array.v'
    array.write_text('''module refinement_sine_array(input wire clk,input wire [11:0] addr,output wire signed [15:0] data);
wire [9:0] q=addr[10] ? 10'd0-addr[9:0] : addr[9:0];
reg [15:0] rom[0:1023];reg [15:0] magnitude=0;reg negative=0,peak=0;
initial $readmemh("'''+data.as_posix()+'''",rom);
wire signed [15:0] positive=peak ? 16'sd32767 : $signed(magnitude);
assign data=negative ? -positive : positive;
always @(posedge clk) if((^addr)!==1'bx) begin magnitude<=rom[q];negative<=addr[11];peak<=addr[10] && addr[9:0]==0;end
endmodule
''')
    bench=work/'compact_rom_check.v';bench.write_text('''`timescale 1ns/1ps
module compact_rom_check;reg clk=0;always #10 clk=~clk;reg [11:0] addr=0;wire signed [15:0] a,b;
refinement_sine literal(clk,addr,a);refinement_sine_array array(clk,addr,b);integer i;reg [31:0] rng=32'h51ab23df;
task check;begin @(posedge clk);#1;if(a!==b) $fatal(1,"compact array %h %d %d",addr,a,b);@(negedge clk);end endtask
initial begin #1;if(a!==b) $fatal(1,"initial");@(negedge clk);
for(i=0;i<4096;i=i+1) begin addr=i;check;end
for(i=0;i<1000;i=i+1) begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};addr=rng[11:0];check;end
addr=12'hxxx;check;addr=12'hzzz;check;addr=0;check;
$display("COMPACT_ROM_ARRAY_PASS all4096 random1000 XZ initial");$finish;end endmodule
''')
    lib=work/'work'
    def run(tool,args):
        p=subprocess.run([str(Path(modelsim)/tool),*args],cwd=work,capture_output=True,text=True,errors='replace',timeout=120)
        out=p.stdout+'\n'+p.stderr
        if p.returncode or re.search(r'\*\* (Error|Fatal)',out):raise RuntimeError(out[-6000:])
        return out
    run('vlib.exe',[str(lib)])
    run('vlog.exe',['-vlog01compat','-work',str(lib),str(source),str(array),str(bench)])
    log=run('vsim.exe',['-c','-lib',str(lib),'compact_rom_check','-do','onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f'])
    if 'COMPACT_ROM_ARRAY_PASS' not in log:raise RuntimeError('ROM verification incomplete')
    replacement=work/'refinement_sine.v';replacement.write_text(array.read_text().replace('module refinement_sine_array','module refinement_sine'))
    return {'replacement_source':str(replacement),'verified':True,
        'source_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [source,Path(__file__).resolve()]}}
