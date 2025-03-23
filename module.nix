{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  options.services.albyHub = {
    enable = mkEnableOption "Alby Hub service";

    package = mkOption {
      type = types.package;
      default = config.albyHub.pkgs.albyHub;
      description = "The AlbyHub Nix package";
    };

    relay = mkOption {
      type = types.str;
      default = "wss://relay.getalby.com/v1";
      description = "Relay URL";
    };

    jwtSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "JWT secret string. If not provided, a random one will be generated at runtime.";
    };

    databaseUri = mkOption {
      type = types.str;
      default = "$XDG_DATA_HOME/albyhub/nwc.db";
      description = "SQLite database filename";
    };

    port = mkOption {
      type = types.int;
      default = 8029;
      description = "Port on which the app should listen";
    };

    workDir = mkOption {
      type = types.str;
      default = "$XDG_DATA_HOME/albyhub";
      description = "Directory to store NWC data files";
    };

    logLevel = mkOption {
      type = types.int;
      default = 4;
      description = "Log level for the application (higher is more verbose)";
    };

    autoUnlockPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Unlock password to auto-unlock Alby Hub on startup";
    };

    lnd = {
      enable = mkEnableOption "Enable LND as a backend.";
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "localhost:10009";
        description = "The LND gRPC address";
      };
      certPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tls.cert";
        description = "Path to the LND TLS certificate";
      };
      macaroonPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "admin.macaroon";
        description = "Path to the LND admin macaroon file";
      };
    };

    ldkEsploraServer = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Esplora server to use instead of the default Alby esplora instance.";
    };

    user = mkOption {
      type = types.str;
      default = "alby";
      description = "The user as which to run albyhub.";
    };

    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run albyhub.";
    };
  };

  cfg = config.services.albyHub;
in
{
  inherit options;

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.workDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.albyhub = rec {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        RELAY = cfg.relay;
        DATABASE_URI = cfg.databaseUri;
        PORT = toString cfg.port;
        WORK_DIR = cfg.workDir;
        LOG_LEVEL = toString cfg.logLevel;
        JWT_SECRET = mkIf (cfg.jwtSecret != null) cfg.jwtSecret;
        AUTO_UNLOCK_PASSWORD = mkIf (cfg.autoUnlockPassword != null) cfg.autoUnlockPassword;
        LDK_ESPLORA_SERVER = mkIf (cfg.ldkEsploraServer != null) cfg.ldkEsploraServer;
        LN_BACKEND_TYPE = mkIf (cfg.lnd.enable) "LND";
        LND_ADDRESS = mkIf (cfg.lnd.address != null) cfg.lnd.address;
        LND_CERT_FILE = mkIf (cfg.lnd.certPath != null) cfg.lnd.certPath;
        LND_MACAROON_FILE = mkIf (cfg.lnd.macaroonPath != null) cfg.lnd.macaroonPath;
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/alby-hub";
        Restart = "always";
        RestartSec = "1s";
      };
    };
  };
}
