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
    unwrap (Ssh.Client.scp_to ~src_path:src ~dest_path:dst session);
    let r = unwrap (Ssh.Client.exec ~command:("cat " ^ dst) session) in
    Sys.remove src;
    let _ = Ssh.Client.exec ~command:("rm -f " ^ dst) session in
    assert (r.Ssh.Client.stdout = content);
    assert (r.Ssh.Client.status = Ssh.Client.Exited 0));

  check "scp_from: file content arrives intact on the local side" (fun () ->
    let content = "hello from scp_from test\n" in
    let src = Filename.temp_file "r_test_from_src" ".txt" in
    let remote = Filename.temp_file "r_test_from_remote" ".txt" in
    let local = Filename.temp_file "r_test_from_local" ".txt" in
    (* create a known file, push it to remote, then pull it back *)
    (let oc = open_out src in output_string oc content; close_out oc);
    unwrap (Ssh.Client.scp_to ~src_path:src ~dest_path:remote session);
    unwrap (Ssh.Client.scp_from ~remote_path:remote ~local_path:local session);
    let ic = open_in local in
    let got = In_channel.input_all ic in
    close_in ic;
    Sys.remove src;
    Sys.remove local;
    let _ = Ssh.Client.exec ~command:("rm -f " ^ remote) session in
    assert (got = content));

  check "to_lines splits stdout into lines" (fun () ->
    let lines =
      unwrap (Ssh.Client.(exec_out ~command:"printf 'a\nb\nc'" session |> to_lines))
    in
    assert (lines = ["a"; "b"; "c"]));

  check "one session can be reused across exec and scp" (fun () ->
    let content = "session reuse test\n" in
    let src = Filename.temp_file "r_test_reuse_src" ".txt" in
    let dst = Filename.temp_file "r_test_reuse_dst" ".txt" in
    (* exec before scp *)
    let r1 = unwrap (Ssh.Client.exec ~command:"echo before" session) in
    (* scp *)
    (let oc = open_out src in output_string oc content; close_out oc);
    unwrap (Ssh.Client.scp_to ~src_path:src ~dest_path:dst session);
    (* exec after scp, then exec to verify scp result *)
    let r2 = unwrap (Ssh.Client.exec ~command:"echo after" session) in
    let r3 = unwrap (Ssh.Client.exec ~command:("cat " ^ dst) session) in
    Sys.remove src;
    let _ = Ssh.Client.exec ~command:("rm -f " ^ dst) session in
    assert (r1.Ssh.Client.stdout = "before\n");
    assert (r1.Ssh.Client.status = Ssh.Client.Exited 0);
    assert (r2.Ssh.Client.stdout = "after\n");
    assert (r2.Ssh.Client.status = Ssh.Client.Exited 0);
    assert (r3.Ssh.Client.stdout = content);
    assert (r3.Ssh.Client.status = Ssh.Client.Exited 0))
