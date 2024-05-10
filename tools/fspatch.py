import argparse
import os


def scanfs(file) -> dict[str, list[str]]:
    filesystem_config = {}
    with open(file, "r") as file_:
        for line in file_:
            try:
                filepath, *other = line.strip().split()
            except Exception as e:
                print(f"[W] Skip line '{line}'. Error: {e}")
                continue
            filesystem_config[filepath] = other
            if len(other) > 4:
                print(f"[W] {filepath} has too much data-{len(other)}.")
    return filesystem_config


def scan_dir(folder) -> list[str]:
    allfiles = [
        os.path.abspath(os.path.join(folder, "..", p))
        for p in ["/", "/lost+found", f"{os.path.basename(folder)}/lost+found", f"{os.path.basename(folder)}/"]
    ]
    base_name = os.path.basename(folder)
    if os.name == "nt":
        yield base_name.replace("\\", "")
    elif os.name == "posix":
        yield base_name.replace("/", "")
    else:
        yield base_name
    for root, dirs, files in os.walk(folder, topdown=True):
        for dir_ in dirs:
            yield os.path.join(root, dir_).replace(folder, base_name).replace("\\", "/")
        for file in files:
            yield os.path.join(root, file).replace(folder, base_name).replace("\\", "/")
        for rv in allfiles:
            yield rv


def islink(file) -> str:
    if os.name == "nt":
        if not os.path.isdir(file):
            with open(file, "rb") as f:
                if f.read(10) == b"!<symlink>":
                    return f.read().decode("utf-16")[:-1]
                else:
                    return ""
    elif os.name == "posix":
        if os.path.islink(file):
            return os.readlink(file)
        else:
            return ""


def fs_patch(fs_file, dir_path) -> tuple[dict[str, list[str]], int]:  # 接收两个字典对比
    new_fs = {}
    new_add = 0
    r_fs = {}
    print("FsPatcher: Load origin", len(fs_file.keys()), "entries")
    for file_path in scan_dir(dir_path):
        if not file_path.isprintable():
            file_path = "".join(c if c.isprintable() else "*" for c in file_path)
        if " " in file_path:
            file_path = file_path.replace(" ", "*")
        if fs_file.get(file_path):
            new_fs[file_path] = fs_file[file_path]
        else:
            if r_fs.get(file_path):
                continue
            file_path = os.path.abspath(file_path)
            if os.path.isdir(file_path):
                uid = "0"
                gid = "0"
                mode = "0755"  # dir path always 755
                config = [uid, gid, mode]
            elif not os.path.exists(file_path):
                config = ["0", "0", "0755"]
            elif islink(file_path):
                uid = "0"
                gid = "0"
                mode = "0755"
                link = islink(file_path)
                config = [uid, gid, mode, link]
            elif "/bin" in file_path or "/xbin" in file_path:
                uid = "0"
                gid = "0"
                mode = "0755"
                if ".sh" in file_path:
                    mode = "0750"
                config = [uid, gid, mode]
            else:
                uid = "0"
                gid = "0"
                mode = "0644"
                config = [uid, gid, mode]
            print(f"Add [{file_path}{config}]")
            r_fs[file_path] = 1
            new_add += 1
            new_fs[file_path] = config
    return new_fs, new_add


def main(dir_path: str, fs_config: str):
    fs_file = scanfs(fs_config)
    new_fs, new_add = fs_patch(fs_file, dir_path)
    with open(fs_config, "w", encoding="utf-8", newline="\n") as f:
        for filepath, config in sorted(new_fs.items()):
            f.write(f"{filepath} {
