let check name f =
  match f () with
  | () -> Printf.printf "pass: %s\n%!" name
  | exception exn ->
    Printf.eprintf "FAIL: %s: %s\n%!" name (Printexc.to_string exn);
    exit 1

let print_result label r =
  let status_str = match r.Ssh.Client.status with
    | Ssh.Client.Exited n   -> Printf.sprintf "exited %d" n
    | Ssh.Client.Signaled s -> Printf.sprintf "signaled %s" s
  in
  Printf.printf "%s: status=%s stdout=%S stderr=%S\n%!"
    label status_str r.Ssh.Client.stdout r.Ssh.Client.stderr

let () =
  Printf.printf "SSH version is: %s\n%!" (Ssh.version ());
  let a_session = Ssh.create () in
  let opts = Ssh.Client.({ host = "localhost";
                           log_level = SSH_LOG_NOLOG;
                           port = 22;
                           username = Sys.getenv "USER";
                           auth = Auto; })
  in
  Ssh.Client.connect opts a_session;

  check "uname writes to stdout, not stderr" (fun () ->
    let r = Ssh.Client.exec ~command:"uname -a" a_session in
    print_result "uname -a" r;
    assert (String.length r.Ssh.Client.stdout > 0);
    assert (r.Ssh.Client.stderr = "");
    assert (r.Ssh.Client.status = Ssh.Client.Exited 0));

  check "ls of missing path writes to stderr, not stdout" (fun () ->
    let r = Ssh.Client.exec ~command:"ls /no_such_path_xyz" a_session in
    print_result "ls /no_such_path_xyz" r;
    assert (r.Ssh.Client.stdout = "");
    assert (String.length r.Ssh.Client.stderr > 0);
    assert (r.Ssh.Client.status <> Ssh.Client.Exited 0))
