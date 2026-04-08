// C Standard stuff
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <ctype.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
// OCaml declarations
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/callback.h>
#include <caml/custom.h>
// libssh itself
#include <libssh/libssh.h>
#include <libssh/sftp.h>

#define BUFFERSIZE 256

struct result {
  int status;
  int err;
  int exit_code;       /* remote command exit code; -1 if signaled */
  char *signal_name;   /* signal name if process was signaled, else NULL */
  char *stdout;
  char *stderr;
};

void clean_up_ssh_memory (value a_session)
{
  CAMLparam1(a_session);
  printf("Finished\n");
  CAMLnoreturn;
}

static struct custom_operations ssh_custom_ops = {
  .identifier = "ssh_custom_ops",
  .finalize = clean_up_ssh_memory,
  .compare = NULL,
  .hash = NULL,
  .serialize = NULL,
  .deserialize = NULL
};

CAMLprim value libssh_ml_version(void)
{
  return caml_copy_string(SSH_STRINGIFY(LIBSSH_VERSION));
}

CAMLprim value libssh_ml_ssh_init(void)
{
  CAMLparam0();
  CAMLlocal1(ssh_ml_handle);

  ssh_session this_sess = ssh_new();

  if (!this_sess) {
    caml_failwith("Couldn't allocate ssh session");
  }
  ssh_ml_handle = caml_alloc_custom(&ssh_custom_ops, sizeof(this_sess), 0, 1);
  *(ssh_session *)Data_custom_val(ssh_ml_handle) = this_sess;
  CAMLreturn(ssh_ml_handle);
}

void check_result(int r, ssh_session this_session)
{
  if (r != SSH_OK) {
    /* Copy error string before freeing the session that owns it. */
    char error_msg[256];
    strncpy(error_msg, ssh_get_error(this_session), sizeof(error_msg) - 1);
    error_msg[sizeof(error_msg) - 1] = '\0';
    ssh_disconnect(this_session);
    ssh_free(this_session);
    caml_failwith(error_msg);
  }
}

static void verify_server(ssh_session this_sess)
{
  switch (ssh_session_is_known_server(this_sess)) {
  case SSH_SERVER_KNOWN_OK:
    break;
  default:
    printf("Otherwise\n");
  }
}

static struct result exec_remote_command(char *this_command, ssh_session session)
{
  ssh_channel channel;
  int rc;
  char buffer[BUFFERSIZE];
  char *output = NULL;
  char *error = NULL;
  int nbytes;
  int outlen = 0, outsize = BUFFERSIZE;
  int errlen = 0, errsize = BUFFERSIZE;

  channel = ssh_channel_new(session);
  if (channel == NULL)
    return (struct result){SSH_ERROR, errno, -1, NULL, NULL, NULL};

  rc = ssh_channel_open_session(channel);
  if (rc != SSH_OK) {
    ssh_channel_free(channel);
    return (struct result){rc, errno, -1, NULL, NULL, NULL};
  }

  rc = ssh_channel_request_exec(channel, this_command);
  if (rc != SSH_OK) {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return (struct result){rc, errno, -1, NULL, NULL, NULL};
  }

  output = caml_stat_alloc(BUFFERSIZE);
  while ((nbytes = ssh_channel_read(channel, buffer, BUFFERSIZE, 0)) > 0) {
    if ((outlen + nbytes) > outsize) {
      output = caml_stat_resize(output, outsize + BUFFERSIZE);
      outsize += BUFFERSIZE;
    }
    strncpy((output + outlen), buffer, nbytes);
    outlen += nbytes;
  }

  error = caml_stat_alloc(BUFFERSIZE);
  while ((nbytes = ssh_channel_read(channel, buffer, BUFFERSIZE, 1)) > 0) {
    if ((errlen + nbytes) > errsize) {
      error = caml_stat_resize(error, errsize + BUFFERSIZE);
      errsize += BUFFERSIZE;
    }
    strncpy((error + errlen), buffer, nbytes);
    errlen += nbytes;
  }

  if (nbytes < 0) {
    caml_stat_free(output);
    caml_stat_free(error);
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return (struct result){SSH_ERROR, errno, -1, NULL, NULL, NULL};
  }

  ssh_channel_send_eof(channel);
  ssh_channel_close(channel);

  uint32_t exit_code_u = 0;
  char *sig_name = NULL;
  int is_core = 0;
  int exit_code = -1;
  char *signal_name = NULL;
  if (ssh_channel_get_exit_state(channel, &exit_code_u,
                                 &sig_name, &is_core) == SSH_OK) {
    if (sig_name) {
      signal_name = strdup(sig_name);   /* owned by libssh, copy before free */
    } else {
      exit_code = (int)exit_code_u;
    }
  }
  ssh_channel_free(channel);

  output = caml_stat_resize(output, outlen + 1);
  output[outlen] = '\0';
  error = caml_stat_resize(error, errlen + 1);
  error[errlen] = '\0';
  return (struct result){SSH_OK, 0, exit_code, signal_name, output, error};
}

CAMLprim value libssh_ml_ssh_exec(value command_val, value sess_val)
{
  CAMLparam2(command_val, sess_val);
  CAMLlocal4(result_val, status_val, stdout_val, stderr_val);

  char *command;
  size_t len;
  ssh_session this_sess;

  len = caml_string_length(command_val);
  command = caml_stat_strdup(String_val(command_val));
  if (strlen(command) != len) {
    caml_failwith("Problem copying string from OCaml to C");
  }
  this_sess = *(ssh_session *)Data_custom_val(sess_val);

  struct result this_result = exec_remote_command(command, this_sess);
  caml_stat_free(command);

  if (this_result.status != SSH_OK) {
    caml_failwith("Command execution failed");
  }

  /* Build the status variant: `Exited of int | `Signaled of string.
     OCaml represents these as blocks with tag 0 / tag 1 respectively. */
  if (this_result.signal_name) {
    status_val = caml_alloc(1, 1);   /* `Signaled _ */
    Store_field(status_val, 0, caml_copy_string(this_result.signal_name));
    free(this_result.signal_name);
  } else {
    status_val = caml_alloc(1, 0);   /* `Exited _ */
    Store_field(status_val, 0, Val_int(this_result.exit_code));
  }

  stdout_val = caml_copy_string(this_result.stdout);
  stderr_val = caml_copy_string(this_result.stderr);
  caml_stat_free(this_result.stdout);
  caml_stat_free(this_result.stderr);

  /* exec_result = { status; stdout; stderr } — field order must match OCaml type */
  result_val = caml_alloc(3, 0);
  Store_field(result_val, 0, status_val);
  Store_field(result_val, 1, stdout_val);
  Store_field(result_val, 2, stderr_val);
  CAMLreturn(result_val);
}

CAMLprim value libssh_ml_ssh_connect(value opts, value sess_val)
{
  CAMLparam2(opts, sess_val);
  CAMLlocal5(hostname_val, username_val, port_val, log_level_val, auth_val);

  char *hostname;
  int port, log_level;
  size_t len;
  ssh_session this_sess;

  this_sess = *(ssh_session *)Data_custom_val(sess_val);
  hostname_val = Field(opts, 0);
  username_val = Field(opts, 1);
  port_val = Field(opts, 2);
  log_level_val = Field(opts, 3);
  auth_val = Field(opts, 4);

  len = caml_string_length(hostname_val);
  hostname = caml_stat_strdup(String_val(hostname_val));

  if (strlen(hostname) != len) {
    caml_failwith("Problem copying string from OCaml to C");
  }

  port = Int_val(port_val);
  log_level = Int_val(log_level_val);

  check_result(ssh_options_set(this_sess, SSH_OPTIONS_HOST, hostname),
  	       this_sess);
  caml_stat_free(hostname);

  check_result(ssh_options_set(this_sess, SSH_OPTIONS_LOG_VERBOSITY, &log_level),
  	       this_sess);

  /* username is string option: Some s sets SSH_OPTIONS_USER, None leaves it
     to libssh (falls back to ~/.ssh/config or the current system user). */
  if (Is_block(username_val)) {
    value uname_str = Field(username_val, 0);
    char *username = caml_stat_strdup(String_val(uname_str));
    check_result(ssh_options_set(this_sess, SSH_OPTIONS_USER, username),
                 this_sess);
    caml_stat_free(username);
  }

  check_result(ssh_connect(this_sess), this_sess);
  verify_server(this_sess);

  /* auth is Auto (Val_int 0) or Password of string (block, tag 0, field 0). */
  if (Is_long(auth_val)) {
    check_result(ssh_userauth_publickey_auto(this_sess, NULL, NULL), this_sess);
  } else {
    char *password = caml_stat_strdup(String_val(Field(auth_val, 0)));
    int rc = ssh_userauth_password(this_sess, NULL, password);
    caml_stat_free(password);
    if (rc != SSH_AUTH_SUCCESS) {
      caml_failwith(ssh_get_error(this_sess));
    }
  }

  CAMLreturn(Val_unit);
}

CAMLprim value libssh_ml_remote_shell(value produce, value consume, value sess_val)
{
  CAMLparam3(produce, consume, sess_val);
  CAMLlocal1(exec_this);

  ssh_session this_sess = *(ssh_session *)Data_custom_val(sess_val);
  exec_this = caml_callback(produce, Val_unit);
  size_t len = caml_string_length(exec_this);
  char *copied = caml_stat_strdup(String_val(exec_this));
  if (strlen(copied) != len) {
    caml_failwith("Problem copying string from OCaml to C");
  }

  struct result r = exec_remote_command(copied, this_sess);
  caml_stat_free(copied);

  if (r.status != SSH_OK) {
    caml_failwith("Command execution failed");
  }

  caml_callback(consume, caml_copy_string(r.stdout));
  caml_stat_free(r.stdout);
  caml_stat_free(r.stderr);
  CAMLreturn(Val_unit);
}

CAMLprim value libssh_ml_ssh_scp(value src_path, value dest_path, value sess)
{
  CAMLparam3(src_path, dest_path, sess);
  char *s_path, *d_path;
  ssh_session this_sess;
  struct stat file_info;
  FILE *f;
  sftp_session sftp;
  sftp_file remote;
  char buf[BUFFERSIZE];
  size_t nread;
  ssize_t nwritten;

  s_path = caml_stat_strdup(String_val(src_path));
  d_path = caml_stat_strdup(String_val(dest_path));
  this_sess = *(ssh_session *)Data_custom_val(sess);

  if (stat(s_path, &file_info) != 0) {
    caml_stat_free(s_path); caml_stat_free(d_path);
    caml_failwith("Cannot stat source file");
  }

  f = fopen(s_path, "rb");
  if (!f) {
    caml_stat_free(s_path); caml_stat_free(d_path);
    caml_failwith("Cannot open source file");
  }

  sftp = sftp_new(this_sess);
  if (!sftp) {
    fclose(f); caml_stat_free(s_path); caml_stat_free(d_path);
    caml_failwith(ssh_get_error(this_sess));
  }

  if (sftp_init(sftp) != SSH_OK) {
    sftp_free(sftp); fclose(f); caml_stat_free(s_path); caml_stat_free(d_path);
    caml_failwith(ssh_get_error(this_sess));
  }

  remote = sftp_open(sftp, d_path, O_WRONLY | O_CREAT | O_TRUNC,
                     file_info.st_mode & 0777);
  if (!remote) {
    sftp_free(sftp); fclose(f); caml_stat_free(s_path); caml_stat_free(d_path);
    caml_failwith(ssh_get_error(this_sess));
  }

  while ((nread = fread(buf, 1, sizeof(buf), f)) > 0) {
    nwritten = sftp_write(remote, buf, nread);
    if (nwritten < 0 || (size_t)nwritten != nread) {
      sftp_close(remote); sftp_free(sftp); fclose(f);
      caml_stat_free(s_path); caml_stat_free(d_path);
      caml_failwith("sftp_write: short write");
    }
  }

  sftp_close(remote);
  sftp_free(sftp);
  fclose(f);
  caml_stat_free(s_path);
  caml_stat_free(d_path);

  CAMLreturn(Val_unit);
}
