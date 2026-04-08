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
                           username = None;
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
    assert (r.Ssh.Client.status <> Ssh.Client.Exited 0));

  check "scp: file content arrives intact on the remote side" (fun () ->
    let content = "hello from r_test\n" in
    let src = Filename.temp_file "r_test_src" ".txt" in
    let dst = Filename.temp_file "r_test_dst" ".txt" in
    (let oc = open_out src in output_string oc content; close_out oc);
    Ssh.Client.scp ~src_path:src ~dest_path:dst a_session;
    let r = Ssh.Client.exec ~command:("cat " ^ dst) a_session in
    Sys.remove src;
    let _ = Ssh.Client.exec ~command:("rm -f " ^ dst) a_session in
    assert (r.Ssh.Client.stdout = content);
    assert (r.Ssh.Client.status = Ssh.Client.Exited 0))
