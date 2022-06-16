{
  description = "ignite all nix'd up";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";

    home-manager.url = github:nix-community/home-manager;
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";

    # ignite-api.url = "github:CarolinaIgnites/igniteapi";
    # ignite-site.url = "github:NixOS/nixpkgs/nixos-21.11";
    # ignite-editor.url = "github:CarolinaIgnites/editFrame";

    ignite-api.url = "path:./igniteApi";
    ignite-editor.url = "path:./editFrame";
  };

  outputs = { self, nixpkgs, home-manager, ignite-editor, ignite-api, deploy-rs, ... }:
    let
      system = "x86_64-linux";
      # Add nixpkgs overlays and config here. They apply to system and home-manager builds.
      pkgs = import nixpkgs {
        inherit system;
      };
      sshKeys = [ ''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEztZBP8FKPbysbOIKprz0QVgTuhEdwUJ1sf2/aFcpUfy3aRml3v9GvzlkRD0waPPUYQ0vj/SZfYEqexvkbY7YeudycXPpleypwW58WJxjWTM/2uV+syK3ZpcRX/MyIISVMgmMDp2nthJtowMhyoyZWFYUJKbKEJ3mRAP7Yzrbf4slIdn1NWXzazSbsQqgDG7mww/kcO4Tq90QyPv5l7F2ulrVj3PLk59DKctUxALOlEzuSPSAUcCKqaxkjFyTJiaK1oUX+N4G9XYTLQ/4a8a93Nljm6T57msJqnVgPgXgk0RpHwZveZFfrFv4GUAM/uv0Tyf/Z9YooMSUDkP3U/6h ignitecs'' ];
    in
    {
      # systemd.services."ignite-setup" = {
      #   wantedBy = [ "container@ignite.service" ];
      #   script = ''
      #     mkdir -p /var/lib/ignite/per-user-{profile,gcroots}
      #   '';
      #   serviceConfig.Type = "oneshot";
      # };

      nixosConfigurations.container = nixpkgs.lib.nixosSystem
        {
          system = "x86_64-linux";
          modules =
            [
              # home-manager.nixosModules.home-manager
              ({ pkgs, ... }: {
                boot.isContainer = true;

                # Flakes need to be bootstrapped
                nix = {
                  package = pkgs.nixFlakes;
                  allowedUsers = [ "api" ];
                  trustedUsers = [ "root" ];

                  # The default is 03:15 for when these run.
                  gc.automatic = true;
                  optimise.automatic = true;
                  autoOptimiseStore = true;
                };

                system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
                systemd.services."home-manager-api" = {
                  preStart = ''
                    mkdir -p /nix/var/nix/{profiles,gcroots}/per-user/api
                    chown -R api /nix/var/nix/{profiles,gcroots}/per-user/api
                  '';
                  serviceConfig.PermissionsStartOnly = true;
                };

                services = {
                  openssh = {
                    enable = true;
                    permitRootLogin = "prohibit-password"; # distributed-build.nix requires it
                    passwordAuthentication = false;
                    allowSFTP = false;
                    ports = [ 8443 ];
                  };
                  fail2ban = {
                    enable = true;
                  };
                };

                # Network configuration.
                networking.useDHCP = false;
                networking.firewall.allowedTCPPorts = [ 80 443 8443 ];

                users.users.root.openssh.authorizedKeys.keys = sshKeys;
                users.users.api.openssh.authorizedKeys.keys = sshKeys;
                users.mutableUsers = false;
                users.users.api = {
                  isNormalUser = true;
                  shell = pkgs.bash;
                };

                # Enable a web server.
                services.nginx = {
                  enable = true;
                  virtualHosts."editor.ignite.code" = {
                    root = "${ignite-editor.defaultPackage.x86_64-linux}";
                    # TODO: Figure out ssl
                    # enableACME = true;
                    # forceSSL = true;
                  };
                  virtualHosts."api.ignite.code" = {
                    locations."/" = {
                      proxyPass = "http://127.0.0.1:5000";
                      extraConfig = ''
                        add_header 'Access-Control-Allow-Origin' '*';
                        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
                        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
                        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';
                        add_header Cache-Control "public, no-transform";
                        expires max;
                      '';
                    };
                    # TODO: Figure out ssl
                    # enableACME = true;
                    # forceSSL = true;
                  };
                };
              })
              # home-manager configuration
              home-manager.nixosModules.home-manager
              {
                home-manager.useUserPackages = true;
                home-manager.users.api = {
                  home.stateVersion = "21.11";
                  systemd.user.services.igniteapi = {
                    Unit = {
                      Description = "Runs the Ignite API";
                    };
                    Install = {
                      WantedBy = [ "default.target" ];
                    };
                    Service = {
                      ExecStart = "${ignite-api.defaultPackage.x86_64-linux}";
                    };
                  };

                  programs.home-manager.enable = true;
                  home.file.".home-manager-installed".text = "yes\n";
                  home.file."README.md".text = "it's alive?";
                };
                # systemd.user.services = [
                #   # redis
                #   {
                #     description = "systemd service unit configuration";
                #   }
                #   #services.igniteapi
                #   #services.batteryNotifier
                #   # igniteapi
                # ];
                # and custom systemd script
              }
            ];
        } // {
        privateNetwork = true;
        # Hmm. This needs to be local container specific.
        # systemd.tmpfiles.rules = [
        #   "d /nix/var/nix/{profiles,gcroots} - api - - -"
        # ];
        # bindMounts = {
        #   per-user-profile = {
        #     hostPath = "/var/lib/ignite/per-user-profile";
        #     mountPoint = "/nix/var/nix/profiles/per-user";
        #     isReadOnly = false;
        #   };
        #   per-user-gcroots = {
        #     hostPath = "/var/lib/ignite/per-user-gcroots";
        #     mountPoint = "/nix/var/nix/gcroots/per-user/api";
        #     isReadOnly = false;
        #   };
        #   "/nix/var/nix/profiles/per-user/root".isReadOnly = true;
        # };
        # Fix permissions on profile/gcroots directories before
        # home-manager activation.
      };

      deploy.nodes.ignite = {
        sshUser = "root";
        sshOpts = [ "-p" "8443" "-i" "~/.ssh/keys/ignite" ];
        hostname = "10.233.2.2";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.container;
            user = "root";
          };
          api = {
            sshUser = "api";
            user = "api";
            path = deploy-rs.lib.x86_64-linux.activate.custom ignite-api.defaultPackage.x86_64-linux "./bin/igniteapi";
          };
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
