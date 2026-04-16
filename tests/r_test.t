  $ ./r_test.exe
  pass: uname writes to stdout, not stderr
  pass: ls of missing path writes to stderr, not stdout
  pass: scp: file content arrives intact on the remote side
  pass: scp_from: file content arrives intact on the local side
  pass: to_lines splits stdout into lines
  pass: one session can be reused across exec and scp
