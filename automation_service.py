#!/usr/bin/env python3
"""
Automation Service for Idle Finance Desktop App
This service manages Golem provider operations and provides API endpoints
"""

import asyncio
import json
import logging
import os
import signal
import sys
import time
from pathlib import Path
from typing import Dict, Any, Optional
import subprocess
import threading
import platform

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/idle-finance-automation.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class AutomationService:
    def __init__(self, port: int = 8000):
        self.port = port
        self.golem_process: Optional[subprocess.Popen] = None
        self.api_process: Optional[subprocess.Popen] = None
        self.is_running = False
        self.log_file = "/tmp/idle-finance-automation.log"
        
    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] [{level}] {message}"
        
        # Write to log file
        with open(self.log_file, 'a') as f:
            f.write(log_entry + '\n')
        
        # Also print to console
        print(log_entry)
    
    def check_virtual_environment(self) -> Dict[str, Any]:
        """Check virtual environment status"""
        try:
            # Handle PyInstaller bundled binary case
            if getattr(sys, 'frozen', False):
                # Running as bundled binary - all dependencies are already included
                return {
                    "status": "ready",
                    "message": "Running as bundled binary, all dependencies included",
                    "python_path": sys.executable
                }
            
            # Running as script - check virtual environment
            script_dir = Path(__file__).parent.absolute()
            venv_dir = script_dir / "venv"
            
            if not venv_dir.exists():
                return {
                    "status": "not_found",
                    "message": "Virtual environment not found",
                    "venv_path": str(venv_dir)
                }
            
            # Determine the Python executable in the virtual environment
            if platform.system() == "Windows":
                python_executable = venv_dir / "Scripts" / "python.exe"
            else:
                python_executable = venv_dir / "bin" / "python"
            
            if not python_executable.exists():
                return {
                    "status": "corrupted",
                    "message": "Python executable not found in virtual environment",
                    "python_path": str(python_executable)
                }
            
            # Check if required packages are installed
            missing_packages = []
            required_packages = ["fastapi", "uvicorn", "pydantic", "requests"]
            
            for package in required_packages:
                try:
                    subprocess.run(
                        [str(python_executable), "-c", f"import {package}"],
                        check=True,
                        capture_output=True,
                        text=True
                    )
                except subprocess.CalledProcessError:
                    missing_packages.append(package)
            
            if missing_packages:
                return {
                    "status": "incomplete",
                    "message": f"Missing packages: {', '.join(missing_packages)}",
                    "missing_packages": missing_packages
                }
            
            return {
                "status": "ready",
                "message": "Virtual environment is ready",
                "python_path": str(python_executable)
            }
            
        except Exception as e:
            return {
                "status": "error",
                "message": f"Error checking virtual environment: {str(e)}"
            }
    
    def setup_virtual_environment(self) -> Dict[str, Any]:
        """Setup virtual environment and install requirements"""
        try:
            self.log("Setting up virtual environment...")
            
            # Handle PyInstaller bundled binary case
            if getattr(sys, 'frozen', False):
                # Running as bundled binary - skip virtual environment setup
                self.log("Running as bundled binary, skipping virtual environment setup")
                return {
                    "status": "success",
                    "message": "Running as bundled binary, virtual environment not needed"
                }
            
            # Running as script - setup virtual environment
            script_dir = Path(__file__).parent.absolute()
            self.log(f"Running as script, using script directory: {script_dir}")
            
            venv_dir = script_dir / "venv"
            requirements_file = script_dir / "requirements.txt"
            
            # Check if requirements.txt exists
            if not requirements_file.exists():
                return {
                    "status": "error",
                    "message": f"requirements.txt not found at {requirements_file}"
                }
            
            # Create virtual environment if it doesn't exist
            if not venv_dir.exists():
                self.log("Creating virtual environment...")
                try:
                    subprocess.run(
                        [sys.executable, "-m", "venv", str(venv_dir)],
                        check=True,
                        capture_output=True,
                        text=True
                    )
                    self.log("Virtual environment created successfully")
                except subprocess.CalledProcessError as e:
                    return {
                        "status": "error",
                        "message": f"Failed to create virtual environment: {e.stderr}"
                    }
            
            # Determine the pip executable in the virtual environment
            if platform.system() == "Windows":
                pip_executable = venv_dir / "Scripts" / "pip.exe"
            else:
                pip_executable = venv_dir / "bin" / "pip"
            
            # Install requirements
            self.log("Installing requirements...")
            try:
                subprocess.run(
                    [str(pip_executable), "install", "-r", str(requirements_file)],
                    check=True,
                    capture_output=True,
                    text=True
                )
                self.log("Requirements installed successfully")
            except subprocess.CalledProcessError as e:
                return {
                    "status": "error",
                    "message": f"Failed to install requirements: {e.stderr}"
                }
            
            return {
                "status": "success",
                "message": "Virtual environment setup completed"
            }
            
        except Exception as e:
            return {
                "status": "error",
                "message": f"Error setting up virtual environment: {str(e)}"
            }
        
    def start_api_server(self):
        """Start the FastAPI server"""
        try:
            self.log("Starting automation API server...")
            
            # Check virtual environment status
            venv_status = self.check_virtual_environment()
            if venv_status["status"] != "ready":
                self.log(f"Virtual environment not ready: {venv_status['message']}", "ERROR")
                return False
            
            # Get the directory where this script is located
            if getattr(sys, 'frozen', False):
                # Running as bundled binary
                script_dir = Path(sys._MEIPASS)
                # For bundled binary, we need to import and run the FastAPI app directly
                self.log("Running as bundled binary, starting FastAPI server directly...")
                
                # Import the FastAPI app from main module
                import main
                import uvicorn
                
                # Start the server using uvicorn.run
                def run_server():
                    uvicorn.run(
                        main.app,
                        host="127.0.0.1",
                        port=self.port,
                        log_level="info"
                    )
                
                # Start server in a separate thread
                server_thread = threading.Thread(target=run_server, daemon=True)
                server_thread.start()
                
                self.log(f"API server started in thread")
                return True
            else:
                # Running as script - use subprocess
                script_dir = Path(__file__).parent.absolute()
                
                # Start the API server using the virtual environment Python
                cmd = [
                    venv_status["python_path"], "-m", "uvicorn", 
                    "main:app", 
                    "--host", "127.0.0.1", 
                    "--port", str(self.port),
                    "--log-level", "info"
                ]
                
                self.log(f"Starting server with command: {' '.join(cmd)}")
                
                self.api_process = subprocess.Popen(
                    cmd,
                    cwd=script_dir,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                
                self.log(f"API server started with PID: {self.api_process.pid}")
                return True
            
        except Exception as e:
            self.log(f"Failed to start API server: {str(e)}", "ERROR")
            return False
    
    def call_bootstrap_endpoint(self) -> Dict[str, Any]:
        """Call the bootstrap endpoint to install necessary dependencies"""
        try:
            self.log("🚀 Calling bootstrap endpoint to install dependencies...")
            
            import requests
            import time
            
            # Wait for server to be ready
            max_retries = 30
            retry_count = 0
            
            while retry_count < max_retries:
                try:
                    # Test if server is responding
                    response = requests.get(f"http://127.0.0.1:{self.port}/docs", timeout=5)
                    if response.status_code == 200:
                        self.log("✅ API server is ready, calling bootstrap endpoint...")
                        break
                except requests.exceptions.RequestException:
                    pass
                
                retry_count += 1
                time.sleep(1)
                if retry_count % 5 == 0:
                    self.log(f"⏳ Waiting for API server to be ready... ({retry_count}/{max_retries})")
            
            if retry_count >= max_retries:
                return {
                    "status": "error",
                    "message": "API server did not become ready in time"
                }
            
            # Call bootstrap endpoint and wait for completion
            try:
                self.log("📋 Starting bootstrap process via HTTP...")
                response = requests.post(
                    f"http://127.0.0.1:{self.port}/bootstrap",
                    timeout=600  # 10 minutes timeout for bootstrap
                )
                
                if response.status_code == 200:
                    result = response.json()
                    self.log("✅ Bootstrap completed successfully!")
                    
                    # Log completion details
                    steps_completed = result.get("steps_completed", 0)
                    total_steps = result.get("total_steps", 5)
                    completion_time = result.get("completion_time", "Unknown")
                    
                    self.log(f"📊 Bootstrap Summary:")
                    self.log(f"   - Steps completed: {steps_completed}/{total_steps}")
                    self.log(f"   - Completion time: {completion_time}")
                    
                    # Log individual step results
                    bootstrap_steps = result.get("bootstrap_steps", [])
                    for step in bootstrap_steps:
                        step_num = step.get("step", "?")
                        action = step.get("action", "unknown")
                        status = step.get("status", "unknown")
                        message = step.get("message", "No message")
                        
                        if status == "success":
                            self.log(f"   ✅ Step {step_num} ({action}): {message}")
                        else:
                            self.log(f"   ❌ Step {step_num} ({action}): {message}", "ERROR")
                    
                    # Wait a bit more to ensure all processes are settled
                    time.sleep(3)
                    
                    # Verify installation via HTTP endpoint
                    try:
                        self.log("🔍 Verifying installation...")
                        verify_response = requests.get(f"http://127.0.0.1:{self.port}/verify-installation", timeout=30)
                        if verify_response.status_code == 200:
                            verify_result = verify_response.json()
                            if verify_result.get("all_systems_go", False):
                                self.log("✅ Installation verification successful - all systems ready!")
                            else:
                                self.log("⚠️ Installation verification shows some issues", "WARNING")
                        else:
                            self.log("⚠️ Could not verify installation", "WARNING")
                    except Exception as e:
                        self.log(f"⚠️ Installation verification failed: {str(e)}", "WARNING")
                    
                    return {
                        "status": "success",
                        "message": "Bootstrap completed successfully",
                        "result": result
                    }
                else:
                    self.log(f"❌ Bootstrap failed with status {response.status_code}: {response.text}", "ERROR")
                    return {
                        "status": "error",
                        "message": f"Bootstrap failed with status {response.status_code}",
                        "response": response.text
                    }
                    
            except requests.exceptions.Timeout:
                self.log("❌ Bootstrap request timed out", "ERROR")
                return {
                    "status": "error",
                    "message": "Bootstrap request timed out"
                }
            except requests.exceptions.RequestException as e:
                self.log(f"❌ Bootstrap request failed: {str(e)}", "ERROR")
                return {
                    "status": "error",
                    "message": f"Bootstrap request failed: {str(e)}"
                }
                
        except Exception as e:
            self.log(f"❌ Error calling bootstrap endpoint: {str(e)}", "ERROR")
            return {
                "status": "error",
                "message": str(e)
            }
    
    def stop_api_server(self):
        """Stop the API server"""
        if self.api_process:
            try:
                self.log("Stopping API server...")
                self.api_process.terminate()
                self.api_process.wait(timeout=5)
                self.log("API server stopped")
            except subprocess.TimeoutExpired:
                self.log("Force killing API server...", "WARNING")
                self.api_process.kill()
            except Exception as e:
                self.log(f"Error stopping API server: {str(e)}", "ERROR")
            finally:
                self.api_process = None
    
    def check_golem_installed(self) -> bool:
        """Check if Golem is installed"""
        try:
            result = subprocess.run(
                ["which", "golemsp"], 
                capture_output=True, 
                text=True, 
                check=True
            )
            return bool(result.stdout.strip())
        except subprocess.CalledProcessError:
            return False
    
    def install_golem(self) -> Dict[str, Any]:
        """Install Golem if not already installed"""
        try:
            self.log("Checking Golem installation...")
            
            if self.check_golem_installed():
                self.log("Golem is already installed")
                return {"status": "success", "message": "Golem already installed"}
            
            self.log("Installing Golem...")
            
            # Get the installation script path
            script_dir = Path(__file__).parent.parent.absolute()
            install_script = script_dir / "scripts" / "install-golem.sh"
            
            if not install_script.exists():
                return {
                    "status": "error", 
                    "message": f"Installation script not found: {install_script}"
                }
            
            # Run installation script
            result = subprocess.run(
                ["bash", str(install_script)],
                capture_output=True,
                text=True,
                timeout=300  # 5 minutes timeout
            )
            
            if result.returncode == 0:
                self.log("Golem installation completed successfully")
                return {
                    "status": "success",
                    "message": "Golem installed successfully",
                    "output": result.stdout
                }
            else:
                self.log(f"Golem installation failed: {result.stderr}", "ERROR")
                return {
                    "status": "error",
                    "message": "Golem installation failed",
                    "error": result.stderr
                }
                
        except subprocess.TimeoutExpired:
            self.log("Golem installation timed out", "ERROR")
            return {"status": "error", "message": "Installation timed out"}
        except Exception as e:
            self.log(f"Error during Golem installation: {str(e)}", "ERROR")
            return {"status": "error", "message": str(e)}
    
    def start_golem_provider(self) -> Dict[str, Any]:
        """Start the Golem provider"""
        try:
            self.log("Starting Golem provider...")
            
            # Check if already running
            if self.is_golem_running():
                self.log("Golem provider is already running")
                return {"status": "success", "message": "Golem provider already running"}
            
            # Start golemsp in background
            cmd = "nohup golemsp run > ~/.local/share/yagna/yagna_rCURRENT.log 2>&1 & echo $!"
            result = subprocess.run(
                ["bash", "-c", cmd], 
                capture_output=True, 
                text=True, 
                check=True
            )
            
            pid = result.stdout.strip()
            self.log(f"Golem provider started with PID: {pid}")
            
            # Wait a bit for it to start
            time.sleep(3)
            
            if self.is_golem_running():
                self.log("Golem provider started successfully")
                return {
                    "status": "success",
                    "message": "Golem provider started",
                    "pid": pid
                }
            else:
                self.log("Golem provider failed to start", "ERROR")
                return {"status": "error", "message": "Failed to start Golem provider"}
                
        except Exception as e:
            self.log(f"Error starting Golem provider: {str(e)}", "ERROR")
            return {"status": "error", "message": str(e)}
    
    def stop_golem_provider(self) -> Dict[str, Any]:
        """Stop the Golem provider"""
        try:
            self.log("Stopping Golem provider...")
            
            # Check if golemsp is available
            golem_path = None
            try:
                subprocess.run(["golemsp", "--version"], capture_output=True, check=True)
                golem_path = "golemsp"
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Try explicit path
                explicit_path = os.path.expanduser("~/.local/bin/golemsp")
                if os.path.exists(explicit_path):
                    golem_path = explicit_path
                else:
                    self.log("Golem is not installed", "WARNING")
                    return {"status": "success", "message": "Golem not installed"}
            
            if not self.is_golem_running():
                self.log("Golem provider is not running")
                return {"status": "success", "message": "Golem provider not running"}
            
            result = subprocess.run(
                [golem_path, "stop"], 
                capture_output=True, 
                text=True, 
                check=True
            )
            
            self.log("Golem provider stopped")
            return {
                "status": "success",
                "message": "Golem provider stopped",
                "output": result.stdout
            }
            
        except Exception as e:
            self.log(f"Error stopping Golem provider: {str(e)}", "ERROR")
            return {"status": "error", "message": str(e)}
    
    def is_golem_running(self) -> bool:
        """Check if Golem provider is running"""
        try:
            result = subprocess.run(
                ["golemsp", "status"], 
                capture_output=True, 
                text=True, 
                check=True
            )
            return "is running" in result.stdout
        except subprocess.CalledProcessError:
            return False
    
    def get_golem_status(self) -> Dict[str, Any]:
        """Get Golem provider status"""
        try:
            if not self.is_golem_running():
                return {
                    "status": "stopped",
                    "message": "Golem provider is not running"
                }
            
            result = subprocess.run(
                ["golemsp", "status"], 
                capture_output=True, 
                text=True, 
                check=True
            )
            
            return {
                "status": "running",
                "output": result.stdout,
                "timestamp": time.time()
            }
            
        except Exception as e:
            return {"status": "error", "message": str(e)}
    
    def get_logs(self, log_type: str = "golem", lines: int = 50) -> Dict[str, Any]:
        """Get log files"""
        try:
            log_files = {
                "golem": "~/.local/share/yagna/yagna_rCURRENT.log",
                "provider": "~/.local/share/ya-provider/ya-provider_rCURRENT.log",
                "automation": self.log_file
            }
            
            log_file = os.path.expanduser(log_files.get(log_type, log_files["golem"]))
            
            if not os.path.exists(log_file):
                return {
                    "status": "error",
                    "message": f"Log file not found: {log_file}"
                }
            
            result = subprocess.run(
                ["tail", "-n", str(lines), log_file],
                capture_output=True,
                text=True,
                check=True
            )
            
            return {
                "status": "success",
                "log": result.stdout,
                "file": log_file
            }
            
        except Exception as e:
            return {"status": "error", "message": str(e)}
    
    def start(self):
        """Start the automation service"""
        try:
            self.log("Starting Idle Finance Automation Service...")
            self.is_running = True
            
            # Check and setup virtual environment if needed
            script_dir = Path(__file__).parent.absolute()
            venv_dir = script_dir / "venv"
            
            if not venv_dir.exists():
                self.log("Virtual environment not found. Setting up automatically...")
                setup_result = self.setup_virtual_environment()
                if setup_result["status"] != "success":
                    self.log(f"Failed to setup virtual environment: {setup_result['message']}", "ERROR")
                    return False
            
            # Start API server
            if not self.start_api_server():
                self.log("Failed to start API server", "ERROR")
                return False
            
            # Wait for API server to be ready
            time.sleep(2)
            
            # Wait for API server to be ready
            time.sleep(2)
            
            self.log(f"Automation service started successfully on port {self.port}")
            self.log("API endpoints available at:")
            self.log(f"  - Status: http://127.0.0.1:{self.port}/golem-status")
            self.log(f"  - Start: http://127.0.0.1:{self.port}/start-golem")
            self.log(f"  - Stop: http://127.0.0.1:{self.port}/stop-golem")
            self.log(f"  - Logs: http://127.0.0.1:{self.port}/golem-log")
            
            return True
            
        except Exception as e:
            self.log(f"Failed to start automation service: {str(e)}", "ERROR")
            return False
    
    def stop(self):
        """Stop the automation service"""
        try:
            self.log("Stopping Idle Finance Automation Service...")
            self.is_running = False
            
            # Stop Golem provider
            self.stop_golem_provider()
            
            # Stop API server
            self.stop_api_server()
            
            self.log("Automation service stopped")
            
        except Exception as e:
            self.log(f"Error stopping automation service: {str(e)}", "ERROR")

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    if hasattr(signal_handler, 'service'):
        signal_handler.service.stop()
    sys.exit(0)

def main():
    """Main entry point"""
    # Parse command line arguments
    port = 8000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("Invalid port number, using default port 8000")
    
    # Create and start service
    service = AutomationService(port)
    
    # Set up signal handlers
    signal_handler.service = service
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start the service
    if service.start():
        try:
            # Keep the service running
            while service.is_running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        finally:
            service.stop()
    else:
        logger.error("Failed to start automation service")
        sys.exit(1)

if __name__ == "__main__":
    main()
