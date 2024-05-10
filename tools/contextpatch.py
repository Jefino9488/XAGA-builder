#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
import os
from collections import defaultdict
from difflib import SequenceMatcher
from re import escape, match
from typing import Dict, Generator, Any, List, Union, DefaultDict, cast
from pathlib import Path
import sys
from contextlib import ExitStack

FixPermission = Dict[str, str]
Context = Dict[str, List[str]]

fix_permission: FixPermission = {
    r"/system_ext/lost\+found": "u:object_r:system_file:s0",
    r"/product/lost\+found": "u:object_r:system_file:s0",
    r"/mi_ext/lost\+found": "u:object_r:system_file:s0",
    r"/odm/lost\+found": "u:object_r:vendor_file:s0",
    r"/vendor/lost\+found": "u:object_r:vendor_file:s0",
    r"/vendor_dlkm/lost\+found": "u:object_r:vendor_file:s0",
    r"/system/lost\+found": "u:object_r:rootfs:s0",
    r"/lost\+found": "u:object_r:rootfs:s0",
    "/mi_ext/product/lib*": "u:object_r:system_lib_file:s0",
    "/system/system/app/*": "u:object_r:system_file:s0",
    "/system/system/priv-app/*": "u:object_r:system_file:s0",
    "/system/system/lib*": "u:object_r:system_lib_file:s0",
    "/system/system/bin/apexd": "u:object_r:apexd_exec:s0",
    "/system/system/bin/init": "u:object_r:init_exec:s0",
    "system_ext/lib*": "u:object_r:system_lib_file:s0",
    "/product/lib*": "u:object_r:system_lib_file:s0",
    "/odm/app/*": "u:object_r:vendor_app_file:s0",
    "/odm/app/": "u:object_r:vendor_app_file:s0",
    "/odm/etc*": "u:object_r:vendor_configs_file:s0",
    "/vendor/apex*": "u:object_r:vendor_apex_file:s0",
    "/vendor/app/*": "u:object_r:vendor_app_file:s0",
    "/vendor/priv-app/*": "u:object_r:vendor_app_file:s0",
    "/vendor/etc*": "u:object_r:vendor_configs_file:s0",
    "/vendor/firmware*": "u:object_r:vendor_firmware_file:s0",
    "/vendor/framework*": "u:object_r:vendor_framework_file:s0",
    "*/hw/android.hardware.audio*": "u:object_r:hal_audio_default_exec:s0",
    "*/hw/android.hardware.bluetooth*": "u:object_r:hal_bluetooth_default_exec:s0",
    "*/hw/android.hardware.boot*": "u:object_r:hal_bootctl_default_exec:s0",
    "*/hw/android.hardware.power*": "u:object_r:hal_power_default_exec:s0",
    "*/hw/android.hardware.wifi*": "u:object_r:hal_wifi_default_exec:s0",
    "*/bin/idmap": "u:object_r:idmap_exec:s0",
    "*/bin/fsck": "u:object_r:fsck_exec:s0",
    "*/bin/e2fsck": "u:object_r:fsck_exec:s0",
    "*/bin/logcat": "u:object_r:logcat_exec:s0",
    "*/bin/audioserver": "u:object_r:audioserver_exec:s0",
}


def scan_context(file: Path) -> Context:  # 读取context文件返回一个字典
    context: Context = {}
    with file.open("r", encoding="utf-8") as file_:
        for i in file_:
            filepath, *other = i.strip().split()
            filepath = filepath.replace(r"\@", "@")
            context[filepath] = other
            if len(other) > 1:
                logging.warning(f"[Warn] {i[0]} has too much data.Skip.")
                del context[filepath]
    return context


def scan_dir(folder: Path) -> Generator[Union[str, None], Any, Any]:  # 读取解包的目录，返回一个生成器
    part_name = folder.name
    allfiles = [
        "/",
        "/lost+found",
        f"/{part_name}",
        f"/{part_name}/",
        f"/{part_name}/lost+found",
    ]
    with ExitStack() as stack:
        folder = stack.enter_context(folder.resolve())
        for root, dirs, files in os.walk(folder, topdown=True):
            for dir_ in dirs:
                yield os.path.join(root, dir_).replace(folder, "/" + part_name).replace(
                    "\\", "/"
                )
            for file in files:
                yield os.path.join(root, file).replace(folder, "/" + part_name).replace(
                    "\\", "/"
                )
            for rv in allfiles:
                yield rv
    yield None


def str_to_selinux(string: str):
    return escape(string).replace("\\-", "-")


def context_patch(
    fs_file: Context, dir_path: Path
) -> tuple[Context, int]:  # 接收两个字典对比
    new_fs: Context = {}
    r_new_fs: Context = {}
    add_new = 0

    logging.info("ContextPatcher: Load origin %d" % (len(fs_file.keys())) + " entries")

    permission_d = {
        "system_dlkm": ["u:object_r:system_dlkm_file:s0"],
        "odm": ["u:object_r:vendor_file:s0"],
        "vendor": ["u:object_r:vendor_file:s0"],
        "vendor_dlkm": ["u:object_r:vendor_file:s0"],
    }.get(os.path.basename(dir_path), ["u:object_r:system_file:s0"])

    for i in scan_dir(dir_path):
        if i is None:
            continue

        if not i.isprintable():
            tmp = ""
            for c in i:
                tmp += c if c.isprintable() else "*"
            i = tmp

        if " " in i:
            i = i.replace(" ", "*")

        i = str_to_selinux(i)

        if fs_file.get(i):
            new_fs[i] = fs_file[i]
        else:
            permission = None

            if r_new_fs.get(i):
                continue

            if i:
                for f in fix_permission.keys():
                    pattern = f.replace("*", ".*")
                    if i == pattern:
                        permission = [fix_permission[f]]
                        break
                    if match(pattern, i):
                        permission = [fix_permission[f]]
                        break

                if not permission:
                    for e in fs_file.keys():
                        if (
                            SequenceMatcher(
                                None, (path := os.path.dirname(i)), e
                            ).quick_ratio()
                            >= 0.8
                        ):
                            if e == path:
                                continue
                            permission = fs_file[e]
                            break
                        else:
                            permission = permission_d

            if " " in permission:
                permission = permission.replace(" ", "")

            logging.info(f"Add {i} {permission}")
            add_new += 1
            r_new_fs[i] = permission
            new_fs[i] = permission
    return new_fs, add_new


def main(dir_path: Path, fs_config: Path) -> None:
    new_fs, add_new = context_patch(scan_context(fs_config), dir_path)
    with fs_config.open("w+", encoding="utf-8", newline="\n") as f:
        f.writelines(
            [i + " " + " ".join(new_fs[i]) + "\n" for i in sorted(new_fs.keys())]
        )
    logging.info("ContextPatcher: Add %d" % add_new + " entries")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Auto patch file_context")
    parser.add_argument("folder", help="The folder to scan")
    parser.add_argument("fs_config", help="The fs_config file")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_arguments()
    logging.basicConfig(level=logging.INFO)
    main(Path(args.folder), Path(args.fs_config))
    print("Done!")
