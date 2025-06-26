#!/usr/bin/env python3

"""
StreamForge Auto-Debug
Simple replacement for userinput.py with automatic service management
"""

import subprocess
import sys
import os

def main():
    """
    Automatically run smart debug system
    This replaces the manual userinput.py workflow
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    smart_debug_script = os.path.join(script_dir, "smart_debug.py")
    
    print("🔧 StreamForge Auto-Debug Starting...")
    print("🚀 Automatically checking and fixing services...")
    print()
    
    # Check if smart_debug.py exists
    if not os.path.exists(smart_debug_script):
        print("❌ Error: smart_debug.py not found!")
        print("💡 Please ensure all health scripts are in place.")
        sys.exit(1)
    
    # Run the smart debug system
    try:
        subprocess.run([sys.executable, smart_debug_script], cwd=script_dir)
    except KeyboardInterrupt:
        print("\n👋 Debug session interrupted by user")
    except Exception as e:
        print(f"❌ Error running smart debug: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 