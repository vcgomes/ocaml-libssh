let () =
  let opts = { Ssh.Client.default_options with host = "localhost" } in
  let session = Ssh.create opts in
  match Ssh.Client.(exec_out ~command:"cat /proc/cpuinfo" session |> to_lines) with
  | Error e -> Printf.eprintf "error: %s\n" e; exit 1
  | Ok lines ->
    lines
    |> List.filter (String.starts_with ~prefix:"cpu MHz")
    |> List.iter print_endline
