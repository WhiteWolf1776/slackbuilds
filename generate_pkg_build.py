#!/usr/bin/env python3
#
# Copyright (C) 2022 Nick Blizzard
"""process and prep for updates as needed"""
__author__ = "Nick Blizzard"
__copyright__ = "Copyright (C) 2022 Nick Blizzard"
import os
from pathlib import Path
import argparse
import shutil
import hashlib
import re
import json
import requests
import notify2
from pkg_util import get_pkg_list

def main():
    """main loop"""
    cfg = None
    with open("pkg_build.cfg",'r',encoding="utf-8") as cfg_file:
        cfg = json.load(cfg_file)
    build_dir = cfg['build_dir']

    Path(build_dir).mkdir(parents=True, exist_ok=True)

    args = create_argparse()

    changes = []
    for pkg in get_pkg_list(args):
        changes.append(create_build(pkg.name,pkg.version,build_dir))

    notify_msg = []
    for change in changes:
        if change:
            notify_msg.append(change)

    if notify_msg:
        notify2.init('slackware unsupported update check')

        note = notify2.Notification("Updates Found",
                                    "\n".join(notify_msg),
                                    "notification-message-im"
                                    )
        note.set_timeout(notify2.EXPIRES_NEVER)
        note.show()

def create_argparse():
    """parse out command line arguments"""
    parser = argparse.ArgumentParser(description='generate slackware build scripts')
    parser.add_argument('--pkg_list',help='comma seperated list of packages')
    parser.add_argument('--ver_list',help='comma seperated list of versions')
    args = parser.parse_args()
    return args


def create_build(pkg,ver,build_dir):
    """create a build folder for processing"""
    build = f"{pkg}-{ver}"
    if build not in get_folder_names(build_dir):
        shutil.copytree(f"unsupported-pkgs/{pkg}",f"{build_dir}/{build}")
        info_text = ""
        with open(f"{build_dir}/{build}/{pkg}.info",'r',encoding="utf-8") as info:
            info_text = info.read()
            info_text = info_text.replace("$VERSION",ver)

        download_line = info_text.find("DOWNLOAD=")

        download_urls = list(info_text[download_line:].split('"')[1].replace("\\","").split("\n"))
        md_hash = ""
        for download_url in download_urls:
            data = requests.get(download_url.strip(),
                                allow_redirects=True,
                                headers={'User-Agent':'Slackware-Linux'})
            bin_name = get_filename(data,data.request.url)
            with open(f"{build_dir}/{build}/{bin_name}",'wb') as file:
                file.write(data.content)
            if md_hash != "":
                md_hash = f"{md_hash} \\ \n        "
            md_hash = md_hash + hashlib.md5(data.content).hexdigest()
        info_text = info_text.replace('MD5SUM=""',f'MD5SUM="{md_hash}"')
        with open(f"{build_dir}/{build}/{pkg}.info",'w',encoding="utf-8") as info:
            info.write(info_text)
        return build

def get_filename(data,url):
    """get the filename from a url or data stream"""
    if "Content-Disposition" in data.headers.keys():
        return re.findall("filename=(.+)", data.headers["Content-Disposition"])[0].replace('"','')
    return url.split("/")[-1]

def get_folder_names(relative_path):
    """get list of folders"""
    folder_list = [elem.name for elem in os.scandir(relative_path) if elem.is_dir()]
    return folder_list

if __name__ == "__main__":
    main()
