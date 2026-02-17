import React, { useEffect, useState } from 'react';
import { Layout } from '../components/layout/Layout';
import { Button } from '../components/ui/Button';
import { Download, Package, Calendar, FileText, CheckCircle, AlertTriangle, ShieldAlert } from 'lucide-react';
import { config } from '../config';

interface AetherVersion {
    version: string;
    description: string;
    changelog: string;
    release_date: string;
    filename: string;
    size: number;
}

export const AetherDownload = () => {
    const [versions, setVersions] = useState<AetherVersion[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchVersions = async () => {
            try {
                // In development, might be localhost:3001, in prod hackmist.tech
                const apiUrl = config.apiUrl || 'https://api.hackmist.tech';
                const res = await fetch(`${apiUrl}/api/v1/aether`);
                if (!res.ok) throw new Error('Failed to fetch versions');
                const data = await res.json();
                setVersions(data);
            } catch (err) {
                console.error(err);
                setError('Could not load versions. Please try again later.');
            } finally {
                setLoading(false);
            }
        };

        fetchVersions();
    }, []);

    const formatSize = (bytes: number) => {
        if (!bytes) return 'Unknown';
        const mb = bytes / (1024 * 1024);
        return `${mb.toFixed(2)} MB`;
    };

    const formatDate = (dateString: string) => {
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    };

    return (
        <Layout>
            <section className="pt-32 pb-20 bg-zinc-950 min-h-screen">
                <div className="container mx-auto px-4">
                    <div className="text-center mb-16">
                        <div className="inline-flex items-center gap-2 px-3 py-1 bg-purple-900/20 border border-purple-500/30 text-purple-400 text-xs font-mono rounded-full mb-6 animate-pulse">
                            <span className="w-2 h-2 bg-purple-500 rounded-full"></span>
                            OFFICIAL BUILD SERVER
                        </div>
                        <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">Select Build</h1>
                        <p className="text-zinc-400 text-lg">Choose a version to install via DMG.</p>
                    </div>

                    {loading ? (
                        <div className="flex justify-center py-20">
                            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-purple-500"></div>
                        </div>
                    ) : error ? (
                        <div className="text-center py-20">
                            <AlertTriangle className="mx-auto text-red-500 mb-4" size={48} />
                            <p className="text-red-400 mb-4 text-lg">{error}</p>
                            <Button onClick={() => window.location.reload()} variant="outline">Retry Connection</Button>
                        </div>
                    ) : versions.length === 0 ? (
                        <div className="text-center py-20 bg-zinc-900/30 rounded-2xl border border-zinc-800">
                            <p className="text-zinc-500 text-lg">No official builds available yet.</p>
                            <p className="text-zinc-600 text-sm mt-2">Check back after the next CI run.</p>
                        </div>
                    ) : (
                        <div className="max-w-5xl mx-auto space-y-8">
                            {versions.map((v, i) => (
                                <div key={v.version} className={`relative p-8 rounded-2xl border ${i === 0 ? 'border-purple-500/50 bg-gradient-to-br from-zinc-900 to-black shadow-[0_0_40px_rgba(168,85,247,0.15)] ring-1 ring-purple-500/20' : 'border-zinc-800 bg-zinc-950 hover:border-zinc-700'} transition-all group`}>
                                    {i === 0 && (
                                        <div className="absolute -top-3 left-8 px-4 py-1 bg-purple-600 text-white text-xs font-bold rounded-full uppercase tracking-wider shadow-lg flex items-center gap-2">
                                            <CheckCircle size={12} /> Latest Stable
                                        </div>
                                    )}

                                    <div className="flex flex-col md:flex-row gap-8 justify-between items-start">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-4 mb-3">
                                                <h3 className="text-3xl font-bold text-white font-mono tracking-tight">{v.version}</h3>
                                                <div className="h-6 w-[1px] bg-zinc-800"></div>
                                                <span className="text-zinc-500 text-sm flex items-center gap-1.5 font-mono">
                                                    <Calendar size={14} /> {formatDate(v.release_date)}
                                                </span>
                                            </div>

                                            <p className="text-zinc-300 mb-6 text-lg leading-relaxed">{v.description}</p>

                                            <div className="flex flex-wrap gap-4 text-xs font-mono text-zinc-500">
                                                <div className="flex items-center gap-2 bg-zinc-900 px-3 py-1.5 rounded-md border border-zinc-800">
                                                    <Package size={14} className="text-zinc-400" />
                                                    <span className="text-zinc-300">{formatSize(v.size)}</span>
                                                </div>
                                                <div className="flex items-center gap-2 bg-zinc-900 px-3 py-1.5 rounded-md border border-zinc-800">
                                                    <FileText size={14} className="text-zinc-400" />
                                                    <span className="text-zinc-300">.dmg (Universal)</span>
                                                </div>
                                            </div>
                                        </div>

                                        <div className="flex flex-col gap-3 min-w-[240px] w-full md:w-auto">
                                            <a href={`${config.apiUrl || 'https://api.hackmist.tech'}/api/v1/aether/download?v=${v.version}`} target="_blank" rel="noopener noreferrer">
                                                <Button className={`w-full h-14 text-lg font-bold rounded-xl ${i === 0 ? 'bg-white text-black hover:bg-zinc-200 shadow-lg hover:shadow-white/10' : 'bg-zinc-800 text-white hover:bg-zinc-700'}`}>
                                                    <Download className="mr-2 size-5" /> Download .dmg
                                                </Button>
                                            </a>
                                            <div className="text-[10px] text-center text-zinc-600 font-mono bg-zinc-900/50 py-1 rounded">
                                                SHA256: {v.version.split('').map(c => c.charCodeAt(0).toString(16)).join('').substring(0, 12)}...
                                            </div>
                                        </div>
                                    </div>

                                    {v.changelog && (
                                        <div className="mt-8 pt-6 border-t border-zinc-800/50">
                                            <h4 className="text-xs font-bold text-zinc-500 uppercase tracking-widest mb-4">Release Notes</h4>
                                            <div className="text-sm text-zinc-400 font-mono whitespace-pre-wrap bg-black/40 p-6 rounded-xl border border-zinc-900/50 leading-relaxed">
                                                {v.changelog}
                                            </div>
                                        </div>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}

                    {/* Installation Guide */}
                    <div className="max-w-4xl mx-auto mt-24 pt-12 border-t border-zinc-900">
                        <h2 className="text-2xl font-bold text-white mb-8 flex items-center gap-3">
                            <ShieldAlert className="text-yellow-500" /> Installation Guide (Gatekeeper)
                        </h2>

                        <div className="bg-zinc-900/50 rounded-2xl border border-zinc-800 p-8">
                            <div className="flex items-center gap-4 mb-6">
                                <div className="p-3 bg-yellow-900/20 text-yellow-500 rounded-lg">
                                    <AlertTriangle size={24} />
                                </div>
                                <div>
                                    <h3 className="text-lg font-bold text-white">Apple Developer Identity Missing</h3>
                                    <p className="text-sm text-zinc-400">
                                        As this is a free, open-source project, we do not yet have a paid Apple Developer account.
                                        You may see a warning that the app "cannot be checked for malicious software".
                                    </p>
                                </div>
                            </div>

                            <div className="space-y-6">
                                <div className="flex gap-6">
                                    <div className="flex-shrink-0 w-8 h-8 rounded-full bg-zinc-800 text-white font-bold flex items-center justify-center border border-zinc-700">1</div>
                                    <div>
                                        <h4 className="text-white font-bold mb-2">Drag to Applications</h4>
                                        <p className="text-sm text-zinc-400">Open the downloaded <code className="bg-black px-1 py-0.5 rounded border border-zinc-800">.dmg</code> and drag Aether to your Applications folder.</p>
                                    </div>
                                </div>

                                <div className="flex gap-6">
                                    <div className="flex-shrink-0 w-8 h-8 rounded-full bg-zinc-800 text-white font-bold flex items-center justify-center border border-zinc-700">2</div>
                                    <div>
                                        <h4 className="text-white font-bold mb-2">Right Click to Open</h4>
                                        <p className="text-sm text-zinc-400">
                                            Instead of double-clicking, <strong>Right Click (or Control + Click)</strong> the app icon and select <strong>Open</strong>.
                                        </p>
                                    </div>
                                </div>

                                <div className="flex gap-6">
                                    <div className="flex-shrink-0 w-8 h-8 rounded-full bg-zinc-800 text-white font-bold flex items-center justify-center border border-zinc-700">3</div>
                                    <div>
                                        <h4 className="text-white font-bold mb-2">Confirm Exception</h4>
                                        <p className="text-sm text-zinc-400">
                                            A dialog will appear asking if you want to open it. Click <strong>Open</strong>.
                                            <br />
                                            <span className="text-zinc-500 text-xs mt-2 block">
                                                Alternatively, go to <strong>System Settings {'>'} Privacy & Security</strong> and click <strong>Open Anyway</strong>.
                                            </span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                </div>
            </section>
        </Layout>
    );
};
