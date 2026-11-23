"""Rebuild the selected snapshots with the pinned local tools in a temporary directory."""
import argparse
import os
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent



def functions_at(log, pass_name):
    functions = {}
    for block in log.split('// -----// IR Dump After ')[1:]:
        header, _, body = block.partition('\n')
        if '(' + pass_name + ')' not in header:
            continue
        match = re.search(r'^(func\.func @(add_kernel(?:_outlined_vf_\d+)?)\(.*?^\})', body, re.M | re.S)
        if match:
            code, name = match.groups()
            if name in functions and functions[name] != code:
                raise ValueError('ambiguous snapshot: ' + name)
            functions[name] = code
    if 'add_kernel' not in functions:
        raise ValueError('missing entry at ' + pass_name)
    return '\n\n'.join(functions.values()) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(exist_ok=True, parents=True)
    bindir = args.bin.resolve()
    env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'])
    def run(program, *args, **kwargs):
        return subprocess.run([str(bindir/program), *args], env=env, **kwargs)
    for profile in sorted((ROOT/'profiles').glob('*.mlir')):
        emitted = run('bishengir-opt', '--hacc-append-device-spec=target=' + profile.stem,
                      input='module {}\n', capture_output=True, text=True, check=True)
        if emitted.stdout != profile.read_text():
            raise ValueError('target spec differs: ' + profile.stem)
    print(run('bishengir-opt','--version',capture_output=True,text=True,check=True).stdout.splitlines()[0])
    for version in ('v1','v2'):
        run('bishengir-opt',ROOT/'official/mix.mlir',
            f'--pass-pipeline=builtin.module(hivm-delayed-cross-core-gss{{solver-version={version}}})',
            '-o',out/f'mix-{version}.mlir',check=True)
    expected_mix = (ROOT/'official/mix-v2.mlir').read_bytes()
    for version in ('v1', 'v2'):
        if (out/f'mix-{version}.mlir').read_bytes() != expected_mix:
            raise ValueError('MIX solver output differs: ' + version)
    run('bishengir-opt',out/'mix-v2.mlir','-hivm-graph-sync-solver=solver-version=v2','-o',out/'mix-both.mlir',check=True)
    if (out/'mix-both.mlir').read_bytes() != (ROOT/'official/mix-both.mlir').read_bytes():
        raise ValueError('combined MIX snapshot differs')
    print('MIX: DCCGSS v1=v2; cross-core + local snapshot matched')
    run('bishengir-opt', ROOT/'issue920/920.mlir',
        '-cv-pipelining=pipeline-mode=skew enable-preload=true set-depth-in-unroll-mode=2 bypass-shape-registry=true',
        '-o',out/'920.mlir',check=True)
    with (out/'920.mlir').open() as inp:
        check=run('FileCheck',ROOT/'issue920/920.mlir',stdin=inp,capture_output=True,text=True)
    if check.returncode != 1 or check.stderr.count('CHECK-NOT: excluded string found') != 2:
        raise ValueError('unexpected issue 920 FileCheck verdict: ' + check.stderr)
    if (out/'920.mlir').read_bytes() != (ROOT/'issue920/920-exact.mlir').read_bytes():
        raise ValueError('issue 920 snapshot differs')
    print('#920: pass exit 0; two expected negative checks failed on this build')
    with tempfile.TemporaryDirectory() as scratch:
        for stem, target, disabled, boundary in (
            ('910B1-on','Ascend910B1',False,'hivm-add-ffts-to-syncblocksetop'),
            ('910B1-off','Ascend910B1',True,'hivm-add-ffts-to-syncblocksetop'),
            ('950-on','Ascend950PR_9579',False,'hivm-graph-sync-solver')):
            result=run('bishengir-compile',ROOT/'triton/add.hfusion.mlir',f'--target={target}',
                       '--enable-hfusion-compile','--enable-triton-kernel-compile','--enable-lir-compile=false',
                       '--disable-hivm-auto-inject-sync='+str(disabled).lower(),'--mlir-disable-threading',
                       '--mlir-print-ir-after-all','-o',Path(scratch)/'kernel.ll',cwd=scratch,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            active='IR Dump After GraphSyncSolver (' in result.stdout
            if active == disabled:
                raise ValueError('unexpected GraphSyncSolver activation: ' + stem)
            if stem == '910B1-on':
                common = functions_at(result.stdout,'hivm-graph-sync-solver')
                common_file = out/'910B1-on.after-gss.mlir'
                common_file.write_text(common)
                run('bishengir-opt',common_file,'-o',os.devnull,check=True)
                common_ref = ROOT/'triton'/common_file.name
                if common_ref.read_text() != common:
                    raise ValueError('910B1 common-stage snapshot differs')
            snapshot=functions_at(result.stdout,boundary)
            file=out/(stem+'.mlir')
            file.write_text(snapshot)
            run('bishengir-opt',file,'-o',os.devnull,check=True)
            print(stem,'driver exit',result.returncode,'GSS',active,
                  'set/wait/barrier',*[snapshot.count('hivm.hir.'+op) for op in ('set_flag','wait_flag','pipe_barrier')])
            ref=ROOT/'triton'/file.name
            if ref.read_bytes() != file.read_bytes():
                raise ValueError('snapshot differs: '+file.name)


if __name__=='__main__':
    main()
