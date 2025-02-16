# @Summary
class nftablesfirewall::interfaces (
  String  $network_base   = '198.18',
  Integer $prod_base      = 32, # Start of Supernet
  Integer $prod_mask      = 24,
  Integer $dev_base       = 64, # Start of Supernet
  Integer $dev_mask       = 24,
  Integer $shared_base    = 96, # Start of Supernet
  Integer $shared_mask    = 24,
  Integer $transit_actual = 255,
  Integer $transit_mask   = 24,
) {
  if ($facts['networking']['interfaces']['eth0']) {
    #################################################################
    ######## Using the MAC address we've configured, define each
    ######## network interface. On cloud platforms, we'd need to
    ######## figure out a better way of doing this!
    #################################################################
    # This relies HEAVILY on the mac address for the device on eth0 
    # following this format:       16:0D:EC:AF:xx:01
    # The first 8 hex digits (160DECAF) don't really matter, but the
    # 9th and 10th are the VM number and the 11th and 12 are the 
    # interface ID. This MAC prefix I found is a purposefully 
    # unallocated prefix for virtual machines.
    #
    # Puppet magic to turn desired interface names etc into MAC
    # addresses, thanks to ChatGPT.
    #
    # https://chatgpt.com/share/67ae1617-a398-8002-807b-4bc4298b40bb
    $interface_map = {
      'wan'     => '01',
      'prod'    => '02',
      'dev'     => '03',
      'shared'  => '04',
      'transit' => '05',
    }
    $interfaces = $interface_map.map |$role, $suffix| {
      $match = $facts['networking']['interfaces'].filter |$iface, $details| {
        $details['mac'] and $details['mac'] =~ "${suffix}$"
      }

      if !empty($match) {
        { $role => $match.values()[0]['mac'] }  # Store the MAC address
      } else {
        {}
      }
    }.reduce |$acc, $entry| {
      $acc + $entry  # Merge all key-value pairs into a final hash
    }

    file { '/etc/udev/rules.d/70-persistent-net.rules':
      ensure  => present,
      owner   => root,
      group   => root,
      mode    => '0644',
      content => template('nftablesfirewall/etc/udev/rules.d/70-persistent-net.rules.erb'),
      notify  => Exec['Reboot'],
    } -> exec { 'Reboot':
      command     => '/bin/bash -c "(sleep 30 && reboot) &"',
      # We delay 30 seconds so the reboot doesn't kill puppet and report an error.
      refreshonly => true
    }
  } else {
    #################################################################
    ######## Once the network interfaces are renamed and the host
    ######## rebooted, we can now start applying IP addresses to the
    ######## Network interfaces.
    #################################################################
    # This block here works out which host we are, based on the 5th
    # octet of the MAC address
    #################################################################
    $vm_offset = Integer(
      regsubst(
        $facts['networking']['interfaces']['wan']['mac'],
        '.*:([0-9A-Fa-f]{2}):[0-9A-Fa-f]{2}$',
        '\1'
      )
    )

    #################################################################
    # Next calculate the IP addresses to assign to each NIC
    #################################################################
    $transit_ip    = "${network_base}.${transit_actual}.${vm_offset}/${transit_mask}"
    $dev_actual    = $dev_base + $vm_offset
    $dev_ip        = "${network_base}.${dev_actual}.1/${dev_mask}"
    $prod_actual   = $prod_base + $vm_offset
    $prod_ip       = "${network_base}.${prod_actual}.1/${dev_mask}"
    $shared_actual = $shared_base + $vm_offset
    $shared_ip     = "${network_base}.${shared_actual}.1/${dev_mask}"

    #################################################################
    # This script applies and activates network changes to Network
    # Manager to keep the amount of lines of exec in here to a
    # minimum. It also has a test flag that can be used to identify
    # if the NIC actually needs changing, to reduce noise from 
    # puppet.
    #
    # Install the script and then run it for each interface.
    #################################################################
    file { '/usr/local/sbin/configure_nm_if.py':
      owner  => root,
      group  => root,
      mode   => '0755',
      source => 'puppet:///modules/nftablesfirewall/usr/local/sbin/configure_nm_if.py',
    }
    exec { 'Configure WAN Interface': # wan interface uses DHCP, so set to auto
      require => File['/usr/local/sbin/configure_nm_if.py'],
      command => '/usr/local/sbin/configure_nm_if.py wan auto',
      unless  => '/usr/local/sbin/configure_nm_if.py wan auto --test',
      notify  => Exec['Reboot'],
    }
    exec { 'Configure Dev Interface':
      require => File['/usr/local/sbin/configure_nm_if.py'],
      command => "/usr/local/sbin/configure_nm_if.py dev ${dev_ip}",
      unless  => "/usr/local/sbin/configure_nm_if.py dev ${dev_ip} --test",
      notify  => Exec['Reboot'],
    }
    exec { 'Configure Prod Interface':
      require => File['/usr/local/sbin/configure_nm_if.py'],
      command => "/usr/local/sbin/configure_nm_if.py prod ${prod_ip}",
      unless  => "/usr/local/sbin/configure_nm_if.py prod ${prod_ip} --test",
      notify  => Exec['Reboot'],
    }
    exec { 'Configure Shared Interface':
      require => File['/usr/local/sbin/configure_nm_if.py'],
      command => "/usr/local/sbin/configure_nm_if.py shared ${shared_ip}",
      unless  => "/usr/local/sbin/configure_nm_if.py shared ${shared_ip} --test",
      notify  => Exec['Reboot'],
    }
    exec { 'Configure Transit Interface':
      require => File['/usr/local/sbin/configure_nm_if.py'],
      command => "/usr/local/sbin/configure_nm_if.py transit ${transit_ip}",
      unless  => "/usr/local/sbin/configure_nm_if.py transit ${transit_ip} --test",
      notify  => Exec['Reboot'],
    }

    #################################################################
    # Remove any unused Network Manager connections
    #################################################################
    $con = '/bin/nmcli connection'
    $conshow = '/bin/nmcli --terse --fields UUID,ACTIVE,DEVICE connection show'
    exec { 'Prune all unused nmcli connections':
      command => "${con} delete $(${conshow} | grep ':no:' | cut -d: -f1)",
      unless  => "/bin/test $(${conshow} | grep ':no:' | wc -l) -eq 0",
      notify  => Exec['Reboot'],
    }

    exec { 'Reboot':
      command     => '/bin/bash -c "(sleep 30 && reboot) &"',
      # We delay 30 seconds so the reboot doesn't kill puppet and report an error.
      refreshonly => true
    }
  }
}
