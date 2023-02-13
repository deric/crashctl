# crashctl
A simple tool for crashing server diagnosis.

## Install

The script is written Bash, it might work on any distribution using Systemd.

```
wget https://raw.githubusercontent.com/deric/crashctl/main/crashctl.sh -O /usr/local/bin/crashctl
```

Asumes existence of basic Unix utils as `cat`, `awk`, `stat`

Following utils might require `root` priviledges:

  - `journalctl`
  - `tune2fs`
