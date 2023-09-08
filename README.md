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

With `kdump-tools` installed each session might be matched to a crash log:

```
-2   2023-09-08 11:35:19 UTC   2023-09-08 11:35:32 UTC  0d 00:00:13  kernel panic. See /var/crash/202309081135
-1   2023-09-08 11:38:37 UTC   2023-09-08 12:45:32 UTC  0d 01:06:55  CRASH?
0    2023-09-08 13:39:29 UTC   2023-09-08 21:31:53 UTC  0d 07:52:24  running

```


## Advanced usage

Detecting crash is not always reliable sometimes kernel might crash without logging a message or the power could be cut, etc. Reboot or shutdown sequence can be found in logs.

```
$ crashctl --boots --utc
Boot First message             Last message             Uptime       Reboot/Crash
-------------------------------------------------------------------------------------
-11  2022-12-05 20:43:53 UTC   2022-12-05 20:52:00 UTC  0d 00:08:07  reboot (SIGTERM)
-10  2022-12-06 07:56:01 UTC   2022-12-06 15:14:36 UTC  0d 07:18:35  CRASH?
-9   2022-12-07 12:28:07 UTC   2022-12-10 16:33:43 UTC  3d 04:05:36  reboot (SIGTERM)
-8   2022-12-12 08:56:05 UTC   2022-12-18 08:18:40 UTC  5d 23:22:35  CRASH?
-7   2022-12-18 08:32:27 UTC   2022-12-25 10:54:03 UTC  7d 02:21:36  reboot (SIGTERM)
-6   2022-12-28 10:51:54 UTC   2022-12-29 12:12:32 UTC  1d 01:20:38  Power key pressed, but ignored
-5   2023-01-02 08:45:54 UTC   2023-01-06 08:05:01 UTC  3d 23:19:07  CRASH?
-4   2023-01-06 10:07:00 UTC   2023-01-12 10:01:25 UTC  5d 23:54:25  Power key pressed, but ignored
-3   2023-01-12 10:04:36 UTC   2023-01-28 14:07:19 UTC  16d 04:02:43 reboot (SIGTERM)
-2   2023-01-30 08:43:42 UTC   2023-01-31 07:27:26 UTC  0d 22:43:44  reboot (SIGTERM)
-1   2023-02-02 12:41:51 UTC   2023-02-04 13:16:19 UTC  2d 00:34:28  reboot (SIGTERM)
0    2023-02-06 03:12:01 UTC   2023-02-13 18:17:52 UTC  7d 15:05:51  running
```
