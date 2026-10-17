"""Applies LabLedger's Windows settings on top of the files `flutter create`
generates in CI: window title and size, exe name, version info and icon.

Usage: python tool/patch_windows.py <AppName>
"""
import pathlib
import re
import shutil
import sys

app = sys.argv[1] if len(sys.argv) > 1 else "LabLedger"
root = pathlib.Path("windows")

main_cpp = root / "runner" / "main.cpp"
src = main_cpp.read_text(encoding="utf-8")
src = re.sub(r'window\.Create\(L"[^"]*"', f'window.Create(L"{app}"', src)
src = re.sub(r"Win32Window::Size size\(\d+, \d+\)", "Win32Window::Size size(1360, 860)", src)
src = re.sub(r"Win32Window::Point origin\(\d+, \d+\)", "Win32Window::Point origin(60, 40)", src)
main_cpp.write_text(src, encoding="utf-8")

cmake = root / "CMakeLists.txt"
src = cmake.read_text(encoding="utf-8")
src = re.sub(r'set\(BINARY_NAME "[^"]*"\)', f'set(BINARY_NAME "{app}")', src)
cmake.write_text(src, encoding="utf-8")

rc = root / "runner" / "Runner.rc"
src = rc.read_text(encoding="utf-8", errors="ignore")
src = re.sub(r'VALUE "CompanyName", "[^"]*"', f'VALUE "CompanyName", "{app}"', src)
src = re.sub(r'VALUE "FileDescription", "[^"]*"', f'VALUE "FileDescription", "{app}"', src)
src = re.sub(r'VALUE "InternalName", "[^"]*"', f'VALUE "InternalName", "{app}"', src)
src = re.sub(r'VALUE "OriginalFilename", "[^"]*"', f'VALUE "OriginalFilename", "{app}.exe"', src)
src = re.sub(r'VALUE "ProductName", "[^"]*"', f'VALUE "ProductName", "{app}"', src)
rc.write_text(src, encoding="utf-8")

shutil.copyfile("windows_overrides/app_icon.ico", root / "runner" / "resources" / "app_icon.ico")
print(f"Windows runner patched for {app}")
