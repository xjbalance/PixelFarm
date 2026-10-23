"""兼容入口：当前0.6.1的前置图/资源经济审计。"""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("simulate_061.py")),run_name="__main__")
