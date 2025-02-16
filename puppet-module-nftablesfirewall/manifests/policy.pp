# @summary Deploy a policy file and load it
class nftablesfirewall::policy {
  package { 'nftables':
    ensure => present,
  } -> file { '/etc/sysconfig/nftables.conf':
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
    source => 'puppet:///modules/nftablesfirewall/etc/sysconfig/nftables.conf',
    notify => Service['nftables.service']
  } -> file { '/etc/nftables/firewall.nft':
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
    source => 'puppet:///modules/nftablesfirewall/etc/nftables/firewall.nft',
    notify => Service['nftables.service']
  } -> service { 'nftables.service':
    ensure => 'running',
    enable => true,
  }
}
