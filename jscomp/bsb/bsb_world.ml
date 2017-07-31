(* Copyright (C) 2017- Authors of BuckleScript
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


let (//) = Ext_filename.combine

let install_targets ~cmdline_build_kind cwd (config : Bsb_config_types.t option) =
  (** TODO: create the animation effect *)
  let install ~destdir file = 
    if Bsb_file.install_if_exists ~destdir file  then 
      begin 
        ()
        (*Format.pp_print_string Format.std_formatter "=> "; 
        Format.pp_print_string Format.std_formatter destdir;
        Format.pp_print_string Format.std_formatter "<= ";
        Format.pp_print_string Format.std_formatter file ;
        Format.pp_print_string Format.std_formatter "\r"; 
        Format.pp_print_flush Format.std_formatter ();*)
      end
  in
  match config with 
  | None -> ()
  | Some {files_to_install} -> 
    let nested = begin match cmdline_build_kind with
      | Bsb_config_types.Js -> "js"
      | Bsb_config_types.Bytecode -> "bytecode"
      | Bsb_config_types.Native -> "native"
    end in
    let destdir = cwd // Bsb_config.lib_ocaml // nested in (* lib is already there after building, so just mkdir [lib/ocaml] *)
    if not @@ Sys.file_exists destdir then begin Bsb_build_util.mkp destdir  end;
    begin
      Format.fprintf Format.std_formatter "@{<info>Installing started@}@.";
      (*Format.pp_print_flush Format.std_formatter ();*)
      String_hash_set.iter (fun x ->
          install ~destdir (cwd // x ^  Literals.suffix_ml) ;
          install ~destdir (cwd // x ^  Literals.suffix_re) ;
          install ~destdir (cwd // x ^ Literals.suffix_mli) ;
          install ~destdir (cwd // x ^  Literals.suffix_rei) ;

          (* The library file generated by bsb for each external dep has the 
             same name because they're in different folders and because it makes
             linking easier. *)
          install ~destdir (cwd // Bsb_config.lib_bs // nested // Literals.library_file ^ Literals.suffix_a) ;
          install ~destdir (cwd // Bsb_config.lib_bs // nested // Literals.library_file ^ Literals.suffix_cma) ;
          install ~destdir (cwd // Bsb_config.lib_bs // nested // Literals.library_file ^ Literals.suffix_cmxa) ;

          install ~destdir (cwd // Bsb_config.lib_bs // nested // x ^ Literals.suffix_cmi) ;
          install ~destdir (cwd // Bsb_config.lib_bs // nested // x ^ Literals.suffix_cmj) ;
          install ~destdir (cwd // Bsb_config.lib_bs // nested // x ^ Literals.suffix_cmt) ;
          install ~destdir (cwd // Bsb_config.lib_bs // nested // x ^ Literals.suffix_cmti) ;
        ) files_to_install;
      Format.fprintf Format.std_formatter "@{<info>Installing finished@} @.";
    end



let build_bs_deps cwd ~root_project_dir ~cmdline_build_kind deps entry =
  let bsc_dir = Bsb_build_util.get_bsc_dir cwd in
  let ocaml_dir = Bsb_build_util.get_ocaml_dir bsc_dir in
  let vendor_ninja = bsc_dir // "ninja.exe" in
  let all_external_deps = ref [] in
  let all_ocamlfind_dependencies = ref [] in
  let all_clibs = ref [] in
  Bsb_build_util.walk_all_deps  cwd
    (fun {top; cwd} ->
       if not top then
         begin 
           let config_opt = Bsb_ninja_regen.regenerate_ninja 
             ~is_top_level:false
             ~no_dev:true
             ~generate_watch_metadata:false
             ~override_package_specs:(Some deps) 
             ~root_project_dir
             ~forced:true
             ~cmdline_build_kind
             cwd bsc_dir ocaml_dir in (* set true to force regenrate ninja file so we have [config_opt]*)
           let config = begin match config_opt with 
            | None ->
            (* TODO(sansouci): optimize this to _just_ read the static_libraries field. *)
              Bsb_config_parse.interpret_json 
                ~override_package_specs:(Some deps)
                ~bsc_dir
                ~generate_watch_metadata:false
                ~no_dev:true
                ~compilation_kind:cmdline_build_kind
                cwd
            | Some config -> config
           end in
           (* Append at the head for a correct topological sort. 
              walk_all_deps does a simple DFS, so all we need to do is to append at the head of 
              a list to build a topologically sorted list of external deps.*)
            if List.mem cmdline_build_kind Bsb_config_types.(config.allowed_build_kinds) then begin
              all_clibs := (List.rev Bsb_config_types.(config.static_libraries)) @ !all_clibs;
              all_ocamlfind_dependencies := Bsb_config_types.(config.ocamlfind_dependencies) @ !all_ocamlfind_dependencies;
              let nested = begin match cmdline_build_kind with 
              | Bsb_config_types.Js -> "js"
              | Bsb_config_types.Bytecode -> 
                all_external_deps := (cwd // Bsb_config.lib_ocaml // "bytecode") :: !all_external_deps;
                "bytecode"
              | Bsb_config_types.Native -> 
                all_external_deps := (cwd // Bsb_config.lib_ocaml // "native") :: !all_external_deps;
                "native"
              end in
             Bsb_unix.run_command_execv
               {cmd = vendor_ninja;
                cwd = cwd // Bsb_config.lib_bs // nested;
                args  = [|vendor_ninja|]
               };
             (* When ninja is not regenerated, ninja will still do the build, 
                still need reinstall check
                Note that we can check if ninja print "no work to do", 
                then don't need reinstall more
             *)
             install_targets ~cmdline_build_kind cwd config_opt;
           end
         end
    );
  (* Reverse order here so the leaf deps are at the beginning *)
  (List.rev !all_external_deps, List.rev !all_clibs, List.rev !all_ocamlfind_dependencies)


let get_package_specs_and_entries cmdline_build_kind =
  let (dep, entries) = begin match Bsb_config_parse.package_specs_and_entries_from_bsconfig () with
    (* Entries cannot be empty, we always use a default under-the-hood. *)
    | dep, [] -> assert false
    | dep, entries -> (dep, entries)
  end in
  let filtered_entries = List.filter (fun e -> match e with 
    | Bsb_config_types.JsTarget _ -> cmdline_build_kind = Bsb_config_types.Js
    | Bsb_config_types.BytecodeTarget _ -> cmdline_build_kind = Bsb_config_types.Bytecode
    | Bsb_config_types.NativeTarget _ -> cmdline_build_kind = Bsb_config_types.Native
  ) entries in
  let build_kind_string = begin match cmdline_build_kind with
  | Bsb_config_types.Js -> "js"
  | Bsb_config_types.Bytecode -> "bytecode"
  | Bsb_config_types.Native -> "native"
  end in
  if filtered_entries = [] then begin 
    failwith @@ "Found no 'entries' to compile to '" ^ 
    build_kind_string ^ "' in the bsconfig.json"
  end else (dep, List.hd filtered_entries)

let make_world_deps cwd ~root_project_dir ~cmdline_build_kind (* (config : Bsb_config_types.t option) *) =
  print_endline "\nMaking the dependency world!";
  let (deps, entry) = get_package_specs_and_entries cmdline_build_kind in
  build_bs_deps cwd ~root_project_dir ~cmdline_build_kind deps entry
