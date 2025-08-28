{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.xnode-ai-chat;
in
{
  options = {
    services.xnode-ai-chat = {
      enable = lib.mkEnableOption "Enable the Xnode chat ai.";

      defaultModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "deepseek-r1";
        description = ''
          The model to pull for Ollama and to set as default in Open WebUI.
        '';
      };

      autoGenerate = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          example = false;
          description = ''
            Enable auto generation. On slow models this will have a significant performance impact.
          '';
        };
      };

      search = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          example = false;
          description = ''
            Enable search in Open WebUI.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable ({
    nixpkgs.config.allowUnfree = true;

    systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
    systemd.services.ollama.serviceConfig.ProtectHome = lib.mkForce false;
    systemd.services.ollama.serviceConfig.StateDirectory = [ "ollama/models" ];
    services.ollama = {
      enable = true;
      user = "ollama";
      loadModels = lib.mkIf (cfg.defaultModel != null) [ cfg.defaultModel ];
    };
    systemd.services.ollama-model-loader.serviceConfig.User = "ollama";
    systemd.services.ollama-model-loader.serviceConfig.Group = "ollama";
    systemd.services.ollama-model-loader.serviceConfig.DynamicUser = lib.mkForce false;

    users = {
      users."open-webui" = {
        isSystemUser = true;
        group = "open-webui";
      };
      groups."open-webui" = { };
    };
    systemd.services.open-webui.serviceConfig.User = lib.mkForce "open-webui";
    systemd.services.open-webui.serviceConfig.Group = lib.mkForce "open-webui";
    systemd.services.open-webui.serviceConfig.DynamicUser = lib.mkForce false;
    systemd.services.open-webui.serviceConfig.ProtectHome = lib.mkForce false;
    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      environment = lib.mkMerge [
        {
          WEBUI_URL = "http://${config.networking.hostName}.container:8080";
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";

          ENV = "prod";
          ENABLE_SIGNUP = "False";
          WEBUI_AUTH = "False";
        }
        (lib.mkIf (!cfg.autoGenerate.enable) {
          ENABLE_TITLE_GENERATION = "False";
          ENABLE_FOLLOW_UP_GENERATION = "False";
          ENABLE_AUTOCOMPLETE_GENERATION = "False";
          ENABLE_TAGS_GENERATION = "False";
        })
        (lib.mkIf (cfg.defaultModel != null) {
          DEFAULT_MODELS = cfg.defaultModel;
        })
        (lib.mkIf cfg.search.enable {
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://localhost:8888/search?q=<query>";
        })
      ];
    };

    services.searx = {
      enable = cfg.search.enable;
      settings = {
        server = {
          port = 8888;
          secret_key = "XNODE";
        };

        search = {
          formats = [
            "html"
            "json"
          ];
        };
      };
    };
  });
}
