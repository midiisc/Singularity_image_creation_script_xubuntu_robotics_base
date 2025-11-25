#!/bin/bash
set -euo pipefail

# Launch Zellij session with multiple ROS environments

#--- Sub-block 37.14: System configuration ---
# Purpose: Final system setup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


SESSION="ros_multi"
if ! layout_file="$(mktemp -t ros_layout.XXXXXX.kdl)"; then
    echo "✗ Failed to allocate temporary layout file" >&2
    exit 1
fi

cleanup() {
    rm -f "${layout_file}"
}
trap cleanup EXIT INT TERM

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
            args "-c" "conda activate ros2_humble && cd /workspaces/humble_ws && exec bash"
        }
    }

    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && cd /workspaces/jazzy_ws && exec bash"
        }
    }

    tab name="Bridge" {
        pane {
            command "bash"
            args "-c" "echo 'Start domain bridge via: python3 /opt/scripts/domain_bridge.py' && exec bash"
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
                command "btm" // bottom system monitor
            }
            pane {
                command "nvtop" // GPU monitor
            }
        }
    }
}
LAYOUT
then
    : # File created successfully
else
    echo "✗ Failed to create Zellij layout file" >&2
    exit 1
fi

if [ ! -s "${layout_file}" ]; then
    echo "✗ Failed to create Zellij layout file" >&2
    exit 1
fi

# Launch Zellij with layout
if command -v zellij >/dev/null 2>&1; then
    if ! zellij --layout "${layout_file}" attach -c "${SESSION}"; then
        echo "✗ Failed to launch Zellij session" >&2
        exit 1
    fi
else
    echo "Error: zellij not found. Please install zellij first." >&2
    exit 1
fi
