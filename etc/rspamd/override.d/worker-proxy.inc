upstream "local" {
  default = yes;
  hosts = "127.0.0.1";
  self_scan = yes;
}

bind_socket = "0.0.0.0:11332";
