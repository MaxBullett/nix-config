# domains/audio/multi-headphone.nix
#
# Ephemeral multi-headphone audio. Creates a PipeWire combine sink at runtime
# via pipewire-pulse's module-combine-sink, holds it for the session, and
# tears it down on exit. Nothing is written to disk, nothing survives a reboot.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.domains.audio.multi-headphone;

  multi-headphone = pkgs.writeShellApplication {
    name = "multi-headphone";

    runtimeInputs = with pkgs; [
      bluez # bluetoothctl
      gum # TUI
      jq # parsing pactl -f json
      pulseaudio # pactl
      pipewire
    ];

    text = ''
      SINK_NAME="multi_headphone"
      SINK_DESC="Multi-Headphone Mode"
      MODULE_ID=""
      PREV_DEFAULT=""

      # ---------------------------------------------------------------- utils

      say() { gum style --foreground 4 "  $*"; }
      warn() { gum style --foreground 3 "  $*"; }
      die() { gum style --foreground 1 "  $*"; exit 1; }

      pw_snapshot() { pw-dump; }

      bt_sink_names() {
        pw_snapshot | jq -r '
          .[] | select(.type == "PipeWire:Interface:Node") | .info.props
          | select(.["media.class"] == "Audio/Sink")
          | select(.["node.name"] // "" | startswith("bluez_output"))
          | .["node.name"]
        '
      }

      sink_label() {
        pw_snapshot | jq -r --arg n "$1" '
          .[] | select(.type == "PipeWire:Interface:Node") | .info.props
          | select(.["node.name"] == $n)
          | "\(.["node.description"] // .["node.name"])  [\(.["api.bluez5.codec"] // "codec?")]"
        '
      }

      sink_codec() {
        pw_snapshot | jq -r --arg n "$1" '
          .[] | select(.type == "PipeWire:Interface:Node") | .info.props
          | select(.["node.name"] == $n)
          | .["api.bluez5.codec"] // "unknown"
        '
      }

      # ------------------------------------------------------------- teardown

      cleanup() {
        echo
        if [ -n "$MODULE_ID" ]; then
          say "Unloading combine sink (module $MODULE_ID)..."
          pactl unload-module "$MODULE_ID" || true
        fi
        if [ -n "$PREV_DEFAULT" ]; then
          pactl set-default-sink "$PREV_DEFAULT" || true
          say "Default output restored to $PREV_DEFAULT"
        fi
      }
      trap cleanup EXIT INT TERM

      # ------------------------------------------------- connect if necessary

      connect_paired() {
        local choices mac
        # bluetoothctl output: "Device AA:BB:CC:DD:EE:FF Some Name"
        mapfile -t choices < <(bluetoothctl devices Paired \
          | sed 's/^Device //')
        [ ''${#choices[@]} -eq 0 ] && die "No paired Bluetooth devices found."

        local picked
        picked=$(printf '%s\n' "''${choices[@]}" \
          | gum choose --no-limit --header "Connect which headphones?") || return 1

        while IFS= read -r line; do
          [ -z "$line" ] && continue
          mac=''${line%% *}
          echo "  Connecting $mac..."
          bluetoothctl connect "$mac" >/dev/null 2>&1 || warn "Failed to connect $mac"
        done <<< "$picked"

        # Give WirePlumber a moment to expose the sinks.
        echo "  Waiting for audio sinks..."
        sleep 4
      }

      # ------------------------------------------------------------ main flow

      gum style --padding "1 2" \
        "Multi-Headphone Mode" "One stream, many ears, zero permanent config."

      mapfile -t available < <(bt_sink_names)

      if [ ''${#available[@]} -lt 2 ]; then
        warn "Only ''${#available[@]} Bluetooth sink(s) currently connected."
        if gum confirm "Connect more headphones now?"; then
          connect_paired || true
          mapfile -t available < <(bt_sink_names)
        fi
      fi

      [ ''${#available[@]} -lt 2 ] && die "Need at least 2 Bluetooth sinks. Got ''${#available[@]}."

      # Pick which sinks to combine. Labels are shown, names resolved after.
      declare -A label_to_name=()
      labels=()
      for name in "''${available[@]}"; do
        label="$(sink_label "$name")"
        label_to_name["$label"]="$name"
        labels+=("$label")
      done

      selected_labels=$(printf '%s\n' "''${labels[@]}" \
        | gum choose --no-limit --header "Combine which outputs?") \
        || die "Cancelled."

      slaves=()
      codecs=()
      while IFS= read -r label; do
        [ -z "$label" ] && continue
        n="''${label_to_name[$label]}"
        slaves+=("$n")
        codecs+=("$(sink_codec "$n")")
      done <<< "$selected_labels"

      [ ''${#slaves[@]} -lt 2 ] && die "Pick at least two."

      # Warn on codec mismatch: main cause of audible skew between headphones.
      first_codec="''${codecs[0]}"
      mismatch=0
      for c in "''${codecs[@]}"; do
        [ "$c" != "$first_codec" ] && mismatch=1
      done
      if [ "$mismatch" -eq 1 ]; then
        warn "Codec mismatch: ''${codecs[*]}"
        warn "Expect a fixed offset between outputs. See notes in this module."
        gum confirm "Continue anyway?" || exit 0
      fi

      # -------------------------------------------------------- load the sink

      PREV_DEFAULT="$(pactl get-default-sink)"

      slave_csv=$(IFS=,; echo "''${slaves[*]}")

      if ! MODULE_ID=$(pactl load-module module-combine-sink \
            sink_name="$SINK_NAME" \
            slaves="$slave_csv" \
            sink_properties="device.description='$SINK_DESC'" 2>&1); then
        warn "$MODULE_ID"
        MODULE_ID=""
        die "Failed to create combine sink."
      fi

      pactl set-default-sink "$SINK_NAME"

      # Drag anything already playing onto the combined sink.
      while read -r id _; do
        [ -z "$id" ] && continue
        pactl move-sink-input "$id" "$SINK_NAME" 2>/dev/null || true
      done < <(pactl list sink-inputs short)

      gum style --padding "1 2" \
        "Active: $SINK_DESC" \
        "Outputs: ''${#slaves[@]}   Codec: ''${codecs[*]}" \
        "" \
        "Volume is per-headphone, use the buttons on each." \
        "Ctrl-C to tear down."

      # Hold. Re-assert default only if something else grabbed it, which the
      # bluetooth autoSwitch rule will do on any reconnect.
      while true; do
        current="$(pactl get-default-sink 2>/dev/null)"
        if [ "$current" != "$SINK_NAME" ] && [[ "$current" == bluez_output* ]]; then
          pactl set-default-sink "$SINK_NAME" 2>/dev/null || true
        fi
        sleep 3
      done
    '';
  };
in
{
  options.domains.audio.multi-headphone = {
    enable = mkEnableOption "multi-headphone shared audio CLI";

    package = mkOption {
      type = types.package;
      default = multi-headphone;
      readOnly = true;
      description = "The multi-headphone script package.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
