import React, { useState, useEffect } from 'react';
import { Layout } from '../components/layout/Layout';
import { Button } from '../components/ui/Button';
import { supabase } from '../lib/supabase';
import { Package, Terminal, ExternalLink, Check, BarChart3 } from 'lucide-react';
import { Link } from 'react-router-dom';

interface PollVotes {
    javascript: number;
    rust: number;
    go: number;
    java: number;
    cpp: number;
}

export const Packages = () => {
    const [votes, setVotes] = useState<PollVotes>({ javascript: 0, rust: 0, go: 0, java: 0, cpp: 0 });
    const [userVote, setUserVote] = useState<string | null>(null);
    const [voteStatus, setVoteStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
    const [copied, setCopied] = useState<string | null>(null);

    const fetchVotes = async () => {
        const { data, error } = await supabase
            .from('language_poll')
            .select('language, votes')
            .order('language');

        if (data && !error) {
            const voteMap: PollVotes = { javascript: 0, rust: 0, go: 0, java: 0, cpp: 0 };
            data.forEach((row: { language: string; votes: number }) => {
                if (row.language in voteMap) {
                    voteMap[row.language as keyof PollVotes] = row.votes;
                }
            });
            setVotes(voteMap);
        }
    };

    useEffect(() => {
        // Check if user already voted (localStorage)
        const existingVote = localStorage.getItem('okernel_language_vote');
        if (existingVote) {
            // We can safely ignore this lint because we are initializing state from localStorage
            // once on mount. The alternative is lazy initialization in useState, but this is fine.
            // eslint-disable-next-line react-hooks/set-state-in-effect
            setUserVote(existingVote);
        }

        // Fetch current votes
        fetchVotes();
    }, []);

    const handleVote = async (language: string) => {
        if (userVote) return; // Already voted
        
        setVoteStatus('loading');
        
        const { error } = await supabase.rpc('increment_language_vote', { lang: language });

        if (error) {
            console.error('Vote error:', error);
            setVoteStatus('error');
            setTimeout(() => setVoteStatus('idle'), 2000);
            return;
        }

        localStorage.setItem('okernel_language_vote', language);
        setUserVote(language);
        setVoteStatus('success');
        fetchVotes();
        setTimeout(() => setVoteStatus('idle'), 2000);
    };

    const copyToClipboard = (text: string, id: string) => {
        navigator.clipboard.writeText(text);
        setCopied(id);
        setTimeout(() => setCopied(null), 2000);
    };

    const totalVotes = Object.values(votes).reduce((a, b) => a + b, 0);

    const languages = [
        { key: 'javascript', name: 'JavaScript/TypeScript', color: 'yellow' },
        { key: 'rust', name: 'Rust', color: 'orange' },
        { key: 'go', name: 'Go', color: 'cyan' },
        { key: 'java', name: 'Java', color: 'red' },
        { key: 'cpp', name: 'C++', color: 'blue' },
    ];

    const codeExamples = [
        {
            id: 'basic',
            title: 'Basic Tracing',
            description: 'Trace any Python code and generate an HTML report',
            code: `import okernel

code = """
x = 10
y = 20
result = x + y
print(f"Sum: {result}")
"""

trace = okernel.trace(code)
trace.to_html("basic_trace.html")
print(trace.summary())`,
        },
        {
            id: 'recursive',
            title: 'Recursive Functions',
            description: 'Visualize call stacks and recursion depth',
            code: `import okernel

code = """
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

result = factorial(5)
print(f"5! = {result}")
"""

trace = okernel.trace(code)
trace.to_html("factorial_trace.html")
# Generates visualization showing 5 recursive calls`,
        },
        {
            id: 'memory',
            title: 'Memory Tracking',
            description: 'Track object allocation and memory usage',
            code: `import okernel

code = """
# Track memory allocation patterns
data = []
for i in range(10):
    data.append([0] * 100)

# Objects are tracked with address and size
matrix = [[i * j for j in range(5)] for i in range(5)]
print(f"Matrix size: {len(matrix)}x{len(matrix[0])}")
"""

trace = okernel.trace(code)
print(f"Peak memory: {trace.peak_memory} bytes")
trace.to_html("memory_trace.html")`,
        },
        {
            id: 'sorting',
            title: 'Algorithm Visualization',
            description: 'Step through sorting algorithms instruction by instruction',
            code: `import okernel

code = """
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr

data = [64, 34, 25, 12, 22, 11, 90]
sorted_data = bubble_sort(data.copy())
print(f"Sorted: {sorted_data}")
"""

trace = okernel.trace(code)
trace.to_html("sorting_trace.html")
# See each comparison and swap in the timeline`,
        },
        {
            id: 'classes',
            title: 'Object-Oriented Code',
            description: 'Trace class instantiation and method calls',
            code: `import okernel

code = """
class Stack:
    def __init__(self):
        self.items = []
    
    def push(self, item):
        self.items.append(item)
    
    def pop(self):
        if self.items:
            return self.items.pop()
        return None
    
    def peek(self):
        return self.items[-1] if self.items else None

stack = Stack()
stack.push(10)
stack.push(20)
stack.push(30)
print(f"Top: {stack.peek()}")
print(f"Popped: {stack.pop()}")
"""

trace = okernel.trace(code)
trace.to_html("oop_trace.html")`,
        },
        {
            id: 'exception',
            title: 'Exception Handling',
            description: 'Track exception flow and error handling',
            code: `import okernel

code = """
def divide(a, b):
    try:
        result = a / b
        return result
    except ZeroDivisionError as e:
        print(f"Error: {e}")
        return None

print(divide(10, 2))
print(divide(10, 0))
print(divide(15, 3))
"""

trace = okernel.trace(code)
trace.to_html("exception_trace.html")
# Exception events are captured in the trace`,
        },
    ];

    return (
        <Layout>
            {/* Hero Section */}
            <section className="pt-20 pb-16 relative border-b border-zinc-800 bg-zinc-950 overflow-hidden">
                <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(34,197,94,0.1),transparent_70%)] pointer-events-none"></div>
                
                <div className="container mx-auto px-4 relative z-10">
                    <div className="max-w-4xl mx-auto text-center">
                        <div className="inline-flex items-center gap-2 px-3 py-1 bg-green-900/20 border border-green-500/30 text-green-400 text-xs font-mono rounded-full mb-6">
                            <Package size={12} />
                            OFFICIAL PACKAGES
                        </div>
                        
                        <h1 className="text-4xl md:text-6xl font-bold tracking-tight text-white mb-6">
                            OKernel <span className="text-green-500">Packages</span>
                        </h1>
                        
                        <p className="text-lg text-zinc-400 max-w-2xl mx-auto mb-8">
                            Install OKernel tools locally. Trace code execution, visualize memory, and debug algorithms without leaving your terminal.
                        </p>
                    </div>
                </div>
            </section>

            {/* Python Package Section */}
            <section className="py-16 border-b border-zinc-800">
                <div className="container mx-auto px-4">
                    <div className="flex flex-col lg:flex-row gap-12 items-start">
                        {/* Left: Package Info */}
                        <div className="lg:w-1/3 space-y-6">
                            <div className="flex items-center gap-3">
                                <div className="w-12 h-12 bg-green-500/10 border border-green-500/30 rounded-lg flex items-center justify-center">
                                    <Terminal className="text-green-500" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-2xl font-bold text-white">okernel</h2>
                                    <p className="text-sm text-zinc-500 font-mono">Python Package</p>
                                </div>
                            </div>
                            
                            <div className="space-y-4">
                                <div className="p-4 bg-zinc-900 border border-zinc-800 rounded-lg">
                                    <div className="text-xs text-zinc-500 mb-2 font-mono">Installation</div>
                                    <div className="flex items-center justify-between">
                                        <code className="text-green-400 font-mono">pip install okernel</code>
                                        <button
                                            onClick={() => copyToClipboard('pip install okernel', 'install')}
                                            className="text-zinc-500 hover:text-white transition-colors"
                                        >
                                            {copied === 'install' ? <Check size={16} className="text-green-500" /> : 'Copy'}
                                        </button>
                                    </div>
                                </div>
                                
                                <div className="grid grid-cols-2 gap-3 text-sm">
                                    <div className="p-3 bg-zinc-900/50 border border-zinc-800 rounded">
                                        <div className="text-zinc-500 text-xs">Version</div>
                                        <div className="text-white font-mono">0.2.0</div>
                                    </div>
                                    <div className="p-3 bg-zinc-900/50 border border-zinc-800 rounded">
                                        <div className="text-zinc-500 text-xs">Dependencies</div>
                                        <div className="text-green-400 font-mono">Zero</div>
                                    </div>
                                    <div className="p-3 bg-zinc-900/50 border border-zinc-800 rounded">
                                        <div className="text-zinc-500 text-xs">Python</div>
                                        <div className="text-white font-mono">3.8+</div>
                                    </div>
                                    <div className="p-3 bg-zinc-900/50 border border-zinc-800 rounded">
                                        <div className="text-zinc-500 text-xs">License</div>
                                        <div className="text-white font-mono">MIT</div>
                                    </div>
                                </div>

                                <a
                                    href="https://pypi.org/project/okernel/"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="flex items-center justify-center gap-2 w-full p-3 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded-lg text-white font-mono text-sm transition-colors"
                                >
                                    <ExternalLink size={14} />
                                    View on PyPI
                                </a>
                            </div>

                            <div className="p-4 bg-zinc-900/50 border border-zinc-800 rounded-lg">
                                <h3 className="text-white font-bold mb-3">Features</h3>
                                <ul className="space-y-2 text-sm text-zinc-400">
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        Zero external dependencies (stdlib only)
                                    </li>
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        3-panel HTML visualizer (Code/Stack/Timeline)
                                    </li>
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        Memory tracking with peak usage stats
                                    </li>
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        GC callback tracking
                                    </li>
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        Hardware cost estimation per opcode
                                    </li>
                                    <li className="flex items-start gap-2">
                                        <span className="text-green-500 mt-1">-</span>
                                        Self-contained offline HTML output
                                    </li>
                                </ul>
                            </div>
                        </div>

                        {/* Right: Code Examples */}
                        <div className="lg:w-2/3 space-y-6">
                            <h3 className="text-xl font-bold text-white mb-4">Code Examples</h3>
                            
                            <div className="grid gap-6">
                                {codeExamples.map((example) => (
                                    <div key={example.id} className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                                        <div className="p-4 border-b border-zinc-800 flex items-center justify-between">
                                            <div>
                                                <h4 className="text-white font-bold">{example.title}</h4>
                                                <p className="text-sm text-zinc-500">{example.description}</p>
                                            </div>
                                            <button
                                                onClick={() => copyToClipboard(example.code, example.id)}
                                                className="px-3 py-1 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded text-xs text-zinc-300 transition-colors"
                                            >
                                                {copied === example.id ? 'Copied!' : 'Copy'}
                                            </button>
                                        </div>
                                        <pre className="p-4 overflow-x-auto text-sm">
                                            <code className="text-zinc-300 font-mono whitespace-pre">{example.code}</code>
                                        </pre>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* Language Poll Section */}
            <section className="py-16 bg-zinc-950 border-b border-zinc-800">
                <div className="container mx-auto px-4">
                    <div className="max-w-3xl mx-auto">
                        <div className="text-center mb-12">
                            <div className="inline-flex items-center gap-2 px-3 py-1 bg-blue-900/20 border border-blue-500/30 text-blue-400 text-xs font-mono rounded-full mb-4">
                                <BarChart3 size={12} />
                                COMMUNITY POLL
                            </div>
                            <h2 className="text-3xl font-bold text-white mb-4">
                                What language should OKernel support next?
                            </h2>
                            <p className="text-zinc-400">
                                Help us prioritize development. Vote for the language you want to trace next.
                            </p>
                        </div>

                        <div className="space-y-4">
                            {languages.map((lang) => {
                                const voteCount = votes[lang.key as keyof PollVotes];
                                const percentage = totalVotes > 0 ? (voteCount / totalVotes) * 100 : 0;
                                const isSelected = userVote === lang.key;
                                
                                return (
                                    <div
                                        key={lang.key}
                                        className={`relative p-4 bg-zinc-900 border rounded-lg transition-all ${
                                            isSelected 
                                                ? 'border-green-500/50 bg-green-500/5' 
                                                : 'border-zinc-800 hover:border-zinc-700'
                                        }`}
                                    >
                                        {/* Progress bar background */}
                                        <div
                                            className={`absolute inset-0 rounded-lg transition-all ${
                                                isSelected ? 'bg-green-500/10' : 'bg-zinc-800/50'
                                            }`}
                                            style={{ width: `${percentage}%` }}
                                        />
                                        
                                        <div className="relative flex items-center justify-between">
                                            <div className="flex items-center gap-3">
                                                <span className="text-white font-medium">{lang.name}</span>
                                                {isSelected && (
                                                    <span className="px-2 py-0.5 bg-green-500/20 text-green-400 text-xs rounded">
                                                        Your vote
                                                    </span>
                                                )}
                                            </div>
                                            
                                            <div className="flex items-center gap-4">
                                                <span className="text-zinc-400 font-mono text-sm">
                                                    {voteCount} votes ({percentage.toFixed(1)}%)
                                                </span>
                                                
                                                {!userVote && (
                                                    <Button
                                                        size="sm"
                                                        variant="outline"
                                                        onClick={() => handleVote(lang.key)}
                                                        disabled={voteStatus === 'loading'}
                                                        className="text-xs"
                                                    >
                                                        Vote
                                                    </Button>
                                                )}
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {userVote && (
                            <div className="mt-6 p-4 bg-green-500/10 border border-green-500/30 rounded-lg text-center">
                                <p className="text-green-400 text-sm">
                                    Thanks for voting! Your voice helps shape OKernel's roadmap.
                                </p>
                            </div>
                        )}

                        {!userVote && (
                            <p className="mt-6 text-center text-zinc-500 text-sm">
                                Vote once per browser. Results update in real-time.
                            </p>
                        )}
                    </div>
                </div>
            </section>

            {/* Coming Soon Section */}
            <section className="py-16">
                <div className="container mx-auto px-4">
                    <div className="text-center mb-12">
                        <h2 className="text-2xl font-bold text-white mb-4">More Packages Coming Soon</h2>
                        <p className="text-zinc-400">Based on community feedback, we're expanding to more languages.</p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
                        <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl opacity-60">
                            <div className="text-yellow-500 font-mono text-sm mb-2">npm</div>
                            <h3 className="text-white font-bold mb-2">@okernel/trace</h3>
                            <p className="text-zinc-500 text-sm">JavaScript/TypeScript tracing for Node.js and browser environments.</p>
                            <div className="mt-4 text-xs text-zinc-600 font-mono">Coming soon</div>
                        </div>

                        <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl opacity-60">
                            <div className="text-orange-500 font-mono text-sm mb-2">cargo</div>
                            <h3 className="text-white font-bold mb-2">okernel-rs</h3>
                            <p className="text-zinc-500 text-sm">Rust crate for compile-time and runtime tracing.</p>
                            <div className="mt-4 text-xs text-zinc-600 font-mono">Coming soon</div>
                        </div>

                        <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl opacity-60">
                            <div className="text-cyan-500 font-mono text-sm mb-2">go get</div>
                            <h3 className="text-white font-bold mb-2">okernel-go</h3>
                            <p className="text-zinc-500 text-sm">Go module for goroutine and memory tracing.</p>
                            <div className="mt-4 text-xs text-zinc-600 font-mono">Coming soon</div>
                        </div>
                    </div>
                </div>
            </section>

            {/* CTA Section */}
            <section className="py-16 border-t border-zinc-800">
                <div className="container mx-auto px-4 text-center">
                    <h2 className="text-2xl font-bold text-white mb-4">Ready to trace your code?</h2>
                    <p className="text-zinc-400 mb-8">Install okernel and start visualizing execution in seconds.</p>
                    <div className="flex justify-center gap-4">
                        <Link to="/docs">
                            <Button variant="outline" className="font-mono">
                                Read the Docs
                            </Button>
                        </Link>
                        <a href="https://pypi.org/project/okernel/" target="_blank" rel="noopener noreferrer">
                            <Button className="bg-green-500 hover:bg-green-400 text-black font-mono">
                                pip install okernel
                            </Button>
                        </a>
                    </div>
                </div>
            </section>
        </Layout>
    );
};
