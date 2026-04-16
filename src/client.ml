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

  type run_out = {
    run_stdout : string;
    run_status : status;
  }

  let exec_out ~command session =
    Result.map (fun r -> { run_stdout = r.stdout; run_status = r.status })
      (exec ~command session)

  external unsafe_scp_to :
    string ->
    string ->
    ssh_session ->
    unit = "libssh_ml_ssh_scp"

  let scp_to ~src_path ~dest_path h =
    if not @@ Sys.file_exists src_path then Error "This file doesn't exist"
    else match unsafe_scp_to src_path dest_path h with
    | ()                    -> Ok ()
    | exception Failure msg -> Error msg

  external unsafe_scp_from :
    string ->
    string ->
    ssh_session ->
    unit = "libssh_ml_ssh_scp_from"

  let scp_from ~remote_path ~local_path h =
    match unsafe_scp_from remote_path local_path h with
    | ()                    -> Ok ()
    | exception Failure msg -> Error msg

  let check_status o f =
    match o.run_status with
    | Exited 0   -> Ok (f o.run_stdout)
    | Exited n   -> Error (Printf.sprintf "exited with %d" n)
    | Signaled s -> Error (Printf.sprintf "signaled with %s" s)

  let to_string r =
    Result.bind r (fun o -> check_status o (fun s -> s))

  let to_lines r =
    Result.bind r (fun o ->
      check_status o (fun s ->
        let lines = String.split_on_char '\n' s in
        match List.rev lines with
        | "" :: rest -> List.rev rest
        | _ -> lines))

end
