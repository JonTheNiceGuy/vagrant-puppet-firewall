#!/usr/bin/env python3
import re
import sys
import logging
import pathlib
import argparse
import subprocess

logging.basicConfig(level=logging.DEBUG)


class ArgumentException(Exception):
    pass


class ProfileNotFound(Exception):
    pass


class NmcliFailed(Exception):
    pass


class nm_profile:
    file = None
    settings = {}

    def __init__(self, search_string: str):
        if search_string is None:
            raise ArgumentException('Invalid Search String')
        search = re.compile(f'^([^=]+)=(.*)\s*$')
        nm_dir = pathlib.Path("/run/NetworkManager/system-connections")
        for file_path in nm_dir.glob("*.nmconnection"):
            if file_path == search_string:
                self.file = file_path
            else:
                with open(file_path, "r") as f:
                    lines = f.readlines()
                    for line in lines:
                        compare = search.match(line)
                        if compare and compare.group(2) == search_string:
                            self.file = file_path
                            break
            if self.file is not None:
                break
        if self.file is None:
            nm_dir = pathlib.Path("/etc/NetworkManager/system-connections")
            for file_path in nm_dir.glob("*.nmconnection"):
                if file_path == search_string:
                    self.file = file_path
                else:
                    with open(file_path, "r") as f:
                        lines = f.readlines()
                        for line in lines:
                            compare = search.match(line)
                            if compare and compare.group(2) == search_string:
                                self.file = file_path
                                break
                if self.file is not None:
                    break
        if self.file is None:
            raise ProfileNotFound(
                f'Unable to find a profile matching the search string "{search_string}"')

        nmcli = subprocess.run(
            ["/bin/nmcli", "--terse", "connection", "show", self.file],
            capture_output=True, text=True
        )
        for line in nmcli.stdout.splitlines():
            data = line.split(":", 1)
            value = data[1].strip()
            if value == '':
                value = None
            self.settings[data[0].strip()] = value


def main():
    parser = argparse.ArgumentParser(
        description="Modify NetworkManager connection settings.")
    parser.add_argument("ifname", help="Interface name")
    parser.add_argument("ip", help="IP address or 'auto'")
    parser.add_argument("--dryrun", action="store_true",
                        help="Enable dry run mode")
    parser.add_argument("--test", action="store_true",
                        help="Enable test mode")
    args = parser.parse_args()

    actions = {}

    nm = nm_profile(args.ifname)

    current_id = nm.settings.get("connection.id")
    next_id = args.ifname
    if current_id != next_id:
        logging.debug(f'Change id from "{current_id}" to "{next_id}"')
        actions['connection.id'] = next_id

    current_method = nm.settings.get("ipv4.method")
    next_method = "manual" if args.ip != "auto" else "auto"

    if current_method != next_method:
        logging.debug(f'Change method from {current_method} to {next_method}')
        actions['ipv4.method'] = next_method

    current_ip = nm.settings.get("ipv4.addresses")
    next_ip = args.ip if args.ip != "auto" else None
    if next_ip is None and current_ip is not None:
        logging.debug(f'Change ipv4.address from {current_ip} to ""')
        actions['ipv4.addresses'] = ""
    elif next_ip != current_ip:
        logging.debug(
            f'Change ipv4.address from {current_ip if not None else "None"} to {next_ip}')
        actions['ipv4.addresses'] = next_ip

    if len(actions) > 0:
        if args.test:
            logging.debug('There are outstanding actions, exit rc 1')
            sys.exit(1)

        command = [
            '/bin/nmcli', 'connection', 'modify', 
            nm.settings.get('connection.uuid', str(nm.file))
        ]

        for action in actions.keys():
            command.append(action)
            command.append(actions[action])
        logging.info(f'About to run the following command: {command}')

        if not args.dryrun:
            nmcli = subprocess.run(
                command,
                capture_output=True, text=True
            )
            if nmcli.returncode > 0:
                raise NmcliFailed(
                    f'Failed to run command {command}, RC: {nmcli.returncode} StdErr: {nmcli.stderr} StdOut: {nmcli.stdout}')

        command = [
            '/bin/nmcli', 'connection', 'down', nm.settings.get(
                'connection.uuid', str(nm.file))
        ]
        logging.info(f'About to run the following command: {command}')

        if not args.dryrun:
            nmcli = subprocess.run(
                command,
                capture_output=True, text=True
            )
            if nmcli.returncode > 0:
                raise NmcliFailed(
                    f'Failed to run command {command}, RC: {nmcli.returncode} StdErr: {nmcli.stderr} StdOut: {nmcli.stdout}')

            command = [
                '/bin/nmcli', 'connection', 'up', nm.settings.get(
                    'connection.uuid', str(nm.file))
            ]
            logging.info(f'About to run the following command: {command}')
            nmcli = subprocess.run(
                command,
                capture_output=True, text=True
            )
            if nmcli.returncode > 0:
                raise NmcliFailed(
                    f'Failed to run command {command}, RC: {nmcli.returncode} StdErr: {nmcli.stderr} StdOut: {nmcli.stdout}')

    if args.test:
        logging.debug('There are no outstanding actions, exit rc 0')

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logging.error(e)
        sys.exit(1)
