"""Read-only delivery checks; outputs evidence only under _reviews/."""
from pathlib import Path
import datetime
import hashlib
import re
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
log_path = root / '_reviews' / 'P_GC_AE_VERIFY.log'
bash = Path('C:/Program Files/Git/bin/bash.exe')
failed = []
with log_path.open('w', encoding='utf-8') as log:
    def emit(text):
        log.write(str(text) + '\n')
        log.flush()
    def run(args):
        emit('COMMAND ' + repr(args))
        result = subprocess.run(args, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        emit('EXIT ' + str(result.returncode))
        if result.returncode:
            failed.append(repr(args))
    emit('time=' + datetime.datetime.now(datetime.timezone.utc).isoformat())
    emit('root=' + str(root))
    run(['git', 'rev-parse', 'HEAD'])
    run(['git', 'status', '--short'])
    run(['git', 'ls-files', '--stage', 'scripts/'])
    run(['git', 'diff', '--check'])
    for name in ('android_device_xiaomi_polaris', 'android_vendor_terminalos', 'android_packages_apps_TerminalHome'):
        run(['git', '-C', str(root.parent / 'Polaris-TerminalOS-repos' / name), 'rev-parse', 'HEAD'])
    docs = sorted((root / 'docs').glob('*.md'))
    emit('DOCS ' + repr([p.name for p in docs]))
    for prefix in range(12):
        found = [p for p in docs if p.name.startswith(f'{prefix:02}_')]
        emit(f'DOC_{prefix:02} count={len(found)}')
        if len(found) != 1:
            failed.append(f'doc {prefix:02}')
    for p in sorted((root / 'scripts').glob('*.sh')):
        data = p.read_bytes()
        emit(f'FILE {p.relative_to(root)} sha256={hashlib.sha256(data).hexdigest()} CRLF={data.count(bytes([13,10]))}')
        run([str(bash), '-n', str(p)])
    manifest = root / 'local_manifests' / 'terminalos.xml'
    tree = ET.parse(manifest).getroot()
    projects = tree.findall('project')
    paths = [p.attrib['path'] for p in projects]
    emit(f'XML root={tree.tag} projects={len(projects)} unique_paths={len(set(paths))}')
    if tree.tag != 'manifest' or len(projects) != 6 or len(set(paths)) != 6:
        failed.append('manifest structure')
    for p in projects:
        emit('PROJECT ' + repr(p.attrib))
    matrix = root / 'acceptance' / '验收测试矩阵.md'
    rows = re.findall(r'^\| (T\d{2}) \| (.*?) \| (.*?) \| (.*?) \| (.*?) \|', matrix.read_text(encoding='utf-8'), re.M)
    emit('MATRIX ' + repr(rows))
    if [r[0] for r in rows] != [f'T{n:02}' for n in range(1, 21)]:
        failed.append('matrix IDs')
    spec = root.parent / 'Polaris-TerminalOS_实施说明书.md'
    emit(f'SPEC_EXISTS {spec} {spec.is_file()}')
    emit('NOTE Missing original specification blocks section 11 conformance sign-off; not a static parser failure.')
    for p in [root / 'README.md', *docs, matrix, manifest]:
        emit(f'SHA256 {p.relative_to(root)} {hashlib.sha256(p.read_bytes()).hexdigest()}')
    emit('STATIC_CHECK_FAILURES ' + repr(failed))
print(str(log_path))
print('Static check failures: ' + str(len(failed)))
raise SystemExit(bool(failed))
