#!/usr/bin/python3
import logging
from pyroute2 import IPRoute, NDB
from pyroute2.netlink.rtnl import RTMGRP_LINK
import socket
import re
import sys
import subprocess
import json
import requests
import traceback


def cmd(cmd_str):
    try:
        result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
    except Exception as exc:
        return str(str)
    return result.stdout.strip()

def tc_apply(intf1, intf2):
    logging.info(f"apply TC to intf {intf1} -> {intf2}")
    return (
        cmd(f"tc qdisc add dev {intf1} ingress")
        + cmd(f"tc filter add dev {intf1} parent ffff: protocol all u32 match u8 0 0 action mirred egress redirect dev {intf2}")
   )

def is_tc_applied(intf1, intf2):
    return f"to device {intf2}" in cmd(f"tc filter show dev {intf1} ingress | grep -w 'mirred.*to device {intf2}'")

def tc_clear(intf1, intf2):
    logging.info(f"TC clear on intfs {intf1} and {intf2}")
    cmd(f"tc filter del dev {intf1} ingress")
    cmd(f"tc filter del dev {intf2} ingress")


logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

logging.info("Starting monitor ports")

# Subscribe to netlink broadcast groups (RTMGRP_LINK)
ipr = IPRoute()
ipr.bind(groups=RTMGRP_LINK)

try:
    ports = json.load(open(sys.argv[1]))
except:
    print(f"USAGE: {sys.argv[0]} <PORTS-FILE>")
    sys.exit(0)

veth_to_p4 = {}
for info in ports.get("PortToVeth", []):
    veth_to_p4[f"veth{info['veth2']}"] = info["device_port"]

hostname = socket.gethostname()
if_fmt = f"{hostname}-eth"
if_fmt_len = len(if_fmt)

intfs = {}

for link in ipr.get_links():
    ifname = link.get_attr('IFLA_IFNAME')
    operstate = link.get_attr('IFLA_OPERSTATE')
    if operstate != "UP":
        operstate = "DOWN"
    intfs[ifname] = operstate

logging.info(f"Existing interfaces {intfs=}")

for intf in intfs:
    if not intf.startswith(if_fmt):
        continue
    veth = "veth" + intf[if_fmt_len:]
    if veth in veth_to_p4:
        # TODO update dataplane state
        dev_port = veth_to_p4[veth]
        if not is_tc_applied(intf, veth):
            tc_apply(intf, veth)
        if not is_tc_applied(veth, intf):
            tc_apply(veth, intf)

logging.info("Monitoring link events... (Ctrl+C to stop)")

while True:
    for message in ipr.get():
        event = message['event']
        attrs = dict(message['attrs'])
        ifname = attrs.get('IFLA_IFNAME')
        if not ifname.startswith(if_fmt):
            logging.info(f"Ignoring interface not of interest {ifname}")
            continue
        veth = "veth" + ifname[if_fmt_len:]
        #logging.info(f"DEBUG {event=} {ifname=} {attrs=}")
        if event == 'RTM_NEWLINK':
            # RTM_NEWLINK covers both new interfaces and state changes (up/down)
            state = attrs.get('IFLA_OPERSTATE')
            bf_cmd = "pal.port_enable(dev_port=%s)"
            if state != "UP":
                bf_cmd = "pal.port_dis(dev_port=%s)"
                state = "DOWN"
            if ifname in intfs:
                if intfs[ifname] != state:
                    logging.info(f"Interface state changed {ifname} | state {intfs[ifname]} -> {state}")
                    try:
                        res = requests.post("http://127.0.0.1:3000/run", json={"cmd": bf_cmd % (veth_to_p4[veth])}, timeout=10)
                        assert res.status_code == 200, res.text
                        logging.info(f"Port status updated in BF via Thritf PAL API {ifname} {state}")
                    except Exception as exc:
                        err = traceback.format_exc().replace("\n", ", ")
                        logging.error(f"Failed to update port status in BF via Thritf PAL API {ifname} {state}: {exc} {err}")
            else:
                logging.info(f"Interface created {ifname} | State: {state}")
                tc_apply(ifname, veth)
                tc_apply(veth, ifname)
                try:
                    res = requests.post("http://127.0.0.1:3000/run", json={"cmd": bf_cmd % (veth_to_p4[veth])}, timeout=10)
                    assert res.status_code == 200, res.text
                    logging.info(f"Port status updated in BF via Thritf PAL API {ifname} {state}")
                except Exception as exc:
                    err = traceback.format_exc().replace("\n", ", ")
                    logging.error(f"Failed to update port status in BF via Thritf PAL API {ifname} {state}: {exc} {err}")
            intfs[ifname] = state
        elif event == 'RTM_DELLINK':
            logging.info(f"Link {ifname} deleted.")
            tc_clear(ifname, veth)
            del intfs[ifname]
