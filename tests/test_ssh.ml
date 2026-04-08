let run name f =
  match f () with
  | () -> Printf.printf "pass: %s\n%!" name
  | exception exn ->
    Printf.eprintf "FAIL: %s: %s\n%!" name (Printexc.to_string exn);
    exit 1

let () =
  run "version is non-empty" (fun () ->
    assert (String.length (Ssh.version ()) > 0));

  run "create with connection refused raises Failure" (fun () ->
    let opts = { Ssh.Client.default_options with host = "localhost"; port = 1 } in
    match Ssh.create opts with
    | _ -> failwith "expected Failure, got a session"
    | exception Failure _ -> ())
