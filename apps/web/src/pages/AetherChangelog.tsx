import React from 'react';
import { Layout } from '../components/layout/Layout';
import { Zap, Palette, ArrowRight } from 'lucide-react';

export const AetherChangelog = () => {
    return (
        <Layout>
            <section className="pt-32 pb-20 bg-zinc-950 min-h-screen">
                <div className="container mx-auto px-4 max-w-4xl">
                    <div className="mb-16 text-center">
                        <div className="inline-flex items-center gap-2 px-3 py-1 bg-zinc-900 border border-zinc-800 text-zinc-400 text-xs font-mono rounded-full mb-6">
                            <span className="w-2 h-2 bg-purple-500 rounded-full animate-pulse"></span>
                            DEVELOPMENT LOG
                        </div>
                        <h1 className="text-4xl md:text-6xl font-bold text-white mb-4">The Aether Journey</h1>
                        <p className="text-zinc-400 text-lg max-w-2xl mx-auto">
                            Tracking the evolution of the world's fastest macOS terminal.
                        </p>
                    </div>

                    <div className="relative border-l border-zinc-800 ml-4 md:ml-0 space-y-16">
                        {/* v0.1.0 */}
                        <div className="relative pl-8 md:pl-0">
                            <div className="md:hidden absolute -left-1.5 top-2 w-3 h-3 bg-purple-500 rounded-full shadow-[0_0_10px_rgba(168,85,247,0.5)]"></div>

                            <div className="grid grid-cols-1 md:grid-cols-[120px_1fr] gap-8">
                                <div className="hidden md:flex flex-col items-end pt-1 relative">
                                    <div className="absolute right-[-37px] top-2 w-3 h-3 bg-purple-500 rounded-full shadow-[0_0_10px_rgba(168,85,247,0.5)] z-10"></div>
                                    <span className="font-mono text-purple-400 font-bold">v0.1.0</span>
                                    <span className="text-zinc-600 text-xs font-mono mt-1">Feb 17, 2026</span>
                                </div>

                                <div className="md:hidden flex items-baseline gap-3 mb-2">
                                    <span className="font-mono text-purple-400 font-bold text-xl">v0.1.0</span>
                                    <span className="text-zinc-600 text-xs font-mono">Feb 17, 2026</span>
                                </div>

                                <div className="bg-zinc-900/30 border border-zinc-800 rounded-2xl p-6 md:p-8 hover:border-purple-500/30 transition-colors">
                                    <h3 className="text-2xl font-bold text-white mb-4">The Genesis Release</h3>
                                    <p className="text-zinc-400 mb-8 leading-relaxed">
                                        Initial public release. The foundation of Aether is built on a custom Zig-based PTY engine and a Metal-accelerated renderer.
                                    </p>

                                    <div className="space-y-6">
                                        <div>
                                            <h4 className="flex items-center gap-2 text-white font-bold mb-3 text-sm uppercase tracking-wider">
                                                <Zap size={16} className="text-yellow-500" /> Core Engine
                                            </h4>
                                            <ul className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>Sub-16ms input latency</span>
                                                </li>
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>60FPS stable rendering</span>
                                                </li>
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>Native MacOS windowing</span>
                                                </li>
                                            </ul>
                                        </div>

                                        <div>
                                            <h4 className="flex items-center gap-2 text-white font-bold mb-3 text-sm uppercase tracking-wider">
                                                <Palette size={16} className="text-blue-500" /> Features
                                            </h4>
                                            <ul className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>TOML Configuration</span>
                                                </li>
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>Ligature Support</span>
                                                </li>
                                                <li className="flex items-center gap-2 text-zinc-400 text-sm">
                                                    <ArrowRight size={12} className="text-zinc-600" />
                                                    <span>24-bit TrueColor</span>
                                                </li>
                                            </ul>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Pre-Alpha (History) */}
                        <div className="relative pl-8 md:pl-0 opacity-50 hover:opacity-100 transition-opacity">
                            <div className="md:hidden absolute -left-1.5 top-2 w-3 h-3 bg-zinc-700 rounded-full"></div>

                            <div className="grid grid-cols-1 md:grid-cols-[120px_1fr] gap-8">
                                <div className="hidden md:flex flex-col items-end pt-1 relative">
                                    <div className="absolute right-[-37px] top-2 w-3 h-3 bg-zinc-700 rounded-full z-10"></div>
                                    <span className="font-mono text-zinc-500 font-bold">Pre-Alpha</span>
                                    <span className="text-zinc-700 text-xs font-mono mt-1">Jan 2026</span>
                                </div>
                                <div className="md:hidden flex items-baseline gap-3 mb-2">
                                    <span className="font-mono text-zinc-500 font-bold text-xl">Pre-Alpha</span>
                                </div>

                                <div className="bg-zinc-950 border border-zinc-900 rounded-2xl p-6">
                                    <h3 className="text-xl font-bold text-zinc-300 mb-2">Proof of Concept</h3>
                                    <p className="text-zinc-500">
                                        Validated the feasibility of bridging Zig and Swift/Metal.
                                        Achieved first successful character render in a native window.
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>
        </Layout>
    );
};
