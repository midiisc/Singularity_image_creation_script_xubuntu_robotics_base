#!/usr/bin/env python3
"""
Purpose: python scripts block 38 zenoh zenoh topic bridge.py
"""
# Zenoh topic bridge for ROS 2 Humble <-> Jazzy communication

import sys
try:
    import zenoh
except ImportError:
    #--- Sub-block 38.7: Helper scripts generation ---
    # Purpose: Create utility and monitoring scripts
    # Dependencies: None (foundational)
    # Outputs: Environment variables, configuration
    print(" Zenoh-Python package not installed")
    print("Install with: python3 -m pip install eclipse-zenoh")
    sys.exit(1)

class ZenohTopicBridge:
    def __init__(self):
        # Connect to Zenoh router
        config = zenoh.Config()
        self.session = zenoh.open(config)
        print("✓ Connected to Zenoh router")


    def bridge_topic(self, from_topic: str, to_topic: str):
        """Bridge a topic from one namespace to another"""
        def callback(sample):
            # Forward data
            self.session.put(to_topic, sample.payload)
            print(f"Bridged: {from_topic} -> {to_topic}")

        #--- Sub-block 38.8: Utility scripts ---
        # Purpose: Helper scripts creation
        # Dependencies: None (foundational)
        # Outputs: Environment variables, configuration

        #--- Code section 6161 ---
        # Purpose: Continuing implementation
        # Dependencies: None (foundational)
        # Outputs: Environment variables, configuration
        # Subscribe and forward
        subscriber = self.session.declare_subscriber(from_topic, callback)
        print(f"Bridge active: {from_topic} -> {to_topic}")

        #--- Sub-block 38.9: Script generation ---
        # Purpose: Create additional helper scripts
        # Dependencies: None (foundational)
        # Outputs: Environment variables, configuration
        return subscriber

    def run(self):
        """Keep bridge running"""
        print("Zenoh topic bridge running. Press Ctrl+C to stop.")
        try:
            import time
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("Stopping bridge...")

if __name__ == "__main__":
    bridge = ZenohTopicBridge()
    # Example bridges - customize as needed
    bridge.bridge_topic('/humble/camera/image', '/jazzy/camera/image')
    bridge.bridge_topic('/jazzy/cmd_vel', '/humble/cmd_vel')
    bridge.run()
