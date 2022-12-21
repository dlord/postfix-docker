milter = yes; # Enable milter mode
timeout = 120s; # Needed for Milter usually

upstream "local" {
  self_scan = yes;
}

bind_socket = "/var/spool/postfix/rspamd/rspamd.sock mode=0664 group=postfix";
