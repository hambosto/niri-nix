{ }:
let
  year = builtins.substring 0 4;
  month = builtins.substring 4 2;
  day = builtins.substring 6 2;
  fmtDate = raw: "${year raw}-${month raw}-${day raw}";
in
{
  packageVersion = src: "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";
  versionString = src: "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";
}
