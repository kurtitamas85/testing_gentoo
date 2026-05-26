import React, { useState } from 'react';
import { BookOpen, Terminal, ChevronRight } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('guide');

  const visualGuideContent = `
    # Visual Guide: Gentoo Setup
    1. Prepare the ISO.
    2. Boot into the live environment.
    3. Run the installer script.
    4. Configure kernel options via the TUI.
  `;

  const scriptContent = `
    #!/bin/bash
    echo "Starting Gentoo Automated Installer..."
    # Add your script logic here
  `;

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 p-6">
      <header className="max-w-4xl mx-auto mb-8">
        <h1 className="text-3xl font-bold text-emerald-400">Gentoo LiveGUI Installer</h1>
        <p className="text-slate-400">Manage your installation process and documentation.</p>
      </header>

      <main className="max-w-4xl mx-auto bg-slate-800 rounded-xl shadow-xl overflow-hidden">
        <div className="flex border-b border-slate-700">
          <button
            onClick={() => setActiveTab('guide')}
            className={`flex items-center gap-2 px-6 py-4 font-medium transition ${activeTab === 'guide' ? 'bg-slate-700 text-emerald-400 border-b-2 border-emerald-400' : 'text-slate-400 hover:text-white'}`}
          >
            <BookOpen size={20} /> Visual Guide
          </button>
          <button
            onClick={() => setActiveTab('script')}
            className={`flex items-center gap-2 px-6 py-4 font-medium transition ${activeTab === 'script' ? 'bg-slate-700 text-emerald-400 border-b-2 border-emerald-400' : 'text-slate-400 hover:text-white'}`}
          >
            <Terminal size={20} /> TUI Installer Script
          </button>
        </div>

        <div className="p-8">
          {activeTab === 'guide' ? (
            <div className="prose prose-invert max-w-none">
              <pre className="bg-slate-950 p-4 rounded text-emerald-300">{visualGuideContent}</pre>
            </div>
          ) : (
            <div className="space-y-4">
              <pre className="bg-slate-950 p-4 rounded text-blue-300 overflow-x-auto">{scriptContent}</pre>
              <button className="bg-emerald-600 hover:bg-emerald-500 px-4 py-2 rounded flex items-center gap-2">
                Copy Script <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
