"""Public simulation entry for the selected stream12 architecture."""
from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('run_stream.py')),run_name='__main__')
