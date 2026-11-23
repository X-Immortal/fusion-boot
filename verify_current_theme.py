from pathlib import Path
import json
import subprocess

def wsl_path(windows_path):
    return subprocess.check_output(["wslpath", "-u", windows_path], text=True).strip()


local_app_data = subprocess.check_output(
    ["powershell.exe", "-NoProfile", "-Command", "[Environment]::GetFolderPath('LocalApplicationData')"],
    text=True,
).strip()
state_path = Path(wsl_path(local_app_data)) / "CodexDreamSkin" / "state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
node = wsl_path(state["nodePath"])
command = [node, state["injectorPath"], "--verify", "--port", str(state["port"]),
           "--browser-id", state["browserId"], "--theme-dir", state["themeDir"], "--timeout-ms", "5000"]
result = subprocess.run(command, capture_output=True, text=True, timeout=20)
report = json.loads(result.stdout)
for item in report.get("targets", []):
    value = item.get("result", {})
    if value.get("themeId"):
        readiness = value.get("readiness", {})
        print(json.dumps({"exit": result.returncode, "themeId": value.get("themeId"),
                          "expectedThemeId": value.get("expectedThemeId"),
                          "installed": value.get("installed"), "stylePresent": value.get("stylePresent"),
                          "windowPass": readiness.get("windowPass"), "viewportPass": readiness.get("viewportPass"),
                          "structurePass": readiness.get("structurePass")}, ensure_ascii=False))
