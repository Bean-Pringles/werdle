import os
import sys
import platform
import shutil
import stat

def get_project_root():
    # installer is assumed to be in /tools or /scripts
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def is_windows():
    return platform.system() == "Windows"

def exe_name():
    return "werdle.exe" if is_windows() else "werdle"


# ---------------- WINDOWS ----------------
def install_windows(src_exe):
    import winreg

    install_dir = os.path.join(os.getenv("LOCALAPPDATA"), "werdle")
    os.makedirs(install_dir, exist_ok=True)

    dst = os.path.join(install_dir, "werdle.exe")
    shutil.copy2(src_exe, dst)

    key_path = r"Software\Microsoft\Windows\CurrentVersion\App Paths\werdle.exe"

    key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path)
    winreg.SetValueEx(key, "", 0, winreg.REG_SZ, dst)
    winreg.SetValueEx(key, "Path", 0, winreg.REG_SZ, install_dir)
    winreg.CloseKey(key)

    print("[✔] Installed to:", dst)
    print("[✔] You can now run: werdle")


# ---------------- UNIX (mac/linux) ----------------
def install_unix(src_exe):
    bin_dir = os.path.expanduser("~/.local/bin")
    os.makedirs(bin_dir, exist_ok=True)

    dst = os.path.join(bin_dir, "werdle")

    if os.path.exists(dst):
        os.remove(dst)

    shutil.copy2(src_exe, dst)

    st = os.stat(dst)
    os.chmod(dst, st.st_mode | stat.S_IEXEC)

    print("[✔] Installed to:", dst)

    print("\nIMPORTANT:")
    print('Make sure this is in your PATH:')
    print('  export PATH="$HOME/.local/bin:$PATH"')


# ---------------- MAIN ----------------
def main():
    root = get_project_root()
    src_exe = os.path.join(root, "src", exe_name())

    if not os.path.exists(src_exe):
        print("[-] Build not found:", src_exe)
        sys.exit(1)

    print("[*] Installing from:", src_exe)

    if is_windows():
        install_windows(src_exe)
    else:
        install_unix(src_exe)

    print("\nDone. Run: werdle")


if __name__ == "__main__":
    main()