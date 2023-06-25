from subprocess import run
from subprocess import call, Popen, PIPE
import os

ALDEC_DIR = r"C:\Aldec\Riviera-PRO-2023.04-x64\bin"

scripts = (
    ("CH2/VHDL/sim/tb.do", True),
    ("CH2/VHDL/sim/tb_challenge.do", False),
    ("CH2/VHDL/sim/tb_challenge_solution.do", True)
)

if __name__ == "__main__":

    for script in scripts:
        path = script[0]
        print("-----------------------------------------------------------------")
        print("Run script: " + path)
        print("-----------------------------------------------------------------")
        script_name = os.path.basename(path)
        script_dir = os.path.dirname(path)
        command = [os.path.join(ALDEC_DIR, "vsim"), "-c", "-do", script_name]
        rc = call(command, cwd=script_dir) # TODO: check PASS/FAIL status

