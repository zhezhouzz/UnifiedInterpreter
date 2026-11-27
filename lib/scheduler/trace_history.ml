open Stdlib
module S = Sqlite3

let sha text=Digestif.SHA256.(to_hex (digest_string text))
let default_file ()=
  let root=match Sys.getenv_opt "XDG_STATE_HOME" with Some p when p<>""->p
    | _->Filename.concat (Sys.getenv "HOME") ".local/state" in
  Filename.concat root "unified-interpreter/traces.sqlite3"

let rec mkdir path=
  if not (Sys.file_exists path) then (
    mkdir (Filename.dirname path);
    try Unix.mkdir path 0o700 with Unix.Unix_error (Unix.EEXIST,_,_)->())

let exec db sql=S.Rc.check (S.exec db sql)
let stmt db sql params f=
  let s=S.prepare db sql in
  Fun.protect ~finally:(fun ()->S.Rc.check (S.finalize s)) (fun ()->
    S.Rc.check (S.bind_values s params);f s)
let write db sql params=stmt db sql params (fun s->S.Rc.check (S.step s))
let row db sql params=stmt db sql params (fun s->match S.step s with
  | ROW->Some (S.row_data s) | DONE->None | rc->S.Rc.check rc;assert false)
let string=S.Data.to_string_exn
let text x=S.Data.TEXT x
let transaction db f=
  exec db "BEGIN IMMEDIATE";
  match f () with v->exec db "COMMIT";v | exception ex->exec db "ROLLBACK";raise ex

exception Busy

let with_db ~timeout_ms filename f=
  mkdir (Filename.dirname filename);
  let db=S.db_open filename in
  Fun.protect ~finally:(fun ()->ignore (S.db_close db)) (fun ()->
    S.busy_timeout db timeout_ms;
    try
    exec db "CREATE TABLE IF NOT EXISTS searches (id TEXT PRIMARY KEY, guide INTEGER NOT NULL, cursor TEXT, revision INTEGER NOT NULL)";
    exec db "CREATE TABLE IF NOT EXISTS guides (id TEXT, seq INTEGER, body TEXT NOT NULL, PRIMARY KEY(id,seq))";
    exec db "CREATE TABLE IF NOT EXISTS issued (id TEXT, hash TEXT, body TEXT NOT NULL, PRIMARY KEY(id,hash))";
    f db with S.SqliteError _ when List.mem (S.errcode db) [S.Rc.BUSY;S.Rc.LOCKED] -> raise Busy)
