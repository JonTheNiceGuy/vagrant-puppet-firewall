# @summary Setup and permit DHCPD on defined interfaces
class nftablesfirewall::dhcpd(
  String  $network_base = '198.18',
  Integer $dev_offset = 32,
  Integer $prod_offset = 64,
  Integer $shared_offset = 96,
  Integer $gateway_address = 1,
  String  $dns_servers = '8.8.8.8,8.8.4.4',
) {
  # Work out the Device IP and interface naming from the transit interface
  if ($facts['networking']['interfaces']['transit'] and $facts['networking']['interfaces']['transit']['ip']) {
    $vm_lan_ip_subnet  = $facts['networking']['interfaces']['transit']['ip']
    $shared_nic        = 'shared'
    $dev_nic           = 'dev'
    $prod_nic          = 'prod'

    # Get the IP address of the relevant interface
    $prod_gateway   = $facts['networking']['interfaces'][$prod_nic]['ip']
    $dev_gateway    = $facts['networking']['interfaces'][$dev_nic]['ip']
    $shared_gateway = $facts['networking']['interfaces'][$shared_nic]['ip']

    # Calculate what firewall device this is
    $split_ip       = split($vm_lan_ip_subnet , '[.]')

    # Extract the last octet, ensuring it exists
    if $split_ip and size($split_ip) == 4 {
      $vm_last_octet = Integer($split_ip[3])
    } else {
      fail("Invalid IP address format: ${split_ip}")
    }

    # Calculate the first three octets of the IP addresses of the various interfaces
    $dev_subnet    = "${network_base}.${$dev_offset + $vm_last_octet}"
    $prod_subnet   = "${network_base}.${$prod_offset + $vm_last_octet}"
    $shared_subnet = "${network_base}.${$shared_offset + $vm_last_octet}"

    package { 'dnsmasq':
      ensure => present
    }

    file { '/etc/dnsmasq.conf':
      owner   => root,
      group   => 'dnsmasq',
      mode    => '0644',
      content => template('nftablesfirewall/etc/dnsmasq.conf.erb'),
      notify  => Service['dnsmasq.service'],
      require => Package['dnsmasq'],
    }

    service { 'dnsmasq.service':
      ensure  => 'running',
      enable  => true,
      require => File['/etc/dnsmasq.conf'],
    }
  } else {
    notify { 'NoDnsmasq':
      message => 'Dnsmasq is not deployed, interfaces still incomplete.'
    }
  }
}
