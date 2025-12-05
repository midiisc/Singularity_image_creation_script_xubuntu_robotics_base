#!/bin/bash
# Launch Zellij session with Zenoh-enabled ROS environments

set -euo pipefail

SESSION="ros_multi_zenoh"
if ! layout_file="$(mktemp -t ros_zenoh_layout.XXXXXX.kdl)"; then
  echo "✗ Failed to allocate temporary Zenoh layout file" >&2
  exit 1
fi

cleanup() {
  rm -f "${layout_file}"
}
trap cleanup EXIT INT TERM

# Start Zenoh infrastructure first
zenoh_start

# Create Zellij layout
if ! cat <<'LAYOUT' > "${layout_file}"
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Humble" focus=true {
        pane {
            command "bash"
            args "-c" "conda activate ros2_humble && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/humble_ws && exec bash"
        }
    }

    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/jazzy_ws && exec bash"
        }
    }

    tab name="Zenoh" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "zenoh_status && echo '' && echo 'Zenoh Infrastructure running' && exec bash"
            }
            pane {
                command "bash"
                args "-c" "tail -f /tmp/zenoh-router.log"
            }
        }
    }

    tab name="Julia" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "echo 'Start Julia server: julia /opt/scripts/julia_vision_server.jl' && exec bash"
            }
            pane {
                command "julia"
            }
        }
    }

    tab name="Monitor" {
        pane split_direction="vertical" {
            pane {
                command "btm"
            }
            pane {
                command "nvtop"
            }
        }
    }
}
LAYOUT
then
    : # File created successfully
else
    echo "✗ Failed to create Zellij Zenoh layout file" >&2
    exit 1
fi


# Launch Zellij with layout
if ! zellij --layout "${layout_file}" attach -c "${SESSION}"; then
  echo "✗ Failed to launch Zellij Zenoh session" >&2
  exit 1
fi
