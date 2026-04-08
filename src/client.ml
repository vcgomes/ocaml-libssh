open Common

module Client = struct

  type log_level =
    | SSH_LOG_NOLOG
    | SSH_LOG_WARNING
    | SSH_LOG_PROTOCOL
    | SSH_LOG_PACKET
    | SSH_LOG_FUNCTIONS

  type auth =
    | Auto
    | Password of string

  type options = { host: string;
                   username : string option;
                   port : int;
                   log_level : log_level;
                   auth : auth; }

  external connect : options -> ssh_session -> unit = "libssh_ml_ssh_connect"

  type status = Exited of int | Signaled of string

  type exec_result = {
    status  : status;
    stdout  : string;
    stderr  : string;
  }

  external exec : command:string -> ssh_session -> exec_result = "libssh_ml_ssh_exec"

  external unsafe_scp :
    string ->
    string ->
    ssh_session ->
    unit = "libssh_ml_ssh_scp"

  let scp ~src_path ~dest_path h =
    if not @@ Sys.file_exists src_path then failwith "This file doesn't exist";
    unsafe_scp src_path dest_path h;
    print_endline "copied"

end
