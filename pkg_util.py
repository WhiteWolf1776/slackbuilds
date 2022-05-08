#!/usr/bin/env python3
#
# Copyright (C) 2022 Nick Blizzard
"""utility class to check versions"""
__author__ = "Nick Blizzard"
__copyright__ = "Copyright (C) 2022 Nick Blizzard"
from dataclasses import dataclass
import requests

@dataclass
class Package:
    """basic metadata for a package"""
    name: str
    version: str

def get_pkg_list():
    """create and return a list of packages to process"""
    pkg_list = []
    pkg_list.append(Package("qemu",get_qemu_latest_version()))
    pkg_list.append(Package("nvidia-driver",get_nvidia_latest_version()))
    pkg_list.append(Package("nvidia-kernel",get_nvidia_latest_version()))
    pkg_list.append(Package("brave-browser",get_brave_latest_ver()))
    pkg_list.append(Package("vscode-bin",get_vscode_latest_ver()))
    pkg_list.append(Package("teams",get_teams_latest_ver()))
    pkg_list.append(Package("zenity",get_zenity_latest_ver()))
    pkg_list.append(Package("steam",get_steam_latest_version()))
    pkg_list.append(Package("signal-desktop",get_signal_latest_version()))
    return pkg_list

def get_brave_latest_ver():
    """find and return the lastest version of brave-browser"""
    ver_pg = requests.get("http://brave.com/latest",headers={'User-Agent':'Slackware-Linux'})
    ver_str = ""
    for line in ver_pg.iter_lines():
        line_str = line.decode("utf-8")
        if "release-notes-" in line_str:
            start_char = line_str.find("V") + 1
            for char in line_str[start_char:]:
                if char != "<":
                    ver_str = ver_str + str(char)
                else:
                    break
            return ver_str

def get_vscode_latest_ver():
    """get latest version"""
    ver_url = "https://code.visualstudio.com/sha/download?build=stable&os=linux-x64"
    data = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    filename = data.headers['content-disposition']
    return str(filename.removesuffix('.tar.gz"').split('-')[-1])

def get_teams_latest_ver():
    """get latest version"""
    ver_url = "https://go.microsoft.com/fwlink/p/?LinkID=2112886&clcid=0x409&culture=en-us&country=US"
    data = requests.get(ver_url,allow_redirects=True,headers={'User-Agent':'Slackware-Linux'})
    filename = data.request.url.split("/")[-1]
    version = filename.split("_")[1]
    return version

def get_zenity_latest_ver():
    """get latest version"""
    ver_url = "https://www.linuxfromscratch.org/blfs/view/svn/gnome/zenity.html"
    ver_pg = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    for line in ver_pg.iter_lines():
        line_str = line.decode("utf-8")
        if "Zenity-" in line_str:
            return line_str.split("-")[1]

def get_steam_latest_version():
    """get latest version"""
    ver_url = "https://repo.steampowered.com/steam/archive/precise/steam_latest-stable.dsc"
    ver_pg = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    for line in ver_pg.iter_lines():
        line_str = line.decode("utf-8")
        if "Version:" in line_str:
            return line_str.split(":")[2]

def get_signal_latest_version():
    """get latest version"""
    ver_url = "https://github.com/signalapp/Signal-Desktop"
    ver_pg = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    for line in ver_pg.iter_lines():
        line_str = line.decode("utf-8")
        if 'title="Label: Latest"' in line_str:
            return last_line_str.split("<")[-2].split(">")[-1].replace("v","")
        last_line_str = line_str

def get_nvidia_latest_version():
    """get latest version"""
    ver_url = "https://download.nvidia.com/XFree86/Linux-x86_64/latest.txt"
    ver_pg = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    return ver_pg.content.decode("utf-8").split(" ")[0]

def get_qemu_latest_version():
    """get latest version"""
    ver_url = "https://www.qemu.org/download/"
    ver_pg = requests.get(ver_url,headers={'User-Agent':'Slackware-Linux'})
    for line in ver_pg.iter_lines():
        line_str = line.decode("utf-8")
        if 'href="https://download.qemu.org/qemu-' in line_str:
            return line_str.split(">")[1].split("<")[0]
