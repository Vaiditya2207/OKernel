import React from 'react';
import { Zap, Settings, Layers, Keyboard, Code, FileCode, ArrowRight } from 'lucide-react';

export const AetherDocs = () => {
    return (
        <div className="space-y-12 max-w-4xl animate-fade-in pb-20">
            {/* Header */}
            <div className="space-y-6 border-b border-zinc-800 pb-10">
                <div className="inline-flex items-center gap-2 px-3 py-1 bg-purple-500/10 text-purple-500 text-xs font-mono rounded-full border border-purple-500/20">
                    <span className="w-2 h-2 rounded-full bg-purple-500 animate-pulse" />
                    Documentation
                </div>
                <h1 className="text-4xl md:text-5xl font-bold tracking-tight text-white">Aether Documentation</h1>
                <p className="text-xl text-zinc-400 leading-relaxed">
                    A deep dive into the engineering decisions, architecture, and configuration of the world's fastest macOS terminal.
                </p>
            </div>

            <div className="space-y-20">
                {/* Core Architecture */}
                <section className="grid grid-cols-1 md:grid-cols-2 gap-12 items-start" id="architecture">
                    <div className="space-y-6">
                        <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                            <Layers className="text-purple-500" size={24} /> Hybrid Architecture
                        </h2>
                        <p className="text-zinc-400 leading-relaxed">
                            Aether eschews the common "Electron-wrapper" approach. Instead, we use a hybrid native architecture designed for maximum throughput and minimum latency.
                        </p>

                        <div className="space-y-4">
                            <div className="p-4 bg-zinc-900/50 border border-zinc-800 rounded-lg">
                                <h4 className="text-white font-bold mb-1">1. Zig Core (libaether)</h4>
                                <p className="text-sm text-zinc-500">
                                    Handles heavy lifting: VT100/ANSI parsing, PTY management, and grid state. Written in Zig for memory safety and C-like speed.
                                </p>
                            </div>
                            <div className="p-4 bg-zinc-900/50 border border-zinc-800 rounded-lg">
                                <h4 className="text-white font-bold mb-1">2. Swift & Metal Frontend</h4>
                                <p className="text-sm text-zinc-500">
                                    MacOS-native UI layer. Uses Metal (GPU) to render glyphs directly from a texture atlas, bypassing CoreGraphics for speed.
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* Code Snippet */}
                    <div className="bg-zinc-950 rounded-xl border border-zinc-800 p-1 shadow-xl">
                        <div className="bg-black/50 rounded-lg p-6 font-mono text-xs text-zinc-400 leading-loose">
                            <span className="text-purple-500">struct</span> <span className="text-yellow-200">TermGrid</span> {'{'} <br />
                            &nbsp;&nbsp;<span className="text-blue-400">cells</span>: <span className="text-orange-400">ArrayList</span>&lt;Cell&gt;,<br />
                            &nbsp;&nbsp;<span className="text-blue-400">cursor</span>: <span className="text-yellow-200">CursorState</span>,<br />
                            &nbsp;&nbsp;<span className="text-blue-400">dirty_rect</span>: <span className="text-yellow-200">Rect</span>,<br />
                            <br />
                            &nbsp;&nbsp;<span className="text-zinc-500">// Zero copy render iterator</span><br />
                            &nbsp;&nbsp;<span className="text-purple-500">pub fn</span> <span className="text-blue-400">render_iter</span>(self: *Self) Iterator {'{'}...{'}'}<br />
                            {'}'}
                        </div>
                    </div>
                </section>

                {/* Rendering Pipeline */}
                <section className="space-y-8" id="rendering">
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Zap className="text-yellow-500" size={24} /> The Metal Pipeline
                    </h2>
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                        <div className="p-6 bg-zinc-900 border border-zinc-800 rounded-xl text-center relative group hover:border-zinc-700 transition-all">
                            <div className="text-xs text-zinc-500 uppercase font-bold mb-2">Step 1</div>
                            <div className="text-white font-bold text-lg">PTY Stream</div>
                            <div className="text-zinc-500 text-xs mt-2">Raw bytes from shell</div>
                            <ArrowRight className="absolute top-1/2 -right-6 transform -translate-y-1/2 text-zinc-700 hidden md:block z-10" />
                        </div>
                        <div className="p-6 bg-zinc-900 border border-zinc-800 rounded-xl text-center relative group hover:border-zinc-700 transition-all">
                            <div className="text-xs text-zinc-500 uppercase font-bold mb-2">Step 2</div>
                            <div className="text-white font-bold text-lg">Zig Parser</div>
                            <div className="text-zinc-500 text-xs mt-2">State updates & diffing</div>
                            <ArrowRight className="absolute top-1/2 -right-6 transform -translate-y-1/2 text-zinc-700 hidden md:block z-10" />
                        </div>
                        <div className="p-6 bg-zinc-900 border border-zinc-800 rounded-xl text-center relative group hover:border-zinc-700 transition-all">
                            <div className="text-xs text-zinc-500 uppercase font-bold mb-2">Step 3</div>
                            <div className="text-white font-bold text-lg">Instance Buffer</div>
                            <div className="text-zinc-500 text-xs mt-2">Geometry generation</div>
                            <ArrowRight className="absolute top-1/2 -right-6 transform -translate-y-1/2 text-zinc-700 hidden md:block z-10" />
                        </div>
                        <div className="p-6 bg-purple-900/20 border border-purple-500/30 rounded-xl text-center">
                            <div className="text-xs text-purple-400 uppercase font-bold mb-2">Step 4</div>
                            <div className="text-white font-bold text-lg">Metal Shader</div>
                            <div className="text-purple-400/70 text-xs mt-2">GPU Rasterization</div>
                        </div>
                    </div>
                </section>

                {/* Configuration Guide */}
                <section className="space-y-8" id="configuration">
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Settings className="text-blue-500" size={24} /> Configuration Guide
                    </h2>
                    <p className="text-zinc-400">
                        Aether looks for a configuration file at `~/.config/aether/aether.toml`.
                        We support both **TOML** and **JSON**.
                    </p>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                        {/* TOML */}
                        <div className="space-y-4">
                            <div className="flex items-center gap-2 text-zinc-300 font-mono text-sm">
                                <FileCode size={16} /> aether.toml
                            </div>
                            <div className="bg-zinc-900 rounded-xl border border-zinc-800 p-6 font-mono text-xs overflow-x-auto">
                                <pre className="text-zinc-300">
                                    <span className="text-purple-400">[window]</span>
                                    <br />
                                    <span className="text-blue-400">opacity</span> = <span className="text-yellow-300">0.95</span>
                                    <br />
                                    <span className="text-blue-400">blur</span> = <span className="text-yellow-300">true</span>
                                    <br />
                                    <br />
                                    <span className="text-purple-400">[font]</span>
                                    <br />
                                    <span className="text-blue-400">family</span> = <span className="text-green-300">"JetBrains Mono"</span>
                                    <br />
                                    <span className="text-blue-400">size</span> = <span className="text-yellow-300">14.0</span>
                                </pre>
                            </div>
                        </div>

                        {/* JSON */}
                        <div className="space-y-4">
                            <div className="flex items-center gap-2 text-zinc-300 font-mono text-sm">
                                <Code size={16} /> aether.json
                            </div>
                            <div className="bg-zinc-900 rounded-xl border border-zinc-800 p-6 font-mono text-xs overflow-x-auto">
                                <pre className="text-zinc-300">
                                    <span className="text-yellow-300">{"{"}</span>
                                    <br />
                                    &nbsp;&nbsp;<span className="text-green-300">"window"</span>: <span className="text-yellow-300">{"{"}</span>
                                    <br />
                                    &nbsp;&nbsp;&nbsp;&nbsp;<span className="text-green-300">"opacity"</span>: <span className="text-blue-400">0.95</span>,
                                    <br />
                                    &nbsp;&nbsp;&nbsp;&nbsp;<span className="text-green-300">"blur"</span>: <span className="text-blue-400">true</span>
                                    <br />
                                    &nbsp;&nbsp;<span className="text-yellow-300">{"}"}</span>,
                                    <br />
                                    &nbsp;&nbsp;<span className="text-green-300">"font"</span>: <span className="text-yellow-300">{"{"}</span>
                                    <br />
                                    &nbsp;&nbsp;&nbsp;&nbsp;<span className="text-green-300">"family"</span>: <span className="text-green-300">"JetBrains Mono"</span>,
                                    <br />
                                    &nbsp;&nbsp;&nbsp;&nbsp;<span className="text-green-300">"size"</span>: <span className="text-blue-400">14.0</span>
                                    <br />
                                    &nbsp;&nbsp;<span className="text-yellow-300">{"}"}</span>
                                    <br />
                                    <span className="text-yellow-300">{"}"}</span>
                                </pre>
                            </div>
                        </div>
                    </div>
                </section>

                {/* Shortcuts */}
                <section className="space-y-8" id="shortcuts">
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Keyboard className="text-green-500" size={24} /> Default Keybindings
                    </h2>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {[
                            { k: 'Cmd + D', d: 'Split Pane Vertically' },
                            { k: 'Cmd + Shift + D', d: 'Split Pane Horizontally' },
                            { k: 'Cmd + T', d: 'New Tab' },
                            { k: 'Cmd + W', d: 'Close Pane/Tab' },
                            { k: 'Cmd + [', d: 'Previous Tab' },
                            { k: 'Cmd + ]', d: 'Next Tab' },
                            { k: 'Cmd + K', d: 'Clear Buffer' },
                            { k: 'Cmd + ,', d: 'Open Preferences' },
                        ].map((item, i) => (
                            <div key={i} className="flex items-center justify-between p-4 bg-zinc-900/30 border border-zinc-800 rounded-lg hover:bg-zinc-900 transition-colors">
                                <span className="text-zinc-300">{item.d}</span>
                                <span className="font-mono text-xs bg-zinc-800 px-2 py-1 rounded text-zinc-400 border border-zinc-700">{item.k}</span>
                            </div>
                        ))}
                    </div>
                </section>

            </div>
        </div>
    );
};
