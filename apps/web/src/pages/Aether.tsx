import React from 'react';
import { Layout } from '../components/layout/Layout';
import { Button } from '../components/ui/Button';
import { Zap, Layers, Cpu, Terminal, Download, ArrowRight, Settings, Heart, Users, GitMerge } from 'lucide-react';
import { Link } from 'react-router-dom';

export const Aether = () => {
    return (
        <Layout>
            {/* Hero Section */}
            <section className="relative pt-32 pb-32 overflow-hidden bg-zinc-950 min-h-screen flex flex-col justify-center">

                {/* Background Elements */}
                <div className="absolute top-0 left-0 right-0 h-[500px] bg-purple-900/10 blur-[120px] pointer-events-none"></div>
                <div className="absolute inset-0 bg-[linear-gradient(to_right,#80808005_1px,transparent_1px),linear-gradient(to_bottom,#80808005_1px,transparent_1px)] bg-[size:40px_40px] pointer-events-none"></div>

                <div className="container mx-auto px-4 text-center relative z-10">
                    <div className="inline-flex items-center gap-2 px-3 py-1 bg-zinc-900 border border-zinc-800 text-zinc-400 text-xs font-mono rounded-full mb-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
                        <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse shadow-[0_0_10px_#22c55e]"></span>
                        SYSTEM ONLINE: v0.1.0 ALPHA
                    </div>

                    <h1 className="text-6xl md:text-9xl font-bold tracking-tight text-white mb-8 animate-in fade-in slide-in-from-bottom-8 duration-1000 leading-tight">
                        Aether <span className="text-transparent bg-clip-text bg-gradient-to-r from-purple-400 to-blue-500">Terminal</span>
                    </h1>

                    <p className="text-xl md:text-2xl text-zinc-400 max-w-3xl mx-auto mb-12 leading-relaxed animate-in fade-in slide-in-from-bottom-12 duration-1000 delay-200">
                        The world's fastest macOS terminal. <br />
                        <span className="text-white">Engineered for flow state.</span>
                    </p>

                    <div className="flex flex-col sm:flex-row gap-6 justify-center items-center animate-in fade-in slide-in-from-bottom-16 duration-1000 delay-300">
                        <Link to="/aether/download">
                            <button className="group relative h-16 pl-8 pr-20 text-xl overflow-hidden rounded-full bg-slate-50 transition-all hover:scale-105 active:scale-95 shadow-[0_0_40px_rgba(255,255,255,0.3)] hover:shadow-[0_0_80px_rgba(255,255,255,0.5)]">
                                <div className="absolute right-2 top-2 h-12 w-12 rounded-full bg-black flex items-center justify-center transition-all group-hover:bg-purple-600">
                                    <ArrowRight className="text-white" size={24} />
                                </div>
                                <span className="relative text-black font-bold">Download App</span>
                            </button>
                        </Link>

                        <Link to="/docs/aether">
                            <button className="px-10 h-16 rounded-full border border-zinc-800 text-zinc-400 font-bold hover:bg-zinc-900 hover:text-white transition-all text-lg">
                                Read the Architecture
                            </button>
                        </Link>
                    </div>
                </div>

                {/* Floating Hero Image */}
                <div className="container mx-auto px-4 mt-24 mb-20 animate-in fade-in slide-in-from-bottom-24 duration-1000 delay-500">
                    <div className="relative w-full rounded-2xl bg-gradient-to-b from-zinc-800 to-zinc-950 p-1 shadow-2xl transform transition-transform duration-700 hover:scale-[1.01]">
                        <div className="absolute inset-0 bg-black rounded-2xl"></div>
                        <img
                            src="/assets/Aether.png"
                            alt="Aether Terminal Hero"
                            className="relative w-full h-auto rounded-xl object-cover z-10 shadow-2xl"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-transparent pointer-events-none rounded-2xl z-20"></div>
                    </div>
                </div>
            </section>

            {/* Performance Stats (Brag Mode) */}
            <section className="py-32 bg-zinc-950 border-y border-zinc-900 relative">
                <div className="container mx-auto px-4">
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-center">
                        {[
                            { val: '<16ms', label: 'Input Latency' },
                            { val: '120fps', label: 'Max Refresh Rate' },
                            { val: '0.9s', label: 'Startup Time' },
                            { val: 'Runes', label: 'GPU Rendering' },
                        ].map((stat, i) => (
                            <div key={i} className="p-8 rounded-2xl bg-black border border-zinc-900 hover:border-purple-500/50 transition-all group">
                                <div className="text-4xl md:text-5xl font-bold text-white mb-2 font-mono group-hover:text-purple-400 transition-colors">{stat.val}</div>
                                <div className="text-zinc-500 text-xs uppercase tracking-widest font-bold">{stat.label}</div>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Section 1: The Origin Story */}
            <section className="py-32 bg-black overflow-hidden relative">
                <div className="absolute top-0 right-0 w-1/3 h-full bg-gradient-to-l from-purple-900/10 to-transparent pointer-events-none"></div>
                <div className="container mx-auto px-4">
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
                        <div className="max-w-3xl">
                            <div className="inline-flex items-center gap-2 text-purple-500 mb-6">
                                <Cpu size={20} />
                                <span className="uppercase tracking-widest font-bold text-sm">The Origin Story</span>
                            </div>
                            <h2 className="text-4xl md:text-6xl font-bold text-white mb-8 leading-tight">
                                We were tired of <br /> <span className="text-zinc-600 line-through">Electron</span>.
                            </h2>
                            <div className="space-y-6 text-lg text-zinc-400 leading-relaxed">
                                <p>
                                    Modern terminals have become bloated web browsers disguised as system tools.
                                    Consuming 500MB of RAM just to blink a cursor? <span className="text-white">Unacceptable.</span>
                                </p>
                                <p>
                                    So we went back to first principles. Aether is built with <strong>Zig</strong> for the simulation core
                                    and <strong>Apple Metal</strong> for the rendering pipeline.
                                    No optimizations spared. No web views allowed.
                                </p>
                                <p>
                                    The result isn't just fast. It's <em>instant</em>.
                                </p>
                            </div>
                        </div>

                        {/* Abstract Chip Image */}
                        <div className="relative group animate-in fade-in slide-in-from-right-8 duration-1000 delay-300">
                            <div className="absolute -inset-1 bg-gradient-to-r from-purple-600 to-blue-600 rounded-2xl blur opacity-20 group-hover:opacity-40 transition duration-1000"></div>
                            <img
                                src="/assets/Aether_Chip.png"
                                alt="Aether Core Architecture"
                                className="relative w-full rounded-2xl shadow-2xl border border-zinc-800 bg-black object-cover aspect-square"
                            />
                        </div>
                    </div>
                </div>
            </section>

            {/* Section 2: Workflow (Nvim) */}
            <section className="py-32 bg-zinc-950 text-white">
                <div className="container mx-auto px-4">
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-20 items-center">
                        <div className="relative group">
                            <div className="absolute -inset-1 bg-gradient-to-r from-purple-600 to-blue-600 rounded-xl blur opacity-20 group-hover:opacity-40 transition duration-1000"></div>
                            <img
                                src="/assets/Nvim.png"
                                alt="Neovim in Aether"
                                className="relative w-full rounded-xl shadow-2xl border border-zinc-800 bg-black"
                            />
                        </div>
                        <div>
                            <div className="inline-flex items-center gap-2 text-green-400 mb-6">
                                <Terminal size={20} />
                                <span className="uppercase tracking-widest font-bold text-sm">Pro Workflow</span>
                            </div>
                            <h3 className="text-3xl md:text-5xl font-bold mb-6">
                                Command Line <br /> <span className="text-green-500">Nirvana</span>.
                            </h3>
                            <p className="text-zinc-400 text-lg mb-8 leading-relaxed">
                                Whether you're a VIM purist or a CLI power user, Aether respects your tools.
                                Full support for the Kitty Keyboard Protocol means your keybindings work exactly as intended.
                                Ligatures render crisp and pixel-perfect.
                            </p>
                            <ul className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <li className="flex items-center gap-3 text-zinc-300">
                                    <div className="w-1.5 h-1.5 bg-green-500 rounded-full"></div>
                                    24-bit TrueColor
                                </li>
                                <li className="flex items-center gap-3 text-zinc-300">
                                    <div className="w-1.5 h-1.5 bg-green-500 rounded-full"></div>
                                    Font Ligatures
                                </li>
                                <li className="flex items-center gap-3 text-zinc-300">
                                    <div className="w-1.5 h-1.5 bg-green-500 rounded-full"></div>
                                    Kitty Protocol
                                </li>
                                <li className="flex items-center gap-3 text-zinc-300">
                                    <div className="w-1.5 h-1.5 bg-green-500 rounded-full"></div>
                                    Undercurl Support
                                </li>
                            </ul>
                        </div>
                    </div>
                </div>
            </section>

            {/* Section 3: Multiplexing */}
            <section className="py-32 bg-black border-t border-zinc-900">
                <div className="container mx-auto px-4">
                    <div className="text-center max-w-3xl mx-auto mb-16">
                        <div className="inline-flex items-center gap-2 text-blue-400 mb-6">
                            <Layers size={20} />
                            <span className="uppercase tracking-widest font-bold text-sm">Window Management</span>
                        </div>
                        <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">Split. Stack. Conquer.</h2>
                        <p className="text-zinc-400 text-lg">
                            Forget `tmux`. Aether has a native, GPU-accelerated multiplexer built right in.
                        </p>
                    </div>

                    <div className="max-w-6xl mx-auto relative group">
                        <div className="absolute -inset-2 bg-gradient-to-r from-blue-600 to-cyan-500 rounded-xl blur opacity-10 group-hover:opacity-30 transition duration-1000"></div>
                        <img
                            src="/assets/Multiple_Panes_Aether.png"
                            alt="Multiplexing"
                            className="relative w-full rounded-xl border border-zinc-800 shadow-2xl bg-zinc-900"
                        />
                    </div>
                </div>
            </section>

            {/* Section 4: Configuration */}
            <section className="py-32 bg-zinc-950">
                <div className="container mx-auto px-4">
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
                        <div className="order-2 lg:order-1">
                            <div className="bg-black border border-zinc-800 rounded-xl overflow-hidden shadow-2xl">
                                <div className="flex items-center px-4 py-3 bg-zinc-900 border-b border-zinc-800">
                                    <div className="flex gap-2">
                                        <div className="w-3 h-3 rounded-full bg-red-500/20 border border-red-500/50"></div>
                                        <div className="w-3 h-3 rounded-full bg-yellow-500/20 border border-yellow-500/50"></div>
                                        <div className="w-3 h-3 rounded-full bg-green-500/20 border border-green-500/50"></div>
                                    </div>
                                    <div className="ml-4 text-xs font-mono text-zinc-500">~/.config/aether/aether.toml</div>
                                </div>
                                <div className="p-6 font-mono text-sm leading-relaxed overflow-x-auto">
                                    <pre className="text-zinc-300">
                                        <span className="text-purple-400">[window]</span> <br />
                                        <span className="text-blue-400">opacity</span> = <span className="text-yellow-300">0.90</span> <br />
                                        <span className="text-blue-400">blur_radius</span> = <span className="text-yellow-300">20.0</span> <br />
                                        <span className="text-blue-400">decorations</span> = <span className="text-green-300">"buttonless"</span> <br />
                                        <br />
                                        <span className="text-purple-400">[keys]</span> <br />
                                        <span className="text-blue-400">"Cmd+T"</span> = <span className="text-green-300">"new_tab"</span> <br />
                                        <span className="text-blue-400">"Cmd+W"</span> = <span className="text-green-300">"close_pane"</span>
                                    </pre>
                                </div>
                            </div>
                        </div>

                        <div className="order-1 lg:order-2">
                            <div className="inline-flex items-center gap-2 text-yellow-500 mb-6">
                                <Settings size={20} />
                                <span className="uppercase tracking-widest font-bold text-sm">Total Control</span>
                            </div>
                            <h3 className="text-4xl md:text-5xl font-bold text-white mb-6">
                                Configuration as <br /> <span className="text-yellow-500">Code</span>.
                            </h3>
                            <p className="text-zinc-400 text-lg mb-8">
                                Define your entire workflow in a single TOML or JSON file.
                                Sync it across machines using dotfiles.
                                Watch your changes apply instantly with zero downtime.
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Section 5: Performance Deep Dive */}
            <section className="py-32 bg-black border-t border-zinc-900">
                <div className="container mx-auto px-4">
                    <div className="text-center mb-20">
                        <h2 className="text-3xl md:text-5xl font-bold text-white mb-6">Benchmarks don't lie.</h2>
                        <p className="text-zinc-400 text-lg max-w-2xl mx-auto">
                            We benchmarked Aether against the most popular terminals on macOS.
                            The results speak for themselves.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-12">

                        {/* Chart 1: Input Latency (Lower is Better) */}
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <Zap className="text-purple-500" />
                                <h3 className="text-xl font-bold text-white">Input Latency</h3>
                            </div>
                            <div className="space-y-4">
                                {/* Aether */}
                                <div className="space-y-2">
                                    <div className="flex justify-between text-zinc-300 text-xs font-mono uppercase tracking-wider">
                                        <span>Aether</span>
                                        <span className="text-purple-400">6ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-gradient-to-r from-purple-500 to-blue-500 w-[6%] rounded-full shadow-[0_0_10px_#a855f7]"></div>
                                    </div>
                                </div>
                                {/* Kitty */}
                                <div className="space-y-2 opacity-70">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Kitty</span>
                                        <span>7ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-700 w-[7%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* iTerm2 */}
                                <div className="space-y-2 opacity-50">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>iTerm2</span>
                                        <span>25ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[25%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* Hyper */}
                                <div className="space-y-2 opacity-30">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Hyper</span>
                                        <span>50ms+</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[50%] rounded-full"></div>
                                    </div>
                                </div>
                            </div>
                            <p className="text-xs text-zinc-600 pt-2">Input to display latency. Lower is better.</p>
                        </div>

                        {/* Chart 2: Startup Time (Lower is Better) */}
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <Zap className="text-blue-500" />
                                <h3 className="text-xl font-bold text-white">Startup Time</h3>
                            </div>
                            <div className="space-y-4">
                                {/* Aether */}
                                <div className="space-y-2">
                                    <div className="flex justify-between text-zinc-300 text-xs font-mono uppercase tracking-wider">
                                        <span>Aether</span>
                                        <span className="text-blue-400">40ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-gradient-to-r from-blue-500 to-cyan-500 w-[8%] rounded-full shadow-[0_0_10px_#3b82f6]"></div>
                                    </div>
                                </div>
                                {/* Alacritty */}
                                <div className="space-y-2 opacity-70">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Alacritty</span>
                                        <span>180ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-700 w-[30%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* iTerm2 */}
                                <div className="space-y-2 opacity-50">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>iTerm2</span>
                                        <span>450ms</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[65%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* Hyper */}
                                <div className="space-y-2 opacity-30">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Electron Apps</span>
                                        <span>1000ms+</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[100%] rounded-full"></div>
                                    </div>
                                </div>
                            </div>
                            <p className="text-xs text-zinc-600 pt-2">Cold boot to interactive shell. Lower is better.</p>
                        </div>

                        {/* Chart 3: Memory Footprint (Lower is Better) */}
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <Cpu className="text-green-500" />
                                <h3 className="text-xl font-bold text-white">Idle Memory</h3>
                            </div>
                            <div className="space-y-4">
                                {/* Aether */}
                                <div className="space-y-2">
                                    <div className="flex justify-between text-zinc-300 text-xs font-mono uppercase tracking-wider">
                                        <span>Aether</span>
                                        <span className="text-green-400">35MB</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-gradient-to-r from-green-500 to-emerald-500 w-[10%] rounded-full shadow-[0_0_10px_#22c55e]"></div>
                                    </div>
                                </div>
                                {/* Alacritty */}
                                <div className="space-y-2 opacity-70">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Alacritty</span>
                                        <span>45MB</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-700 w-[15%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* iTerm2 */}
                                <div className="space-y-2 opacity-50">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>iTerm2</span>
                                        <span>120MB</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[35%] rounded-full"></div>
                                    </div>
                                </div>
                                {/* Hyper */}
                                <div className="space-y-2 opacity-30">
                                    <div className="flex justify-between text-zinc-500 text-xs font-mono uppercase tracking-wider">
                                        <span>Electron Apps</span>
                                        <span>350MB+</span>
                                    </div>
                                    <div className="h-2 bg-zinc-900 rounded-full overflow-hidden">
                                        <div className="h-full bg-zinc-800 w-[90%] rounded-full"></div>
                                    </div>
                                </div>
                            </div>
                            <p className="text-xs text-zinc-600 pt-2">RAM usage with no active tabs. Lower is better.</p>
                        </div>

                    </div>
                </div>
            </section>

            {/* Section 6: Community (The Cult) */}
            <section className="py-32 bg-zinc-950">
                <div className="container mx-auto px-4 text-center">
                    <div className="inline-flex items-center gap-2 text-pink-500 mb-6">
                        <Heart size={20} />
                        <span className="uppercase tracking-widest font-bold text-sm">Open Source</span>
                    </div>
                    <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">Join the Cult.</h2>
                    <p className="text-xl text-zinc-400 max-w-2xl mx-auto mb-12">
                        Aether is built by hackers, for hackers.
                        Star us on GitHub, join the Discord, and help build the last terminal you'll ever need.
                    </p>

                    <div className="flex flex-wrap justify-center gap-6">
                        <a href="https://github.com/Vaiditya2207/OKernel" target="_blank" rel="noopener noreferrer">
                            <Button size="lg" className="h-16 px-8 text-lg bg-white hover:bg-zinc-200 text-black font-bold rounded-full shadow-[0_0_20px_rgba(255,255,255,0.3)] hover:shadow-[0_0_30px_rgba(255,255,255,0.5)] transition-all transform hover:scale-105">
                                <GitMerge className="mr-3" /> Star on GitHub
                            </Button>
                        </a>
                        <a href="#" className="pointer-events-none opacity-50">
                            <Button size="lg" className="h-16 px-8 text-lg bg-[#5865F2] hover:bg-[#4752C4] text-white font-bold border border-transparent rounded-full shadow-lg">
                                <Users className="mr-3" /> Join Discord (Soon)
                            </Button>
                        </a>
                    </div>
                </div>
            </section>

            {/* Final CTA */}
            <section className="py-40 bg-black relative overflow-hidden">
                <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(168,85,247,0.15),transparent_70%)] pointer-events-none"></div>
                <div className="container mx-auto px-4 text-center relative z-10">
                    <h2 className="text-5xl md:text-7xl font-bold text-white mb-8 tracking-tight">
                        It's time to <span className="text-purple-500">switch</span>.
                    </h2>
                    <p className="text-xl text-zinc-500 mb-12 max-w-xl mx-auto">
                        Stop waiting for your terminal. Start waiting for your code.
                    </p>

                    <Link to="/aether/download">
                        <button className="group relative h-20 pl-10 pr-24 text-2xl overflow-hidden rounded-full bg-white transition-all hover:scale-105 shadow-[0_0_60px_rgba(168,85,247,0.4)] hover:shadow-[0_0_100px_rgba(168,85,247,0.6)]">
                            <div className="absolute right-3 top-3 h-14 w-14 rounded-full bg-black flex items-center justify-center transition-all group-hover:bg-purple-600 group-hover:scale-110">
                                <Download className="text-white" size={28} />
                            </div>
                            <span className="relative text-black font-bold tracking-tight">Download for macOS</span>
                        </button>
                    </Link>
                    <div className="mt-6 text-zinc-600 text-sm font-mono">
                        Requires macOS 14.0+ (Sonoma) • Apple Silicon Recommended
                    </div>
                </div>
            </section>
        </Layout>
    );
};
