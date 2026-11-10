# Linux subreaper

- subreaper.py — enables the flag, then replaces itself with Bash.
- demo.sh — creates an orphan and displays its parent PID.

Run from that folder:
```bash
$ ./subreaper.py ./demo.sh
Outer Bash PID: 397348
    PID    PPID STAT COMMAND
 397348  272591 S+   bash ./demo.sh
 397353  397348 S+   sleep 60
```

Compare without the flag:
```bash
$ ./demo.sh
Outer Bash PID: 398235
    PID    PPID STAT COMMAND
 398235  272591 S+   bash ./demo.sh
 398237       1 S+   sleep 60
```
