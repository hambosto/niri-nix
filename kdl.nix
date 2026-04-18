{ lib, ... }:
let
  foldArgs =
    lib.foldl
      (
        acc: arg:
        if lib.isAttrs arg then
          acc // { properties = acc.properties // arg; }
        else
          acc // { arguments = acc.arguments ++ [ arg ]; }
      )
      {
        arguments = [ ];
        properties = { };
      };

  node = name: args: children: {
    inherit name children;
    inherit (foldArgs (lib.toList args)) arguments properties;
  };

  plain = name: node name [ ];
  leaf = name: args: node name args [ ];
  flag = name: node name [ ] [ ];

  magicLeaf = nodeName: {
    ${nodeName} = [ ];
    __functor = self: arg: self // { ${nodeName} = self.${nodeName} ++ lib.toList arg; };
  };

  bareIdentRe = "[A-Za-z][A-Za-z0-9+-]*|[+-]|[+-][A-Za-z+-][A-Za-z0-9+-]*";
  serializeString = lib.flip lib.pipe [
    (lib.escape [
      "\\"
      "\""
    ])
    (lib.replaceStrings [ "\n" ] [ "\\n" ])
    (s: "\"${s}\"")
  ];

  serializeIdent = v: if lib.strings.match bareIdentRe v != null then v else serializeString v;
  serializeValue =
    v:
    {
      string = serializeString;
      path = serializeString;
      int = toString;
      float = toString;
      bool = b: if b then "true" else "false";
      null = lib.const "null";
    }
    .${builtins.typeOf v}
    v;

  serializeProp = { name, value }: "${serializeIdent name}=${serializeValue value}";

  indent = "    ";

  shouldCollapse =
    children:
    let
      n = lib.length children;
    in
    n == 0 || (n == 1 && shouldCollapse (lib.head children).children);

  serializeNode = serializeNodeWith "";
  serializeNodeWith =
    pfx:
    {
      name,
      arguments,
      properties,
      children,
    }:
    pfx
    + lib.concatStringsSep " " (
      lib.flatten [
        (serializeIdent name)
        (map serializeValue arguments)
        (map serializeProp (lib.attrsToList properties))
        (
          if children == [ ] then
            [ ]
          else if shouldCollapse children then
            "{ ${serializeNodes children}; }"
          else
            "{\n${serializeNodesWith (pfx + indent) children}\n${pfx}}"
        )
      ]
    );

  serializeNodes = serializeNodesWith "";
  serializeNodesWith =
    pfx:
    lib.flip lib.pipe [
      (map (serializeNodeWith pfx))
      (lib.concatStringsSep "\n")
    ];

  kdlValue = lib.types.nullOr (
    lib.types.oneOf [
      lib.types.str
      lib.types.int
      lib.types.float
      lib.types.bool
    ]
  );

  kdlNode = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      arguments = lib.mkOption {
        type = lib.types.listOf kdlValue;
        default = [ ];
      };
      properties = lib.mkOption {
        type = lib.types.attrsOf kdlValue;
        default = { };
      };
      children = lib.mkOption {
        type = kdlDocument;
        default = [ ];
      };
    };
  };

  kdlLeaf = lib.mkOptionType {
    name = "kdl-leaf";
    description = "kdl leaf";
    descriptionClass = "noun";
    check = v: lib.isAttrs v && lib.length (builtins.attrNames (removeAttrs v [ "__functor" ])) == 1;
    merge = lib.mergeUniqueOption {
      message = "";
      merge =
        _loc: defs:
        let
          def = builtins.head defs;
          name = builtins.head (builtins.attrNames (removeAttrs def.value [ "__functor" ]));
        in
        {
          ${name} = kdlArgs.merge ([ ] ++ [ name ]) [
            {
              inherit (def) file;
              value = def.value.${name};
            }
          ];
        };
    };
  };

  kdlArgs =
    let
      arg = lib.types.either (lib.types.attrsOf kdlValue) kdlValue;
      args = lib.types.either (lib.types.listOf arg) arg;
    in
    lib.mkOptionType {
      name = "kdl-args";
      description = "kdl arguments";
      descriptionClass = "noun";
      inherit (lib.types.uniq args) check merge;
    };

  kdlNodes = lib.types.listOf kdlNode // {
    name = "kdl-nodes";
    description = "kdl nodes";
    descriptionClass = "noun";
  };

  kdlDocument = lib.mkOptionType {
    name = "kdl-document";
    description = "kdl document";
    descriptionClass = "noun";
    check = v: builtins.isList v || builtins.isAttrs v;
    merge =
      loc: defs:
      kdlNodes.merge loc (
        map (
          def:
          let
            normalized = lib.remove null (lib.flatten def.value);
          in
          {
            inherit (def) file;
            value =
              lib.warnIf (def.value != normalized)
                "kdl document defined in `${def.file}` for `${lib.showOption loc}` is not normalized. \
             Please ensure it is a flat list of nodes."
                normalized;
          }
        ) defs
      );
  };

in
{
  inherit
    node
    plain
    leaf
    flag
    ;
  magicLeaf = magicLeaf;

  serialize = {
    node = serializeNode;
    nodeWith = serializeNodeWith;
    nodes = serializeNodes;
    nodesWith = serializeNodesWith;
    value = serializeValue;
    ident = serializeIdent;
    prop = serializeProp;
  };

  types = {
    inherit
      kdlValue
      kdlNode
      kdlNodes
      kdlLeaf
      kdlArgs
      kdlDocument
      ;
  };
}
