import React, { useState } from 'react';
import { BookOpen, CheckCircle, ChevronRight, ChevronDown, Terminal } from 'lucide-react';

const phases = [
  { id: 1, title: "Preparation", desc: "Setting up boot media and partitioning" },
  { id: 2, title: "Network Configuration", desc: "Configuring interfaces and DNS" },
  { id: 3, title: "Stage 3 Tarball", desc: "Downloading and unpacking the base system" },
  { id: 4, title: "Make.conf Setup", desc: "Optimizing compilation flags" },
  { id: 5, title: "Selecting a Profile", desc: "Choosing the system personality" },
  { id: 6, title: "Timezone & Locale", desc: "Defining system environment settings" },
  { id: 7, title: "Kernel Selection", desc: "Choosing between sources" },
  { id: 8, title: "Kernel Configuration", desc: "Tuning the hardware support" },
  { id: 9, title: "Kernel Compilation", desc: "Building the core system image" },
  { id: 10, title: "fstab Setup", desc: "Mounting point definitions" },
  { id: 11, title: "Networking Utilities", desc: "Installing dhcpcd/networkmanager" },
  { id: 12, title: "System Logger", desc: "Installing syslog-ng or metalog" },
  { id: 13, title: "Bootloader", desc: "GRUB2 installation and configuration" },
  { id: 14, title: "Root Password", desc: "Securing the administrative account" },
  { id: 15, title: "User Accounts", desc: "Creating standard user access" },
  { id: 16, title: "Desktop Environment", desc: "Xorg or Wayland base installation" },
  { id: 17, title: "Display Manager", desc: "Setting up GDM/SDDM" },
  { id: 18, title: "Graphics Drivers", desc: "NVIDIA/AMD/Intel configuration" },
  { id: 19, title: "Sound Support", desc: "ALSA/Pipewire configuration" },
  { id: 20, title: "Browser Setup", desc: "Compiling Firefox or Chromium" },
  { id: 21, title: "Office Suite", desc: "LibreOffice installation" },
  { id: 22, title: "Development Tools", desc: "Git, GCC, and build utilities" },
  { id: 23, title: "Portage Overlays", desc: "Adding secondary repositories" },
  { id: 24, title: "World Update", desc: "Synchronizing system packages" },
  { id: 25, title: "Clean Up", desc: "Removing orphaned dependencies" },
  { id: 26, title: "Kernel Rebuild", desc: "Removing unused features" },
  { id: 27, title: "System Backup", desc: "First stable state snapshot" },
  { id: 28, title: "Security Audit", desc: "Scanning for open ports" },
  { id: 29, title: "Custom Scripts", desc: "Automating routine tasks" },
  { id: 30, title: "Printing Support", desc: "CUPS configuration" },
  { id: 31, title: "Bluetooth Setup", desc: "Configuring Bluez" },
  { id: 32, title: "Power Management", desc: "Laptop battery and CPU throttling" },
  { id: 33, title: "Containerization", desc: "Docker or Podman setup" },
  { id: 34, title: "Virtualization", desc: "QEMU/KVM configuration" },
  { id: 35, title: "Personalization", desc: "Theming and fonts" },
  { id: 36, title: "Startup Services", desc: "OpenRC/systemd service audit" },
  { id: 37, title: "Log Rotation", desc: "Ensuring disk space health" },
  { id: 38, title: "Final Validation", desc: "System sanity check" }
];

export default function App() {
  const [expanded, setExpanded] = useState(1);

  return (
    <div className="min-h-screen bg-slate-50 p-4 md:p-8">
      <header className="max-w-4xl mx-auto mb-10 text-center">
        <h1 className="text-4xl font-bold text-slate-900 mb-2">Gentoo 38-Phase Guide</h1>
        <p className="text-slate-600">Complete architectural roadmap for system installation</p>
      </header>

      <main className="max-w-4xl mx-auto space-y-3">
        {phases.map((phase) => (
          <div 
            key={phase.id} 
            className={`border rounded-xl transition-all duration-300 overflow-hidden ${expanded === phase.id ? 'bg-white shadow-lg border-blue-200' : 'bg-white hover:border-slate-300'}`}
          >
            <button 
              onClick={() => setExpanded(expanded === phase.id ? null : phase.id)}
              className="w-full p-4 flex items-center justify-between text-left focus:outline-none"
            >
              <div className="flex items-center gap-4">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${expanded === phase.id ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-600'}`}>
                  {phase.id}
                </div>
                <div>
                  <h3 className="font-semibold text-slate-800">{phase.title}</h3>
                </div>
              </div>
              {expanded === phase.id ? <ChevronDown className="text-blue-600" /> : <ChevronRight className="text-slate-400" />}
            </button>
            
            {expanded === phase.id && (
              <div className="px-16 pb-4 pt-0 text-slate-600 text-sm animate-in fade-in slide-in-from-top-2">
                <p className="mb-4">{phase.desc}</p>
                <div className="bg-slate-900 rounded-lg p-3 text-emerald-400 font-mono text-xs flex items-center gap-2">
                  <Terminal size={14} />
                  <span>emerge --ask phase-{phase.id}</span>
                </div>
              </div>
            )}
          </div>
        ))}
      </main>
    </div>
  );
}
