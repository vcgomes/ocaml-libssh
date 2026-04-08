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

  let default_options = {
    host       = "";
    username   = None;
    port       = 22;
    log_level  = SSH_LOG_NOLOG;
    auth       = Auto;
  }

  external connect_exn : options -> ssh_session -> unit = "libssh_ml_ssh_connect"

  type status = Exited of int | Signaled of string

  type exec_result = {
    status  : status;
    stdout  : string;
    stderr  : string;
  }

  external exec_exn : command:string -> ssh_session -> exec_result = "libssh_ml_ssh_exec"

  let exec ~command session =
    match exec_exn ~command session with
    | r                     -> Ok r
    | exception Failure msg -> Error msg

  external unsafe_scp :
    string ->
    string ->
    ssh_session ->
    unit = "libssh_ml_ssh_scp"

  let scp ~src_path ~dest_path h =
    if not @@ Sys.file_exists src_path then Error "This file doesn't exist"
    else match unsafe_scp src_path dest_path h with
    | ()                    -> Ok ()
    | exception Failure msg -> Error msg

  let to_string r =
    Result.map (fun r -> (r.stdout, r.status)) r

  let to_lines r =
    Result.map (fun r ->
      let lines = String.split_on_char '\n' r.stdout in
      let lines = match List.rev lines with
        | "" :: rest -> List.rev rest
        | _ -> lines
      in
      (lines, r.status)) r

end
