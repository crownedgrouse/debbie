%%%-------------------------------------------------------------------
%%% File:      debbie.erl
%%% @author    Eric Pailleau <debbie@crownedgrouse.com>
%%% @copyright 2014 crownedgrouse.com
%%% @doc  
%%% .DEB Built In Erlang
%%% @end  
%%%
%%% Permission to use, copy, modify, and/or distribute this software
%%% for any purpose with or without fee is hereby granted, provided
%%% that the above copyright notice and this permission notice appear
%%% in all copies.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
%%% WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
%%% WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
%%% AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
%%% CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
%%% LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
%%% NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
%%% CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%%%
%%% Created : 2014-09-07
%%%-------------------------------------------------------------------

-module(debbie).
-author("Eric Pailleau <debbie@crownedgrouse.com>").

-export([fy/1]).


fy(C) when is_list(C) ->
                         % TempDir basename
                         TDB = integer_to_list(erlang:phash2({self(),calendar:local_time()})),
                         try
                            % Define pathes
                            RootPath    = check_path(root_path, filename:absname(proplists:get_value(root_path, C))),
                            DebianPath  = case filelib:is_dir(filename:join(RootPath, "debian")) of
                                                false ->  filename:join(RootPath, "DEBIAN");
                                                true  ->  filename:join(RootPath, "debian")
                                          end,
                            ControlFile = filename:join(DebianPath, "control"),
                            % Define variables
                            DebVersion  = proplists:get_value(debversion, C, "2.0\n"),
                            User        = proplists:get_value(user, C, {0, "root"}),
                            Group       = list_to_tuple(lists:reverse(tuple_to_list(proplists:get_value(group, C, {0, "root"})))), % swab syntax
                            % Check presence of control file (at least)
                            check_file(ControlFile),
                            % Check presence of something to pack !
                            check_no_empty(RootPath),
                            % Creation of temporary working directory
                            TmpDir      = filename:join(RootPath, TDB),
                            ok          = file:make_dir(TmpDir), % Should fail if already exists
                            % Creating debian-binary file
                            deb_version(TmpDir, DebVersion),
                            % Creating control.tar.gz UID=GID=0 User=Group=root
                            deb_control(TmpDir, DebianPath),
                            % Creating data.tar.gz with specified UID/GID otherwise root/root (swab syntax)
                            deb_data(TmpDir, RootPath, [{tar, User}, {tar, Group}, {convert, gzip}]),
                            % Creating .deb
                            Deb         = deb_pack(TmpDir),
                            % Moving .deb to RootPath
                            _ResFile     = deb_move(Deb, RootPath),
                            ok
                         catch 
                            throw:Term -> {error, Term}
                         after
                            % Cleaning temporary working directory
                            Tmp = filename:join(proplists:get_value(root_path, C), TDB),
                            lists:foreach(fun(X) -> ok = file:delete(X) end, filelib:wildcard(filename:join(Tmp, "*"))),
                            file:del_dir(Tmp) 
                         end.

%%-------------------------------------------------------------------------
%% @doc Generic check of a directory presence.
%% @end
%%-------------------------------------------------------------------------
-spec check_path(atom(), undefined | list()) -> list() | error.

check_path(Path, undefined) -> throw("Mandatory " ++ atom_to_list(Path) ++ " path not set. Aborting.");

check_path(Path, D) when
              is_list(D) -> case filelib:is_dir(D) of
                                true  -> D ;
                                false -> throw("Invalid " ++ atom_to_list(Path) ++ " directory : " ++ D), error
                            end.

%%-------------------------------------------------------------------------
%% @doc Generic check of regular file presence.
%% @end
%%-------------------------------------------------------------------------
-spec check_file(list()) -> ok | error .

check_file(F) when
         is_list(F)-> case filelib:is_file(F) of
                            true  -> case filelib:is_regular(F) of
                                        true  -> ok ;
                                        false -> throw("Invalid regular file : " ++ F), error
                                     end;
                            false -> throw("File not found : " ++ F) , error
                      end.

%%-------------------------------------------------------------------------
%% @doc Check there is something (data) to pack.
%%      I.e more than two directories (DEBIAN and TmpDir) under root path.
%% @end
%%-------------------------------------------------------------------------
-spec check_no_empty(list()) -> ok | error .

check_no_empty(R) -> L = filelib:wildcard(filename:join(R, "*")),
                     case length(L) of
                          N when (N =< 2) ->  throw("Too few files in root_path. Aborting."),
                                              error ;
                          _               -> ok
                     end.

%%-------------------------------------------------------------------------
%% @doc Create debian-binary file.
%% @end
%%-------------------------------------------------------------------------
-spec deb_version(list(), list()) -> ok | error .

deb_version(T, V) -> case file:write_file(filename:join(T, "debian-binary"), V) of
                          ok          -> ok ;
                          {error, R}  -> throw("Cannot create debian-binary file : " ++ atom_to_list(R)), error
                     end.

%%-------------------------------------------------------------------------
%% @doc Create data.tar.gz .
%%      Excluding DEBIAN and TmpDir
%% @end
%%-------------------------------------------------------------------------
-spec deb_data(list(), list(), list()) -> ok.

deb_data(T, R, S) ->  
                        % List all files under RootDir as CWD
                        {ok, Cur}  = file:get_cwd(),
                        ok         = file:set_cwd(R),
                        TB         = filename:basename(T),
                        Raw        = filelib:wildcard("*"),
                        Net        = lists:filter(fun(X) -> ((X =/= "DEBIAN") and (X =/= "debian")and (X =/= TB) and (X =/="debian.deb")) end, Raw),
                        % All files under Net directory list
                        Data       = lists:foldl(fun(D, Acc) -> Acc ++ filelib:fold_files(D, ".*", true, fun(F, A) -> A ++ [F] end , []) end, [], Net),
                        % Tar
                        Tar        = filename:join(T, "data.tar"),
                        ok         = erl_tar:create(Tar, lists:sort(Data)),
                        % Change Owner/Group in Tar and gzip
                        {ok, Bin}  = file:read_file(Tar),
                        {ok, Gzip} = swab:sync(S, Bin), 
                        ok         = file:write_file(filename:join(T, "data.tar.gz"), Gzip),
                        ok         = file:delete(Tar),
                        ok         = file:set_cwd(Cur).

%%-------------------------------------------------------------------------
%% @doc Create control.tar.gz .
%% @end
%%-------------------------------------------------------------------------
-spec deb_control(list(), list()) -> ok.

deb_control(T, D) -> % List all files under RootDir/DEBIAN as CWD
                     {ok, Cur}  = file:get_cwd(),
                     ok         = file:set_cwd(D),
                     F       = filename:join(T, "control.tar"),
                     List    = filelib:wildcard("*"),
                     ok      = erl_tar:create(F, List),
                     {ok, B} = file:read_file(F),
                     {ok, G} = swab:sync([{tar, fakeroot}, {convert, gzip}], B),
                     ok      = file:write_file(F ++ ".gz", G),
                     ok      = file:delete(F),
                     ok      = file:set_cwd(Cur).

%%-------------------------------------------------------------------------
%% @doc Create Debian package .
%% @end
%%-------------------------------------------------------------------------
-spec deb_pack(list()) -> list().

deb_pack(T) -> 
               F  = filename:join(T,"debian.deb"),
               B  = filename:join(T,"debian-binary"),
               C  = filename:join(T,"control.tar.gz"),
               D  = filename:join(T,"data.tar.gz"),
               ok = file:change_mode(B, 8#00644),
               ok = file:change_mode(C, 8#00644),
               ok = file:change_mode(D, 8#00644),
               ok = edgar:create(F, [B, C, D], [fakeroot]),
               ok = file:delete(B),
               ok = file:delete(C),
               ok = file:delete(D),
               filename:join(T, F).

%%-------------------------------------------------------------------------
%% @doc Move package to root path .
%% @end
%%-------------------------------------------------------------------------
-spec deb_move(list(), list()) -> ok.

deb_move(D, R) -> ok = file:rename(D, filename:join(R, filename:basename(D))).




