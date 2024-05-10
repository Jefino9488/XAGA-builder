#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from difflib import SequenceMatcher
from re import escape, match
from typing import Dict, Generator, Any, List, Union

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


def scan_context(file: str) -> Context:  # 读取context文件返回一个字典
    context: Context = {}
    with open(file, "r", encoding="utf-8") as file_:
        for i in file_.readlines():
            filepath, *other = i.strip().split()
            filepath = filepath.replace(r"\@", "@")
            context[filepath] = other
            if len(other) > 1:
                print(f"[Warn] {i[0]} has too much data.Skip.")
                del context[filepath]
    return context


def scan_dir(folder: str) -> Generator[Union[str, None], Any, Any]:  # 读取解包的目录，返回一个生成器
    part_name = os.path.basename(folder)
    allfiles = [
        "/",
        "/lost+found",
        f"/{part_name}",
        f"/{part_name}/",
        f"/{part_name}/lost+found",
    ]
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


def context_patch(fs_file: Context, dir_path: str) -> tuple[Context, int]:  # 接收两个字典对比
    new_fs: Context = {}
    r_new_fs: Context = {}
    add_new = 0

    print("ContextPatcher: Load origin %d" % (len(fs_file.keys())) + " entries")

    permission_d = {
        "system_dlkm": ["u:object_r:system_dlkm_file:s0"],
        "odm": ["u:object_r:vendor_file:s0"],
        "vendor": ["u:object_r:vendor_file:s0"],
        "vendor_dlkm": ["u:object_r:vendor_file:s0"],
    }.get(os.path.basename(dir_path), ["u:object_r:system_file:s0"])

    for i in scan_dir(os.path.abspath(dir_path)):
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

            print(f"Add {i} {permission}")
            add_new += 1
            r_new_fs[i] = permission
            new_fs[i] = permission
    return new_fs, add_new


def main(dir_path: str, fs_config: str) -> None:
    new_fs, add_new = context_patch(scan_context(os.path.abspath(fs_config)), dir_path)
    with open(fs_config, "w+", encoding="utf-8", newline="\n") as f:
        f.writelines(
            [i + " " + " ".join(new_fs[i]) + "\n" for i in sorted(new_fs.keys())]
        )
    print("ContextPatcher: Add %d" % add_new + " entries")


def Usage():
    print("Usage:")
    print("%s <folder> <fs_config>" % (sys.argv[0]))
    print("    This script will auto patch file_context")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        Usage()
        sys.exit()
    if os.path.isdir(sys.argv[1]) or os.path.isfile(sys.argv[2]):
        main(sys.argv[1], sys.argv[2])
        print("Done!")
    else:
        print(
            "The path or filetype you have given may wrong, please check it wether correct."
        )
        Usage()
