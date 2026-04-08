(** OCaml bindings to libssh, both Client and Server side
    functionality provided *)

(** Abstract type for an ssh session*)
type ssh_session

(** libssh's version *)
val version : unit -> string

(** Client side of SSH *)
module Client : sig

  (** Different log levels in increasing order of verbosity *)
  type log_level =
    | SSH_LOG_NOLOG     (** No logging at all *)
    | SSH_LOG_WARNING   (** Only warnings *)
    | SSH_LOG_PROTOCOL  (** High level protocol information *)
    | SSH_LOG_PACKET    (** Lower level protocol infomations, packet level *)
    | SSH_LOG_FUNCTIONS (** Every function path *)

  (** Different kinds of authentication accepted by libssh *)
  type auth =
    | Auto            (** Authenticate using the SSH agent *)
    | Password of string (** Authenticate with the given password *)

  (** Options needed when connecting over ssh *)
  type options = { host: string;
                   username : string option;
                   port : int;
                   log_level : log_level;
                   auth : auth; }

  (** Defaults: port 22, no username override, no logging, public-key auth.
      Use record update to override only what you need:
      [{ default_options with host = "myserver"; auth = Password "s3cr3t" }] *)
  val default_options : options

  (** Process exit status: normal exit with code, or killed by signal *)
  type status = Exited of int | Signaled of string

  (** Result of executing a remote command *)
  type exec_result = {
    status  : status;   (** How the process exited *)
    stdout  : string;   (** Standard output *)
    stderr  : string;   (** Standard error *)
  }

  (** Execute a remote command.
      Returns [Error msg] if the SSH channel operation itself fails. *)
  val exec : command:string -> ssh_session -> (exec_result, string) result

  (** Copy a local file to the remote host.
      Returns [Error msg] if the source file does not exist or the transfer fails. *)
  val scp : src_path:string -> dest_path:string -> ssh_session -> (unit, string) result

  (** Extract stdout and exit status from an [exec] result. *)
  val to_string : (exec_result, string) result -> (string * status, string) result

  (** Split stdout into lines and return with exit status. *)
  val to_lines : (exec_result, string) result -> (string list * status, string) result

end

(** Allocate a session, connect, and authenticate in one step.
    Raises [Failure] on connection or authentication failure. *)
val create : Client.options -> ssh_session
