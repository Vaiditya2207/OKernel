import React from 'react';
import { Link } from 'react-router-dom';
import { ExternalLink, Globe, FileText, Package, Cpu, Terminal, Code, Database, Layers, Zap, Book, Download } from 'lucide-react';

interface SiteLink {
    path: string;
    title: string;
    description: string;
    icon: React.ReactNode;
}

interface SiteSection {
    title: string;
    links: SiteLink[];
}

const SITEMAP: SiteSection[] = [
    {
        title: "Main Pages",
        links: [
            { path: "/", title: "Home", description: "Landing page with project overview and features", icon: <Globe size={16} /> },
            { path: "/packages", title: "Packages", description: "OKernel CLI packages and language poll", icon: <Package size={16} /> },
            { path: "/about", title: "About", description: "Project philosophy and team information", icon: <FileText size={16} /> },
            { path: "/changelog", title: "Changelog", description: "Version history and release notes", icon: <FileText size={16} /> },
            { path: "/aether/download", title: "Download Aether", description: "Get the latest Aether release", icon: <Download size={16} /> },
        ]
    },
    {
        title: "Applications",
        links: [
            { path: "/aether", title: "Aether Terminal", description: "GPU-accelerated terminal emulator for macOS", icon: <Terminal size={16} /> },
            { path: "/apps/visualizer", title: "Code Tracer", description: "Python execution visualizer with hardware inspection", icon: <Cpu size={16} /> },
            { path: "/apps/scheduler", title: "CPU Scheduler", description: "Interactive process scheduling simulator", icon: <Layers size={16} /> },
            { path: "/apps/shell", title: "Shell Maker", description: "Custom Unix shell builder", icon: <Terminal size={16} /> },
        ]
    },
    {
        title: "Documentation - Getting Started",
        links: [
            { path: "/docs", title: "Introduction", description: "Overview of the OKernel Platform", icon: <Book size={16} /> },
            { path: "/docs/quickstart", title: "Quick Start", description: "Get up and running in 5 minutes", icon: <Zap size={16} /> },
            { path: "/docs/packages", title: "Packages", description: "Install OKernel CLI tools locally", icon: <Package size={16} /> },
            { path: "/docs/sitemap", title: "Sitemap", description: "Complete website navigation map", icon: <Globe size={16} /> },
        ]
    },
    {
        title: "Documentation - Architecture",
        links: [
            { path: "/docs/architecture", title: "System Design", description: "High-level overview of the SysCore Engine", icon: <Globe size={16} /> },
            { path: "/docs/architecture/tracing", title: "Trace Engine", description: "How Python execution is intercepted", icon: <Layers size={16} /> },
            { path: "/docs/architecture/sympathy", title: "Code Tracer", description: "Machine Sympathy & Hardware Inspector", icon: <Zap size={16} /> },
            { path: "/docs/aether", title: "Aether Architecture", description: "Deep dive into Aether's Zig/Metal engine", icon: <Terminal size={16} /> },
        ]
    },
    {
        title: "Documentation - Modules",
        links: [
            { path: "/docs/modules/scheduler", title: "CPU Scheduler", description: "Process scheduling simulation", icon: <Cpu size={16} /> },
            { path: "/docs/modules/shell", title: "Shell Maker", description: "Custom Shell implementation", icon: <Terminal size={16} /> },
        ]
    },
    {
        title: "Documentation - API Reference",
        links: [
            { path: "/docs/api/syscore", title: "SysCore API", description: "Kernel system calls and utilities", icon: <Code size={16} /> },
            { path: "/docs/api/persistence", title: "Persistence", description: "Data storage and session management", icon: <Database size={16} /> },
        ]
    },
    {
        title: "External Resources",
        links: [
            { path: "https://github.com/vaiditya-okernel/OKernel", title: "GitHub Repository", description: "Source code and issue tracker", icon: <ExternalLink size={16} /> },
            { path: "https://pypi.org/project/okernel/", title: "PyPI Package", description: "Python package distribution", icon: <Package size={16} /> },
        ]
    }
];

export const SitemapPage: React.FC = () => {
    return (
        <article className="max-w-4xl">
            {/* Header */}
            <header className="mb-12">
                <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 bg-green-500/10 rounded-lg">
                        <Globe className="text-green-400" size={24} />
                    </div>
                    <h1 className="text-3xl font-bold text-white tracking-tight">Sitemap</h1>
                </div>
                <p className="text-zinc-400 text-lg leading-relaxed">
                    Complete navigation map of all pages and resources available on the OKernel website.
                </p>
            </header>

            {/* Sitemap Grid */}
            <div className="space-y-10">
                {SITEMAP.map((section) => (
                    <section key={section.title}>
                        <h2 className="text-lg font-semibold text-white mb-4 pb-2 border-b border-zinc-800">
                            {section.title}
                        </h2>
                        <div className="grid gap-3">
                            {section.links.map((link) => {
                                const isExternal = link.path.startsWith('http');

                                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                                const LinkComponent: any = isExternal ? 'a' : Link;

                                const linkProps = isExternal
                                    ? { href: link.path, target: "_blank", rel: "noopener noreferrer" }
                                    : { to: link.path };

                                return (
                                    <LinkComponent
                                        key={link.path}
                                        {...linkProps}
                                        className="group flex items-start gap-4 p-4 bg-zinc-900/50 border border-zinc-800/50 rounded-lg hover:border-green-500/30 hover:bg-zinc-900 transition-all"
                                    >
                                        <div className="p-2 bg-zinc-800 rounded-md group-hover:bg-green-500/10 transition-colors">
                                            <span className="text-zinc-400 group-hover:text-green-400 transition-colors">
                                                {link.icon}
                                            </span>
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center gap-2">
                                                <span className="font-medium text-white group-hover:text-green-400 transition-colors">
                                                    {link.title}
                                                </span>
                                                {isExternal && (
                                                    <ExternalLink size={12} className="text-zinc-500" />
                                                )}
                                            </div>
                                            <p className="text-sm text-zinc-500 mt-1">{link.description}</p>
                                            <code className="text-xs text-zinc-600 font-mono mt-2 block">
                                                {link.path}
                                            </code>
                                        </div>
                                    </LinkComponent>
                                );
                            })}
                        </div>
                    </section>
                ))}
            </div>

            {/* Stats */}
            <div className="mt-12 p-6 bg-zinc-900/50 border border-zinc-800 rounded-lg">
                <h3 className="text-sm font-semibold text-zinc-400 uppercase tracking-wider mb-4">Site Statistics</h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div>
                        <div className="text-2xl font-bold text-green-400 font-mono">
                            {SITEMAP.reduce((acc, s) => acc + s.links.filter(l => !l.path.startsWith('http')).length, 0)}
                        </div>
                        <div className="text-xs text-zinc-500">Internal Pages</div>
                    </div>
                    <div>
                        <div className="text-2xl font-bold text-blue-400 font-mono">
                            {SITEMAP.filter(s => s.title.includes('Documentation')).reduce((acc, s) => acc + s.links.length, 0)}
                        </div>
                        <div className="text-xs text-zinc-500">Doc Pages</div>
                    </div>
                    <div>
                        <div className="text-2xl font-bold text-yellow-400 font-mono">3</div>
                        <div className="text-xs text-zinc-500">Applications</div>
                    </div>
                    <div>
                        <div className="text-2xl font-bold text-zinc-400 font-mono">
                            {SITEMAP.reduce((acc, s) => acc + s.links.filter(l => l.path.startsWith('http')).length, 0)}
                        </div>
                        <div className="text-xs text-zinc-500">External Links</div>
                    </div>
                </div>
            </div>
        </article>
    );
};
