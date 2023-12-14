#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
from re import sub

fix_permission = {"/vendor/bin/hw/android.hardware.wifi@1.0": "u:object_r:hal_wifi_default_exec:s0"}


def scan_context(file) -> dict:  # 读取context文件返回一个字典
    context = {}
    with open(file, "r", encoding='utf-8') as file_:
        for i in file_.readlines():
            filepath, *other = i.strip().replace('\\', '').split()
            context[filepath] = other
            if len(other) > 1:
                print(f"[Warn] {i[0]} has too much data.")
    return context


def scan_dir(folder) -> list:  # 读取解包的目录，返回一个字典
    part_name = os.path.basename(folder)
    allfiles = ['/', '/lost+found', f'/{part_name}/lost+found', f'/{part_name}', f'/{part_name}/']
    for root, dirs, files in os.walk(folder, topdown=True):
        for dir_ in dirs:
            if os.name == 'nt':
                allfiles.append(os.path.join(root, dir_).replace(folder, '/' + part_name).replace('\\', '/'))
            elif os.name == 'posix':
                allfiles.append(os.path.join(root, dir_).replace(folder, '/' + part_name))
        for file in files:
            if os.name == 'nt':
                allfiles.append(os.path.join(root, file).replace(folder, '/' + part_name).replace('\\', '/'))
            elif os.name == 'posix':
                allfiles.append(os.path.join(root, file).replace(folder, '/' + part_name))
    return sorted(set(allfiles), key=allfiles.index)


def context_patch(fs_file, filename) -> dict:  # 接收两个字典对比
    new_fs = {}
    r_new_fs = {}
    permission_d = None
    try:
        permission_d = fs_file.get(list(fs_file)[5])
    except IndexError:
        pass
    if not permission_d:
        permission_d = ['u:object_r:system_file:s0']
    for i in filename:
        if fs_file.get(i):
            new_fs[sub(r'([^-_/a-zA-Z0-9])', r'\\\1', i)] = fs_file[i]
        else:
            permission = permission_d
            if i:
                if i in fix_permission.keys():
                    permission = fix_permission[i]
                else:
                    d_arg = True
                    for e in fs_file.keys():
                        if (path := os.path.dirname(i)) in e:
                            if e == path and e[-1:] == '/':
                                continue
                            permission = fs_file[e]
                            d_arg = False
                            break
                    if d_arg:
                        for i_ in r_new_fs.keys():
                            if (path := os.path.dirname(i)) in i_:
                                if i_ == path and i_[-1:] == '/':
                                    continue
                                try:
                                    permission = r_new_fs[i]
                                except KeyError:
                                    pass
                                break
            print(f"ADD [{i} {permission}]")
            r_new_fs[i] = permission
            new_fs[sub(r'([^-_/a-zA-Z0-9])', r'\\\1', i)] = permission
    return new_fs


def main(dir_path, fs_config) -> None:
    origin = scan_context(os.path.abspath(fs_config))
    allfiles = scan_dir(os.path.abspath(dir_path))
    new_fs = context_patch(origin, allfiles)
    with open(fs_config, "w+", encoding='utf-8', newline='\n') as f:
        f.writelines([i + " " + " ".join(new_fs[i]) + "\n" for i in sorted(new_fs.keys())])
    print("Load origin %d" % (len(origin.keys())) + " entries")
    print("Detect total %d" % (len(allfiles)) + " entries")
    print('Add %d' % (len(new_fs.keys()) - len(origin.keys())) + " entries")

def Usage():
    print("Usage:")
    print("%s <folder> <fs_config>" % (sys.argv[0]))
    print("    This script will auto patch file_context")


if __name__ == '__main__':
    import sys

    if len(sys.argv) < 3:
        Usage()
        sys.exit()
    if os.path.isdir(sys.argv[1]) or os.path.isfile(sys.argv[2]):
        main(sys.argv[1], sys.argv[2])
        print("Done!")
    else:
        print("The path or filetype you have given may wrong, please check it wether correct.")
        Usage()
