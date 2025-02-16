# @summary Setup routing
class nftablesfirewall::routing {
  # enable IPv4 forwarding - make this box a router
  file { 'net.ipv4.ip_forward':
    ensure  => file,
    path    => '/etc/sysctl.d/80-puppet-net.ipv4.ip_forward.conf',
    content => "net.ipv4.ip_forward=1\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['sysctl_net.ipv4.ip_forward'],
  } -> exec { 'sysctl_net.ipv4.ip_forward':
    command     => '/sbin/sysctl --system',
    refreshonly => true,
  }
}
