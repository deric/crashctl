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

## Usage

See `crashctl -h` for usage.


## Advanced usage

Detecting crash is not always reliable sometimes kernel might crash without logging a message or the power could be cut, etc. Reboot or shutdown sequence can be found in logs.

```
$ crashctl --boots
Boot First message             Last message             Uptime       Reboot/Crash
-------------------------------------------------------------------------------------
-6   2023-02-07 06:50:30 UTC   2023-02-12 17:23:28 UTC  5d 10:32:58  CRASH?
-5   2023-02-12 17:26:04 UTC   2023-02-12 17:34:59 UTC  0d 00:08:55  CRASH?
-4   2023-02-12 17:37:39 UTC   2023-02-12 21:48:10 UTC  0d 04:10:31  CRASH?
-3   2023-02-12 21:50:48 UTC   2023-02-12 22:38:56 UTC  0d 00:48:08  CRASH?
-2   2023-02-12 22:42:02 UTC   2023-02-13 02:02:07 UTC  0d 03:20:05  CRASH?
-1   2023-02-13 02:04:40 UTC   2023-02-13 04:04:46 UTC  0d 02:00:06  CRASH?
0    2023-02-13 04:07:21 UTC   2023-02-13 16:35:41 UTC  0d 12:28:20  running
```
