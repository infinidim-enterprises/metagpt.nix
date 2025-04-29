{ config, lib, pkgs, ... }:
let
  inherit (lib // builtins)
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    mkPackageOption
    literalExpression;

  cfg = config.programs.metagpt;
  yaml = pkgs.formats.yaml { };

in
{
  options.programs.metagpt = {
    enable = mkEnableOption "Enable metagpt";
    package = mkPackageOption pkgs "metagpt" { };
    settings = mkOption {
      type = yaml.type;
      default = { };
      example = literalExpression ''{ llm.api_type = "openrouter"; }'';
      description = ''
        Settings for metagpt.
      '';
    };

  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [ cfg.package ];
      home.file.".metagpt/config2.yaml".source = yaml.generate "metagpt_config" cfg.settings;
    }
  ]);

}
