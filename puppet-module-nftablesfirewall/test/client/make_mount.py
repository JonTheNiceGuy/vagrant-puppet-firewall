#!/usr/bin/env python3
import os
import re
import logging
import subprocess

logging.basicConfig(level=logging.DEBUG if os.environ.get('DEBUG', '0') != '0' else logging.INFO)

with open('/proc/mounts', 'r') as f:
  mounts = [line.strip() for line in f.readlines()]

regex_match = r'^(.*) (/.*) nfs (.*) \d+ \d+'

for mount in mounts:
  if mount.startswith('192.168.56.1'):
    mount_match = re.match(regex_match, mount)
    if mount_match:
      source = mount_match.group(1)
      destination = mount_match.group(2)
      options = mount_match.group(3)

      systemd_destination = subprocess.run(["/bin/systemd-escape", "--path", destination], capture_output=True).stdout.strip().decode()
      systemd_unit = f'/etc/systemd/system/{systemd_destination}.mount'
      if os.path.exists(systemd_unit):
        logging.debug(f'Systemd Mount found at {systemd_destination}.mount')
      else:
        logging.debug(f'Systemd Mount not found. Creating {systemd_destination}.mount')
        lines=[]
        lines.append( '[Unit]')
        lines.append( 'After=network.target')
        lines.append( '')
        lines.append( '[Mount]')
        lines.append(f'What={source}')
        lines.append(f'Where={destination}')
        lines.append( 'Type=nfs')
        lines.append(f'Options={options}')
        lines.append( '')
        lines.append( '[Install]')
        lines.append( 'WantedBy=multi-user.target')
        lines.append( '')
        with open(systemd_unit, 'w') as f:
          f.write('\n'.join(lines))
        logging.debug('Created unit file.')
        subprocess.run(['/bin/systemctl', 'enable', f'{systemd_destination}.mount'])
        logging.debug('Enabled unit')
