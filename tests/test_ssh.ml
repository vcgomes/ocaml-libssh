let run name f =
  match f () with
  | () -> Printf.printf "pass: %s\n%!" name
  | exception exn ->
    Printf.eprintf "FAIL: %s: %s\n%!" name (Printexc.to_string exn);
    exit 1

let () =
  run "version is non-empty" (fun () ->
    assert (String.length (Ssh.version ()) > 0));

  run "create does not raise" (fun () ->
    let _s = Ssh.create () in ());

  run "exec on unconnected session raises Failure" (fun () ->
    let s = Ssh.create () in
    match Ssh.Client.exec ~command:"echo hi" s with
    | _ -> failwith "expected Failure, got a result"
    | exception Failure _ -> ())
