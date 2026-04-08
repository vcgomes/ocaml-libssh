(** OCaml bindings to libssh, both Client and Server side
    functionality provided *)

(** Abstract type for an ssh session*)
type ssh_session

(** libssh's version *)
val version : unit -> string

(** Create a fresh ssh_session *)
val create : unit -> ssh_session

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
    | Auto        (** Authenticate using the Ssh agent, assuming its running *)
    | Interactive (** Type in the password on the command line*)

  (** Options needed when connecting over ssh *)
  type options = { host: string;
                   username : string option;
                   port : int;
                   log_level : log_level;
                   auth : auth; }

  (** Connect and authenticate a ssh connection *)
  val connect : options -> ssh_session -> unit

  (** Process exit status: normal exit with code, or killed by signal *)
  type status = Exited of int | Signaled of string

  (** Result of executing a remote command *)
  type exec_result = {
    status  : status;   (** How the process exited *)
    stdout  : string;   (** Standard output *)
    stderr  : string;   (** Standard error *)
  }

  (** Execute a remote command and return its output and exit status.
      Raises [Failure] if the SSH channel operation itself fails. *)
  val exec : command:string -> ssh_session -> exec_result

  val scp : src_path:string -> dest_path:string -> ssh_session -> unit

end
