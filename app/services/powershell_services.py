from pathlib import Path
import subprocess
import json 


SCRIPT_DIR = Path(__file__).resolve().parents[2] / "scripts"

def run_script(script_name: str):

    script_path = SCRIPT_DIR / script_name

    if not script_path.exists():
        raise FileNotFoundError(
            f"Script {script_name} not found in {SCRIPT_DIR}"
        )  

    result = subprocess.run(
        [
            "powershell", 
            "-ExecutionPolicy", 
            "Bypass", "-File", 
            str(script_path)
        ],
        capture_output=True,
        text=True
    )

    return result

def run_json_script(script_name: str):
    result = run_script(script_name)

    if result.returncode != 0:
        raise Exception(f"Error executing script: {result.stderr}")

    return json.loads(result.stdout)