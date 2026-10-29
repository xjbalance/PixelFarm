"""在临时用户目录实际SIGKILL Godot，再独立启动验证；不接触玩家存档。"""
from pathlib import Path
import os
import selectors
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.tools/Godot_v4.3-stable_linux.x86_64'
SCENE = 'res://tests/palm_persistence.tscn'


def main():
    records = []
    with tempfile.TemporaryDirectory(prefix='pixel-world-real-interrupt-') as profile:
        env = dict(os.environ, XDG_DATA_HOME=profile, APPDATA=profile)
        base = [str(ENGINE), '--headless', '--path', str(ROOT), '--fixed-fps', '60', '--max-fps', '0', SCENE]
        for arguments in [['--', '--write-palm'], None, []]:
            if arguments is None:
                process = subprocess.Popen(base + ['--', '--hold-palm'], env=env,
                                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                           bufsize=0)
                selector = selectors.DefaultSelector()
                selector.register(process.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + 30
                ready = False
                try:
                    while time.monotonic() < deadline and process.poll() is None:
                        if not selector.select(.2):
                            continue
                        line = os.read(process.stdout.fileno(), 65536).decode('utf-8', errors='replace')
                        records.append(line)
                        if 'PALM CRASH READY' in line:
                            ready = True
                            break
                    if not ready:
                        raise RuntimeError('Godot未抵达临时文件中断点')
                    process.kill()  # 实际SIGKILL，不允许Godot正常关窗或退出回调。
                    process.wait(timeout=10)
                    if process.returncode != -9:
                        raise RuntimeError(f'预期SIGKILL，实际返回 {process.returncode}')
                    records.append('ACTUAL SIGKILL: PASS\n')
                finally:
                    selector.close()
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=10)
                    process.stdout.close()
            else:
                result = subprocess.run(base + arguments, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=120)
                records.append(result.stdout)
                if result.returncode or any(x in result.stdout for x in ['ERROR:', 'FAIL', 'instances leaked']):
                    raise RuntimeError('中断写入或独立恢复检查失败')
    records.append('ACTUAL PROCESS INTERRUPT AND RESTART: PASS\n')
    return ''.join(records)


if __name__ == '__main__':
    output = main()
    (ROOT / 'builds/interrupt-0.7.1.log').write_text(output)
    print(output)
