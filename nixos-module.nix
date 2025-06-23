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

      admin = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "Xnode";
          example = "Samuel";
          description = ''
            The name of the Open WebUI admin user.
          '';
        };

        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "xnode@example.com";
          description = ''
            The email of the Open WebUI admin user. If unset, authentication is disabled.
          '';
        };

        password = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "hunter12";
          description = ''
            The password of the Open WebUI admin user. If unset, authentication is disabled.
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

  config = lib.mkIf cfg.enable (
    let
      use_auth = cfg.admin.email != null && cfg.admin.password != null;
    in
    {
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
          }
          (lib.mkIf (cfg.defaultModel != null) {
            DEFAULT_MODELS = cfg.defaultModel;
          })
          (lib.mkIf (!use_auth) {
            WEBUI_AUTH = "False";
          })
          (lib.mkIf cfg.search.enable {
            ENABLE_RAG_WEB_SEARCH = "True";
            RAG_WEB_SEARCH_ENGINE = "searxng";
            SEARXNG_QUERY_URL = "http://localhost:8888/search?q=<query>";
          })
        ];
      };

      systemd.services.open-webui-admin-update = {
        description = "Update auth settings for open-webui";
        wantedBy = [
          "multi-user.target"
          "open-webui.service"
        ];
        after = [ "open-webui.service" ];
        bindsTo = [ "open-webui.service" ];
        serviceConfig = {
          Type = "exec";
          User = "open-webui";
          Group = "open-webui";
          Restart = "on-failure";
          RestartSec = "5s";
          RestartMaxDelaySec = "2h";
          RestartSteps = "10";
        };
        script =
          if use_auth then
            # Wipe all users and add admin user
            let
              database = "${pkgs.sqlite}/bin/sqlite3 /var/lib/open-webui/webui.db";
              htpasswd = "${pkgs.apacheHttpd}/bin/htpasswd";
            in
            ''
              chmod 777 /var/lib/open-webui/webui.db
              ${database} "DELETE FROM auth;"
              ${database} "DELETE FROM user;"
              ${database} "INSERT INTO auth (id, active, email, password) VALUES ('nix', true, '${cfg.admin.email}', '$(${htpasswd} -bnBC 10 "" ${cfg.admin.password} | tr -d ":\n")');"
              ${database} "INSERT INTO user (id, name, email, role, profile_image_url, last_active_at, updated_at, created_at) VALUES ('nix', '${cfg.admin.name}', '${cfg.admin.email}', 'admin', '/user.png', 0, 0, 0);"
            ''
          else
            # Remove any existing users (required for auth to be disabled)
            let
              database = "${pkgs.sqlite}/bin/sqlite3 /var/lib/open-webui/webui.db";
            in
            ''
              chmod 777 /var/lib/open-webui/webui.db
              ${database} "DELETE FROM auth;"
              ${database} "DELETE FROM user;"
            '';
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
    }
  );
}
