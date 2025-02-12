{
  nixpkgs,
  nixpkgs-stable,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.xnode-ai-chat;
  pkgs-unstable = import nixpkgs { system = pkgs.system; };
  pkgs-stable = import nixpkgs-stable { system = pkgs.system; };
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
      services.ollama = {
        enable = true;
        package = pkgs-unstable.ollama;
        loadModels = lib.optional (cfg.defaultModel != null) cfg.defaultModel;
      };

      services.open-webui = {
        enable = true;
        package = pkgs-unstable.open-webui;
        environment =
          {
            ANONYMIZED_TELEMETRY = "False";
            DO_NOT_TRACK = "True";
            SCARF_NO_ANALYTICS = "True";

            ENV = "prod";
            ENABLE_SIGNUP = "False";
          }
          // lib.attrsets.optionalAttrs (cfg.defaultModel != null) {
            DEFAULT_MODELS = cfg.defaultModel;
          }
          // lib.attrsets.optionalAttrs (!use_auth) {
            WEBUI_AUTH = "False";
          }
          // lib.attrsets.optionalAttrs cfg.search.enable {
            ENABLE_RAG_WEB_SEARCH = "True";
            RAG_WEB_SEARCH_ENGINE = "searxng";
            SEARXNG_QUERY_URL = "http://localhost:8888/search?q=<query>";
          };
      };

      systemd.services.open-webui.postStart =
        if use_auth then
          # Wipe all users and add admin user
          let
            database = "${pkgs-unstable.sqlite}/bin/sqlite3 /var/lib/open-webui/webui.db";
            htpasswd = "${pkgs-unstable.apacheHttpd}/bin/htpasswd";
          in
          ''
            sleep 5
            ${database} "DELETE FROM auth;"
            ${database} "DELETE FROM user;"
            ${database} "INSERT INTO auth (id, active, email, password) VALUES ('nix', true, '${cfg.admin.email}', '$(${htpasswd} -bnBC 10 "" ${cfg.admin.password} | tr -d ":\n")');"
            ${database} "INSERT INTO user (id, name, email, role, profile_image_url, last_active_at, updated_at, created_at) VALUES ('nix', '${cfg.admin.name}', '${cfg.admin.email}', 'admin', '/user.png', 0, 0, 0);"
          ''
        else
          # Remove any existing users (required for auth to be disabled)
          let
            database = "${pkgs-unstable.sqlite}/bin/sqlite3 /var/lib/open-webui/webui.db";
          in
          ''
            sleep 5
            ${database} "DELETE FROM auth;"
            ${database} "DELETE FROM user;"
          '';

      services.searx = {
        enable = cfg.search.enable;
        package = pkgs-unstable.searxng;
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
