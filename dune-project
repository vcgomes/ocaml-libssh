(lang dune 2.0)
(generate_opam_files)

(source (github vcgomes/ocaml-libssh))
(license "BSD-3-clause")
(authors "Edgar Aroutiounian")
(maintainers "edgar.factorial@gmail.com")

(package
 (name libssh)
 (synopsis "libssh bindings for OCaml")
 (description "C bindings for the libssh library providing client and server support"))
