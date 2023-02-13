# crashctl
A simple tool for crashing server diagnosis. A replacement for `journalctl --list-boots` with additional and more readable information.

```
$ crashctl
Distribution        : Debian GNU/Linux 10 (buster)
Kernel              : 4.19.0-23-amd64 #1 SMP Debian 4.19.269-1 (2022-12-20)
Current boot        : 555ebf2e-5cd0-4f52-b6fe-a4734248cc82
Scaled load         : 0.24 0.25 0.23
System installed    : Wed Feb  1 09:41:10 UTC 2023
System started      : Mon Feb 13 11:33:08 UTC 2023
Uptime              : up 4:52
Running processes   : 401
kdump               : kdump-tools not installed. Try: apt install kdump-tools
Boot First message        Last message             Uptime       Reboot/Crash
-------------------------------------------------------------------------------------
-1   2023-02-07 06:29:00 UTC 2023-02-13 11:31:08 UTC  6d 05:02:08  reboot (SIGTERM)
0    2023-02-13 11:33:16 UTC 2023-02-13 16:25:43 UTC  0d 04:52:27  running

```

## Install

The script is written Bash, it might work on any distribution using Systemd.

```
wget https://raw.githubusercontent.com/deric/crashctl/main/crashctl.sh -O /usr/local/bin/crashctl
```

Asumes existence of basic Unix utils as `cat`, `awk`, `stat`

Following utils might require `root` priviledges:

  - `journalctl`
  - `tune2fs`
