# Killable D-state process

Compile dstate program from the article:
```bash
cc -o dstate dstate.c
```

Run in the same Bash session:
```bash
$ ./dstate &
[2] 421484

$ parent_pid=$!
$ child_pid=$(pgrep -P "$parent_pid")
$ ps -o pid,ppid,state,cmd -p "$parent_pid,$child_pid"
    PID    PPID S CMD
 421484  272591 D ./dstate
 421486  421484 S ./dstate
```

Kill the parent:
```bash
$ kill -9 "$parent_pid"
[2]+  Killed                  ./dstate

$ ps -o pid,ppid,state,cmd -p "$parent_pid,$child_pid"
    PID    PPID S CMD
 421486       1 S ./dstate
```

## Refs

[Chris Down — Creating controllable D state processes](https://chrisdown.name/2024/02/05/reliably-creating-d-state-processes-on-demand.html).
