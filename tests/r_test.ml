let unwrap = function
  | Ok v -> v
  | Error msg -> failwith msg

let check name f =
  match f () with
  | () -> Printf.printf "pass: %s\n%!" name
  | exception exn ->
    Printf.eprintf "FAIL: %s: %s\n%!" name (Printexc.to_string exn);
    exit 1

let () =
  let opts = { Ssh.Client.default_options with host = "localhost" } in
  let session = Ssh.create opts in

  check "uname writes to stdout, not stderr" (fun () ->
    let r = unwrap (Ssh.Client.exec ~command:"uname -a" session) in
    assert (String.length r.Ssh.Client.stdout > 0);
    assert (r.Ssh.Client.stderr = "");
    assert (r.Ssh.Client.status = Ssh.Client.Exited 0));

  check "ls of missing path writes to stderr, not stdout" (fun () ->
    let r = unwrap (Ssh.Client.exec ~command:"ls /no_such_path_xyz" session) in
    assert (r.Ssh.Client.stdout = "");
    assert (String.length r.Ssh.Client.stderr > 0);
    assert (r.Ssh.Client.status <> Ssh.Client.Exited 0));

  check "scp: file content arrives intact on the remote side" (fun () ->
    let content = "hello from r_test\n" in
    let src = Filename.temp_file "r_test_src" ".txt" in
    let dst = Filename.temp_file "r_test_dst" ".txt" in
    (let oc = open_out src in output_string oc content; close_out oc);
    unwrap (Ssh.Client.scp ~src_path:src ~dest_path:dst session);
    let r = unwrap (Ssh.Client.exec ~command:("cat " ^ dst) session) in
    Sys.remove src;
    let _ = Ssh.Client.exec ~command:("rm -f " ^ dst) session in
    assert (r.Ssh.Client.stdout = content);
    assert (r.Ssh.Client.status = Ssh.Client.Exited 0));

  check "to_lines splits stdout into lines" (fun () ->
    let lines, status =
      unwrap (Ssh.Client.(exec ~command:"printf 'a\nb\nc'" session |> to_lines))
    in
    assert (lines = ["a"; "b"; "c"]);
    assert (status = Ssh.Client.Exited 0))
