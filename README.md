# Project Alias 2.0

<p float="left">
<img src="imgs/alias.jpg" width="49%"> <img src="imgs/short_alias_explained.gif" width="49%">
</p>

[![Python 3.13](https://img.shields.io/badge/python-3.13-blue.svg)](https://www.python.org/downloads/release/python-3130/)
![License: GPL](https://img.shields.io/badge/license-GPL-blue)

Project Alias is an open-source parasite to hack smart home devices. Train custom wake-up names and commands for your devices while disturbing their built-in microphone with noise. Introduce false labelling to their algorithm by changing gender or nationality. Read more about the project **[here](http://bjoernkarmann.dk/project_alias)**

This repository has been updated to 2.0. Find the old version under the branches. This fork adds a Nix flake and a NixOS module that deploy the app on a Raspberry Pi.

### 2.0 Features
- Multiple wake-up words
- Custom commands to be told to the assistant
- Change gender and language of Alias
- Adjust wake-up word sensitivity and delay
- New wake-up word detection powered by **[Pocketsphinx](https://cmusphinx.github.io/)**

### Build Guide
For the complete step-by-step guide and 3D files see our **[Instructables](https://www.instructables.com/id/Project-Alias)**


### Installation (NixOS)

This fork packages Project Alias as a Nix flake with a NixOS module. Only `aarch64-linux` targets are built (newer Pis, Pi 4/5); there are no x86_64 packages for the app.

Prerequisites:

- A Raspberry Pi running NixOS on `aarch64-linux`
- A **[ReSpeaker](http://wiki.seeedstudio.com/ReSpeaker_2_Mics_Pi_HAT/)** microphone HAT attached
- Wireless networking already configured in your NixOS configuration (the module does not manage it)

Add the flake input and import the module in your `flake.nix` / `configuration.nix`:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    project-alias.url = "github:jayRovacsek/project_alias";
  };

  outputs = { self, nixpkgs, project-alias, ... }: {
    nixosConfigurations.mypi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        project-alias.nixosModules.project-alias
      ];
    };
  };
}
```

```nix
# configuration.nix
{
  services.project-alias.enable = true;
}
```

Enabling the module starts two systemd units:

- `project-alias-iptables.service` — a oneshot NAT redirect (port 80 to the
  app port) that replaces the old rc.local/sleep.py behaviour. This is the
  only privileged unit.
- `project-alias.service` — the untrusted Flask app, run as its own user and
  heavily sandboxed (no new privileges, empty capability bounding set, strict
  device allowlist for the HAT, confined to its state and config directories).

The Seeed ReSpeaker kernel driver is built and loaded by the module as well,
so no manual driver installation is needed.

#### Module options

Option | Description | Default
--- | --- | ---
`enable` | Enable the Project Alias service | `false`
`package` | The Project Alias application package | `packages.aarch64-linux.project-alias`
`driverPackage` | Kernel module for the ReSpeaker microphone HAT | `packages.aarch64-linux.seeed-voicecard`
`dataDir` | Directory for stateful training data | `/var/lib/project-alias`
`configDir` | Directory for stateful application configuration | `/etc/project-alias`
`port` | TCP port the application listens on | `5050`


#### Development

From a checkout of this repository:

- `nix develop` — devshell with ruff, nixfmt, statix, deadnix, gitlint and a
  pre-commit startup hook
- `nix flake check` — runs the lint checks (ruff, nixfmt, statix, deadnix)
- `nix build .#tests.x86_64-linux.basic` — boots a minimal NixOS VM that
  validates the module's operational state (units active, sandboxing, state
  directories, NAT rule lifecycle). Requires a KVM-capable host.


### Start using Alias 🍄

1. Configure your Alias by connecting to its local wifi from your phone.
<br>ssid: **Project Alias**  psw: **cordyceps**.

2. Open a browser and enter the url: **alias.local** to interface with Alias.

3. From the interface you can now add new wake-up word / commands or edit existing ones. Save any changes by clicking the **Update Alias** button. We recommend to experiment with different words and sensitivity levels to find what works best for you.

4. To configure the settings, click the icon in the upper right corner. Here you can adjust and customize the noise, language, gender, volume and delay.
  *Tip: If you write the full command into alias you can create shortcuts and new functions. E.g. By calling 'Funky Time' you
  could have Alias whisper 'Ok Google, play some funky music on Spotify'.*


![User interface](imgs/ui.jpg)



### Settings ⚙️

Setting | Description | Default
--- | --- | ---
Noise | This will turn on/off the looping noise| `ON`
Gender | Choose what gender the assistant should perceive when Alias whispers commands. By changing to the opposite gender you will able to introduce false labelling into the assistants algorithm. This confusion might lead to interesting interactions and answers. Note, this only changes the voice of Alias itself, and will therefore only have an effect with long commands. | `Male`
Language | Change the language Alias uses to speak to your assistant. This is to introduce another layer of noise that makes the system label you with a different nationality. To use this feature the command for the assistant has to be written in the same language. | `English`
Volume | Change the volume of the speakers. This needs to be loud enough for the noise to block the assistant, but low enough not to be audible. Settings can vary by acoustics and ambient inferences. | `39`
Noise Delay | This increase the delay after the wake-up word has been activated to restart the noise again. This is used as a noise free window, when asking the assistant a question. It should be set to match the appropriate time interval needed for the maximum length of a conversation. | `10s`
Sensitivity | This setting changes the sensitivity of the wake-up word detection. This setting is found on the front page for each command. The lower the number the less sensitive. | `20`


### Change assistant

If you are using **Google Home** or an **Amazon Alexa** the way you change the wake up word is simply by writing it in the responds field in the Alias web-app


### Contributors
Made by **[Bjørn Karmann](http://bjoernkarmann.dk)** and **[Tore Knudsen](http://www.toreknudsen.dk/)**


### License

This project is licensed under the GPL License - see the LICENSE.GPL file in the root folder
