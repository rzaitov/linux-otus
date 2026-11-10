#!/usr/bin/env python3
import ctypes
import os
import sys

# https://github.com/torvalds/linux/blob/master/include/uapi/linux/prctl.h#L158-L159
PR_SET_CHILD_SUBREAPER = 36

libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
    err = ctypes.get_errno()
    raise OSError(err, os.strerror(err))

os.execvp("bash", ["bash", *sys.argv[1:]])
