include Common
include Client
include Server

let create opts =
  let session = ssh_new () in
  Client.connect_exn opts session;
  session
