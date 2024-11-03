
import 'package:objd/core.dart';
import 'lib/main.dart';

void main(List<String> args){
  createProject(Project(name: "hide_and_seek", generate: 
    Pack(
      name: "hide_and_seek",
      files: files,
      main: tick,
      load: load
    )
  ));
}