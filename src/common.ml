type ssh_session

external version : unit -> string = "libssh_ml_version"

external ssh_new : unit -> ssh_session = "libssh_ml_ssh_init"
