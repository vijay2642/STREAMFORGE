#!/usr/bin/env python3

"""
StreamForge Smart Debug System
Automatically handles health checks and service startup in the debug workflow
"""

import subprocess
import sys
import time
import os
from datetime import datetime

class StreamForgeDebugger:
    def __init__(self):
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.health_script = os.path.join(self.script_dir, "health-check.sh")
        self.startup_script = os.path.join(self.script_dir, "streamforge-quick-start.sh")
        
    def print_header(self):
        print("\n" + "="*70)
        print("🔧 StreamForge Smart Debug System")
        print("🕒 Started at:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        print("="*70)
    
    def print_status(self, message, status="INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S")
        colors = {
            "INFO": "\033[94m",    # Blue
            "SUCCESS": "\033[92m", # Green
            "WARNING": "\033[93m", # Yellow
            "ERROR": "\033[91m",   # Red
            "RESET": "\033[0m"     # Reset
        }
        
        color = colors.get(status, colors["INFO"])
        reset = colors["RESET"]
        print(f"[{timestamp}] {color}[{status}]{reset} {message}")
    
    def run_command(self, command, description=""):
        """Run a shell command and return success status"""
        try:
            if description:
                self.print_status(f"Running: {description}", "INFO")
            
            result = subprocess.run(
                command, 
                shell=True, 
                capture_output=True, 
                text=True,
                cwd=self.script_dir
            )
            
            if result.returncode == 0:
                return True, result.stdout
            else:
                return False, result.stderr
                
        except Exception as e:
            return False, str(e)
    
    def check_script_exists(self, script_path):
        """Check if a script exists and is executable"""
        if not os.path.exists(script_path):
            return False, f"Script not found: {script_path}"
        
        if not os.access(script_path, os.X_OK):
            # Try to make it executable
            try:
                os.chmod(script_path, 0o755)
                return True, f"Made script executable: {script_path}"
            except Exception as e:
                return False, f"Cannot make script executable: {e}"
        
        return True, f"Script ready: {script_path}"
    
    def perform_health_check(self):
        """Run the health check script and return status"""
        self.print_status("🔍 Performing health check...", "INFO")
        
        # Check if health script exists
        exists, message = self.check_script_exists(self.health_script)
        if not exists:
            self.print_status(message, "ERROR")
            return False, 0
        
        # Run health check
        success, output = self.run_command(f"./health-check.sh", "Health Check")
        
        if success:
            # Extract health percentage from output
            health_percentage = 0
            lines = output.split('\n')
            for line in lines:
                if "Overall Health:" in line and "%" in line:
                    try:
                        # Extract percentage from line like "Overall Health: 13/16 services (81%)"
                        percentage_part = line.split('(')[1].split('%')[0]
                        health_percentage = int(percentage_part)
                        break
                    except:
                        pass
            
            if health_percentage >= 90:
                self.print_status(f"✅ Excellent health: {health_percentage}% - System ready!", "SUCCESS")
            elif health_percentage >= 75:
                self.print_status(f"⚠️ Good health: {health_percentage}% - Minor issues detected", "WARNING")
            elif health_percentage >= 50:
                self.print_status(f"🚧 Partial health: {health_percentage}% - Significant issues", "WARNING")
            else:
                self.print_status(f"🚨 Critical health: {health_percentage}% - Multiple failures", "ERROR")
            
            return True, health_percentage
        else:
            self.print_status(f"Health check failed: {output}", "ERROR")
            return False, 0
    
    def auto_startup_services(self):
        """Run the quick-start script to fix issues"""
        self.print_status("🚀 Starting auto-repair and startup...", "INFO")
        
        # Check if startup script exists
        exists, message = self.check_script_exists(self.startup_script)
        if not exists:
            self.print_status(message, "ERROR")
            return False
        
        # Run startup script
        success, output = self.run_command(f"./streamforge-quick-start.sh", "Auto Startup")
        
        if success:
            self.print_status("✅ Auto-startup completed successfully", "SUCCESS")
            return True
        else:
            self.print_status(f"❌ Auto-startup failed: {output}", "ERROR")
            return False
    
    def get_user_input(self):
        """Get user input for debug commands"""
        while True:
            try:
                print("\n" + "-"*50)
                print("🎯 StreamForge Debug Console")
                print("Commands:")
                print("  'health' - Run health check only")
                print("  'fix' - Auto-fix issues")
                print("  'restart' - Restart live transcoder")
                print("  'status' - Quick service status")
                print("  'logs' - Show recent logs")
                print("  'stop' - Exit debug session")
                print("-"*50)
                
                user_input = input("debug> ").strip().lower()
                
                if user_input == "stop":
                    self.print_status("👋 Exiting debug session", "INFO")
                    break
                
                elif user_input == "health":
                    self.perform_health_check()
                
                elif user_input == "fix":
                    self.auto_startup_services()
                    # Re-check health after fix
                    time.sleep(3)
                    self.perform_health_check()
                
                elif user_input == "restart":
                    self.restart_live_transcoder()
                
                elif user_input == "status":
                    self.quick_status()
                
                elif user_input == "logs":
                    self.show_logs()
                
                elif user_input == "":
                    continue
                
                else:
                    self.print_status(f"Unknown command: {user_input}", "WARNING")
                    self.print_status("Type 'stop' to exit or use one of the available commands", "INFO")
                    
            except KeyboardInterrupt:
                print("\n")
                self.print_status("👋 Debug session interrupted", "INFO")
                break
            except EOFError:
                print("\n")
                self.print_status("👋 Debug session ended", "INFO")
                break
    
    def restart_live_transcoder(self):
        """Restart the live transcoder processes"""
        self.print_status("🔄 Restarting live transcoder...", "INFO")
        
        # Kill existing processes
        self.run_command("pkill -f live_transcoder.py", "Stopping live transcoder")
        self.run_command("pkill -f 'ffmpeg.*stream'", "Stopping FFmpeg processes")
        
        time.sleep(2)
        
        # Start new process
        success, output = self.run_command(
            "nohup python3 live_transcoder.py both >/dev/null 2>&1 &", 
            "Starting live transcoder"
        )
        
        if success:
            time.sleep(5)
            # Check if processes started
            success1, _ = self.run_command("pgrep -f live_transcoder.py")
            success2, _ = self.run_command("pgrep -f 'ffmpeg.*stream1'")
            success3, _ = self.run_command("pgrep -f 'ffmpeg.*stream3'")
            
            if success1 and success2 and success3:
                self.print_status("✅ Live transcoder restarted successfully", "SUCCESS")
            else:
                self.print_status("⚠️ Live transcoder may not have started properly", "WARNING")
        else:
            self.print_status("❌ Failed to restart live transcoder", "ERROR")
    
    def quick_status(self):
        """Show quick status of key services"""
        self.print_status("📊 Quick Service Status:", "INFO")
        
        services = [
            ("CORS Server (8085)", "curl -s -o /dev/null -w '%{http_code}' http://localhost:8085"),
            ("Web Player (3000)", "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"),
            ("NGINX RTMP (1935)", "timeout 3 bash -c '</dev/tcp/localhost/1935'"),
            ("Live Transcoder", "pgrep -f live_transcoder.py"),
            ("FFmpeg Stream1", "pgrep -f 'ffmpeg.*stream1'"),
            ("FFmpeg Stream3", "pgrep -f 'ffmpeg.*stream3'"),
        ]
        
        for name, command in services:
            success, output = self.run_command(command)
            if success:
                if "curl" in command:
                    if output.strip() == "200":
                        print(f"  ✅ {name}: HTTP 200 OK")
                    else:
                        print(f"  ⚠️ {name}: HTTP {output.strip()}")
                else:
                    print(f"  ✅ {name}: Running")
            else:
                print(f"  ❌ {name}: Not responding")
    
    def show_logs(self):
        """Show recent logs"""
        self.print_status("📋 Recent logs:", "INFO")
        
        log_files = [
            "/tmp/streamforge-quickstart.log",
            "/tmp/streamforge-startup.log",
            "cors_server.log"
        ]
        
        for log_file in log_files:
            if os.path.exists(log_file):
                print(f"\n--- {log_file} (last 5 lines) ---")
                success, output = self.run_command(f"tail -5 {log_file}")
                if success:
                    print(output)
                else:
                    print("Could not read log file")
    
    def run(self):
        """Main debug workflow"""
        self.print_header()
        
        # Step 1: Initial health check
        health_success, health_percentage = self.perform_health_check()
        
        # Step 2: Auto-fix if health is poor
        if health_success and health_percentage < 75:
            self.print_status(f"🔧 Health below 75% ({health_percentage}%), starting auto-repair...", "WARNING")
            
            if self.auto_startup_services():
                # Re-check health after auto-repair
                time.sleep(5)
                self.print_status("🔍 Re-checking health after auto-repair...", "INFO")
                health_success, health_percentage = self.perform_health_check()
                
                if health_percentage >= 75:
                    self.print_status("🎉 Auto-repair successful! System is now healthy.", "SUCCESS")
                else:
                    self.print_status("⚠️ Auto-repair completed but some issues remain.", "WARNING")
            else:
                self.print_status("❌ Auto-repair failed. Manual intervention may be required.", "ERROR")
        
        elif health_success and health_percentage >= 75:
            self.print_status("✅ System is healthy! Ready for debugging.", "SUCCESS")
        
        elif not health_success:
            self.print_status("❌ Health check failed. Manual intervention required.", "ERROR")
        
        # Step 3: Enter interactive debug mode
        print("\n🎮 Entering interactive debug mode...")
        time.sleep(1)
        self.get_user_input()
        
        # Cleanup
        self.print_status("🏁 Debug session completed", "SUCCESS")

if __name__ == "__main__":
    debugger = StreamForgeDebugger()
    debugger.run() 