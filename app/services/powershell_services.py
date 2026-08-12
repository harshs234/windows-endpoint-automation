from pathlib import Path
import subprocess
import json 


SCRIPT_DIR = Path(__file__).resolve().parents[2] / "scripts"

def run_script(script_name: str, args: list[str] | None = None):

    script_path = SCRIPT_DIR / script_name

    if not script_path.exists():
        raise FileNotFoundError(
            f"Script {script_name} not found in {SCRIPT_DIR}"
        )  

    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script_path)
    ]

    if args:
        command.extend(args)

    print("COMMAND:", command)

    result = subprocess.run(
        command,
        capture_output=True,
        text=True
    )

    return result

# def run_json_script(script_name: str, args: list[str] | None = None):
#     result = run_script(script_name, args)

#     if result.returncode != 0:
#         raise Exception(f"Error executing script: {result.stderr}")

#     return json.loads(result.stdout)

def run_json_script(script_name: str, args: list[str] | None = None):
    result = run_script(script_name, args)

    if result.returncode != 0:
        raise Exception(f"Error executing script: {result.stderr}")

    print("RETURN CODE:", result.returncode)
    print("STDOUT:")
    print(result.stdout)
    print("STDERR:")
    print(result.stderr)

    output = result.stdout.strip()

    if not output:
        raise Exception("PowerShell script returned no output.")

    json_start_object = output.find("{")
    json_start_array = output.find("[")

    starts = [
        pos for pos in [json_start_object, json_start_array]
        if pos != -1
    ]

    if not starts:
        raise Exception(f"No JSON found in PowerShell output:\n{output}")

    json_start = min(starts)
    json_output = output[json_start:]

    return json.loads(json_output)