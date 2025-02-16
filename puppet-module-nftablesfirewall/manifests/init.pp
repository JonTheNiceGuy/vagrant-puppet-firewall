# @summary Load various sub-manifests
class nftablesfirewall {
  # Setup interfaces
  class { 'nftablesfirewall::interfaces': }

  # make this server route traffic
  class { 'nftablesfirewall::routing':
    require => Class['nftablesfirewall::interfaces'],
  }
  class { 'nftablesfirewall::bgp':
    require => Class['nftablesfirewall::interfaces'],
  }

  # Allow traffic flows across the firewall
  class { 'nftablesfirewall::policy':
    require => Class['nftablesfirewall::interfaces'],
  }

  # make this server assign IP addresses
  class { 'nftablesfirewall::dhcpd':
    require => Class['nftablesfirewall::interfaces'],
  }
}
