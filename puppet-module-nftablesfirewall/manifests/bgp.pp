# @summary Install and configure FRR
class nftablesfirewall::bgp (
  String  $bgp_our_asn            = '65513',
  Boolean $bgp_our_peer_enabled   = true,
  Boolean $bgp_advertise_networks = true,
  Boolean $bgp_cloud_peer_enabled = false,
  String  $bgp_cloud_peer_asn     = '65511',
  Array   $bgp_cloud_peer_ips     = ['198.18.0.2', '198.18.0.3'],
  String  $network_base           = '198.18',
  Integer $transit_octet          = 255,
  Integer $prod_offset            = 32,
  Integer $dev_offset             = 64,
  Integer $shared_offset          = 96,
) {
  #################################################################
  ######## Only setup BGP if the transit interface is setup
  #################################################################
  if ($facts['networking']['interfaces']['transit'] and $facts['networking']['interfaces']['transit']['ip']) {
    $vm_lan_ip_address = $facts['networking']['interfaces']['transit']['ip']

    #################################################################
    ######## Work out the offset to get the firewall ID
    #################################################################
    $split_ip = split($vm_lan_ip_address, '[.]')
    # Extract the last octet, ensuring it exists
    if $split_ip and size($split_ip) == 4 {
      $vm_last_octet = Integer($split_ip[3])

      # Time to add the other important addresses for this device
      $dev_address    = "${network_base}.${$dev_offset + $vm_last_octet}.0/24"
      $prod_address   = "${network_base}.${$prod_offset + $vm_last_octet}.0/24"
      $shared_address = "${network_base}.${$shared_offset + $vm_last_octet}.0/24"

      # Calculate the peers from the range 0..31 (excluding this one)
      $peer_addresses = range(0, 31).map |$i| {
        "${network_base}.${transit_octet}.${i}"
      }.filter |$ip| { $ip != $vm_lan_ip_address }

      package { 'frr':
        ensure => present,
      } -> file { '/etc/frr/frr.conf':
        ensure  => file,
        content => template('nftablesfirewall/etc/frr/frr.conf.erb'),
        owner   => 'frr',
        group   => 'frr',
        mode    => '0640',
        notify  => Service['frr.service'],
        require => Package['frr'],
      } -> exec { 'Enable bgpd':
        command => '/usr/bin/sed -i -e "s/bgpd=no/bgpd=yes/" /etc/frr/daemons',
        unless  => '/usr/bin/grep "bgpd=yes" /etc/frr/daemons',
        notify  => Service['frr.service'],
      } -> service { 'frr.service':
        ensure  => 'running',
        enable  => true,
        require => Package['frr'],
      }
    } else {
      notify { 'NoFrr':
        message => "Frr is not deployed, invalid IP address format: ${split_ip}"
      }
    }
  } else {
    notify { 'NoFrr':
      message => 'Frr is not deployed, interfaces still incomplete.'
    }
  }
}
