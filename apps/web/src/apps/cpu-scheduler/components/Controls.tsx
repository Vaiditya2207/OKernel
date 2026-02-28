import React from 'react';
import { RotateCcw, ChevronDown } from 'lucide-react';
import { AlgorithmType, SimulationState } from '../../../core/types';

interface Props {
    state: SimulationState;
    setState: React.Dispatch<React.SetStateAction<SimulationState>>;
    onReset: () => void;
}

export const Controls: React.FC<Props> = ({ state, setState, onReset }) => {

    const handleNumQueuesChange = (value: number) => {
        const numQueues = Math.max(2, Math.min(3, value));
        setState(s => {
            const newQuantums = Array.from({ length: numQueues }, (_, i) =>
                s.mlfqQuantums[i] ?? Math.pow(2, i + 1)
            );
            return {
                ...s,
                mlfqNumQueues: numQueues,
                mlfqQuantums: newQuantums,
                mlfqQueues: Array.from({ length: numQueues }, (_, i) => s.mlfqQueues[i] ?? []),
            };
        });
    };

    const handleQuantumChange = (level: number, value: number) => {
        setState(s => {
            const newQuantums = [...s.mlfqQuantums];
            newQuantums[level] = Math.max(1, value);
            return { ...s, mlfqQuantums: newQuantums };
        });
    };

    const handleCoresChange = (value: number) => {
        const numCores = Math.max(1, Math.min(8, value));
        setState(s => ({
            ...s,
            numCores,
            runningProcessIds: Array(numCores).fill(null),
            quantumRemaining: Array(numCores).fill(0),
            contextSwitchCooldown: Array(numCores).fill(0),
            mlfqCurrentLevel: Array(numCores).fill(0),
        }));
    };

    return (
        <div className="flex overflow-x-auto whitespace-nowrap items-center gap-4 w-full font-mono text-xs pb-2 custom-scrollbar">

            {/* Playback Controls */}
            <div className="flex items-center -space-x-px shrink-0">
                <button
                    onClick={() => setState(s => ({ ...s, isPlaying: !s.isPlaying }))}
                    className={`h-8 px-4 flex items-center justify-center border transition-colors ${state.isPlaying
                        ? 'bg-zinc-900 border-yellow-700 text-yellow-500 hover:bg-yellow-900/20'
                        : 'bg-zinc-900 border-green-800 text-green-500 hover:bg-green-900/20'
                        }`}
                >
                    {state.isPlaying ? (
                        <span className="flex items-center gap-2">[ PAUSE ]</span>
                    ) : (
                        <span className="flex items-center gap-2">[ EXEC ]</span>
                    )}
                </button>
                <button
                    onClick={onReset}
                    className="h-8 px-3 flex items-center justify-center border border-zinc-700 bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-white transition-colors"
                    title="Reset Simulation"
                >
                    <RotateCcw size={14} />
                </button>
            </div>

            <div className="w-px h-6 bg-zinc-800 mx-2 hidden sm:block shrink-0"></div>

            {/* Algorithm Selector — custom dropdown */}
            <AlgorithmDropdown
                value={state.algorithm}
                onChange={algo => setState(s => ({ ...s, algorithm: algo }))}
                disabled={state.isPlaying}
            />

            {/* Cores Input */}
            <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200 shrink-0">
                <span className="text-zinc-500 select-none">CORES:</span>
                <input
                    type="number"
                    value={state.numCores}
                    onChange={e => handleCoresChange(Number(e.target.value))}
                    className="bg-black border border-zinc-700 text-white h-8 w-14 px-2 focus:outline-none focus:border-primary text-center"
                    min={1}
                    max={8}
                    disabled={state.isPlaying}
                />
            </div>

            {/* Time Quantum (RR only) */}
            {state.algorithm === 'RR' && (
                <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200 shrink-0">
                    <span className="text-zinc-500 select-none">Q_TIME:</span>
                    <input
                        type="number"
                        value={state.timeQuantum}
                        onChange={e => setState(s => ({ ...s, timeQuantum: Number(e.target.value) }))}
                        className="bg-black border border-zinc-700 text-white h-8 w-16 px-2 focus:outline-none focus:border-primary text-center"
                        min={1}
                        disabled={state.isPlaying}
                    />
                </div>
            )}

            {/* MLFQ Configuration */}
            {state.algorithm === 'MLFQ' && (
                <div className="flex items-center gap-3 animate-in fade-in slide-in-from-left-2 duration-200 shrink-0">
                    <div className="flex items-center gap-2">
                        <span className="text-zinc-500 select-none">LEVELS:</span>
                        <input
                            type="number"
                            value={state.mlfqNumQueues}
                            onChange={e => handleNumQueuesChange(Number(e.target.value))}
                            className="bg-black border border-zinc-700 text-white h-8 w-14 px-2 focus:outline-none focus:border-primary text-center"
                            min={2}
                            max={3}
                            disabled={state.isPlaying}
                        />
                    </div>
                    <div className="w-px h-5 bg-zinc-800"></div>
                    <div className="flex items-center gap-1">
                        <span className="text-zinc-500 select-none">Q:</span>
                        {state.mlfqQuantums.map((q, i) => (
                            <div key={i} className="flex items-center gap-0.5">
                                <span className="text-zinc-600 text-[9px]">L{i}</span>
                                <input
                                    type="number"
                                    value={q}
                                    onChange={e => handleQuantumChange(i, Number(e.target.value))}
                                    className="bg-black border border-zinc-700 text-white h-7 w-10 px-1 focus:outline-none focus:border-primary text-center text-[10px]"
                                    min={1}
                                    disabled={state.isPlaying}
                                />
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Priority Aging (PRIORITY / PRIORITY_P only) */}
            {(state.algorithm === 'PRIORITY' || state.algorithm === 'PRIORITY_P') && (
                <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200 shrink-0">
                    <label className="flex items-center gap-2 cursor-pointer select-none">
                        <span className="text-zinc-500">AGING:</span>
                        <div
                            onClick={() => setState(s => ({ ...s, priorityAgingEnabled: !s.priorityAgingEnabled }))}
                            className={`w-8 h-4 rounded-full relative transition-colors cursor-pointer ${state.priorityAgingEnabled ? 'bg-primary' : 'bg-zinc-700'
                                }`}
                        >
                            <div className={`absolute top-0.5 w-3 h-3 rounded-full bg-white transition-transform ${state.priorityAgingEnabled ? 'translate-x-4' : 'translate-x-0.5'
                                }`} />
                        </div>
                    </label>
                    {state.priorityAgingEnabled && (
                        <div className="flex items-center gap-1 animate-in fade-in duration-150">
                            <span className="text-zinc-600 text-[9px]">INT</span>
                            <input
                                type="number"
                                value={state.priorityAgingInterval}
                                onChange={e => setState(s => ({ ...s, priorityAgingInterval: Math.max(1, Number(e.target.value)) }))}
                                className="bg-black border border-zinc-700 text-white h-7 w-10 px-1 focus:outline-none focus:border-primary text-center text-[10px]"
                                min={1}
                                disabled={state.isPlaying}
                            />
                        </div>
                    )}
                </div>
            )}

            {/* Context Switch Cost (all algorithms) */}
            <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200 shrink-0">
                <span className="text-zinc-500 select-none">CS_COST:</span>
                <input
                    type="number"
                    value={state.contextSwitchCost}
                    onChange={e => setState(s => ({ ...s, contextSwitchCost: Math.max(0, Number(e.target.value)) }))}
                    className="bg-black border border-zinc-700 text-white h-8 w-14 px-2 focus:outline-none focus:border-primary text-center"
                    min={0}
                    disabled={state.isPlaying}
                />
            </div>

            <div className="flex-1"></div>

            {/* Speed Control */}
            <div className="flex items-center gap-4 shrink-0">
                <span className="text-zinc-500 select-none hidden sm:inline">CLOCK_RATE:</span>
                <div className="flex items-center gap-2">
                    <span className="text-zinc-600">SLOW</span>
                    <input
                        type="range"
                        min="100"
                        max="2000"
                        step="100"
                        value={2100 - state.speed}
                        onChange={e => setState(s => ({ ...s, speed: 2100 - Number(e.target.value) }))}
                        className="w-24 h-1 bg-zinc-800 rounded-none appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-2 [&::-webkit-slider-thumb]:h-3 [&::-webkit-slider-thumb]:bg-primary"
                    />
                    <span className="text-zinc-600">FAST</span>
                </div>
            </div>

            {/* Time Display */}
            <div className="flex items-center gap-2 border border-zinc-800 bg-black h-8 px-3 min-w-[100px] justify-between shrink-0">
                <span className="text-zinc-600">T=</span>
                <span className="text-primary font-bold">{state.currentTime}ms</span>
            </div>

        </div>
    );
};

// ─── Algorithm Dropdown ────────────────────────────────────────────────────────

import { createPortal } from 'react-dom';

interface AlgoOption {
    value: AlgorithmType;
    code: string;
    label: string;
    desc: string;
    tag: string;
    tagColor: string;
}

const ALGO_OPTIONS: AlgoOption[] = [
    {
        value: 'FCFS',
        code: 'FCFS',
        label: 'First Come First Serve',
        desc: 'Processes run in arrival order. Simple but prone to convoy effect.',
        tag: 'Non-preemptive',
        tagColor: 'text-zinc-400 border-zinc-600',
    },
    {
        value: 'SJF',
        code: 'SJF',
        label: 'Shortest Job First',
        desc: 'Picks the process with the smallest burst time. Optimal avg. wait.',
        tag: 'Non-preemptive',
        tagColor: 'text-zinc-400 border-zinc-600',
    },
    {
        value: 'SRTF',
        code: 'SRTF',
        label: 'Shortest Remaining Time',
        desc: 'Preemptive SJF — preempts current job when a shorter one arrives.',
        tag: 'Preemptive',
        tagColor: 'text-amber-400 border-amber-800',
    },
    {
        value: 'RR',
        code: 'RR',
        label: 'Round Robin',
        desc: 'Each process gets a fixed time quantum in cyclic order. Fair & responsive.',
        tag: 'Preemptive',
        tagColor: 'text-amber-400 border-amber-800',
    },
    {
        value: 'PRIORITY',
        code: 'PRI',
        label: 'Priority Scheduling',
        desc: 'Executes the highest-priority process. Low-priority jobs risk starvation.',
        tag: 'Non-preemptive',
        tagColor: 'text-zinc-400 border-zinc-600',
    },
    {
        value: 'PRIORITY_P',
        code: 'PRI-P',
        label: 'Preemptive Priority',
        desc: 'Preempts current job when a higher-priority process arrives.',
        tag: 'Preemptive',
        tagColor: 'text-amber-400 border-amber-800',
    },
    {
        value: 'MLFQ',
        code: 'MLFQ',
        label: 'Multi-Level Feedback Queue',
        desc: 'Multiple queues with decreasing priority. Dynamically adapts to behaviour.',
        tag: 'Adaptive',
        tagColor: 'text-cyan-400 border-cyan-800',
    },
];

interface AlgorithmDropdownProps {
    value: AlgorithmType;
    onChange: (algo: AlgorithmType) => void;
    disabled?: boolean;
}

const AlgorithmDropdown: React.FC<AlgorithmDropdownProps> = ({ value, onChange, disabled }) => {
    const [open, setOpen] = React.useState(false);
    const [rect, setRect] = React.useState<DOMRect | null>(null);
    const triggerRef = React.useRef<HTMLButtonElement>(null);
    const panelRef = React.useRef<HTMLDivElement>(null);

    const selected = ALGO_OPTIONS.find(o => o.value === value) ?? ALGO_OPTIONS[0];

    // Open logic + get rect
    const handleToggle = () => {
        if (disabled) return;
        if (!open) setRect(triggerRef.current?.getBoundingClientRect() || null);
        setOpen(o => !o);
    };

    // Close on outside click
    React.useEffect(() => {
        if (!open) return;
        const handler = (e: MouseEvent) => {
            const isClickInTrigger = triggerRef.current?.contains(e.target as Node);
            const isClickInPanel = panelRef.current?.contains(e.target as Node);
            if (!isClickInTrigger && !isClickInPanel) {
                setOpen(false);
            }
        };
        document.addEventListener('mousedown', handler);
        return () => document.removeEventListener('mousedown', handler);
    }, [open]);

    // Constant position tracking on scroll / resize
    React.useEffect(() => {
        if (!open) return;
        const updateRect = () => setRect(triggerRef.current?.getBoundingClientRect() || null);
        window.addEventListener('resize', updateRect);
        window.addEventListener('scroll', updateRect, true); // true catches internal scrolling
        return () => {
            window.removeEventListener('resize', updateRect);
            window.removeEventListener('scroll', updateRect, true);
        };
    }, [open]);

    // Close on Escape
    React.useEffect(() => {
        if (!open) return;
        const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
        document.addEventListener('keydown', handler);
        return () => document.removeEventListener('keydown', handler);
    }, [open]);

    return (
        <div className="relative shrink-0 flex items-center gap-2">
            <span className="text-zinc-500 select-none">ALGO:</span>

            {/* ── Trigger ── */}
            <button
                ref={triggerRef}
                type="button"
                onClick={handleToggle}
                disabled={disabled}
                className={[
                    'h-8 flex items-center gap-2 pl-3 pr-2 border transition-all duration-150 select-none',
                    disabled
                        ? 'opacity-40 cursor-not-allowed border-zinc-800 bg-transparent text-zinc-600'
                        : open
                            ? 'border-zinc-400 bg-zinc-900 text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.06)]'
                            : 'border-zinc-700 bg-black text-white hover:border-zinc-500 cursor-pointer',
                ].join(' ')}
            >
                {/* short code badge */}
                <span className="text-[9px] font-bold px-1 py-px border border-zinc-600 text-zinc-400 leading-none tracking-wider uppercase">
                    {selected.code}
                </span>
                {/* full name — truncated */}
                <span className="text-[11px] font-semibold tracking-wide max-w-[140px] truncate uppercase">
                    {selected.label}
                </span>
                <ChevronDown
                    size={11}
                    className={`text-zinc-500 transition-transform duration-200 ml-0.5 ${open ? 'rotate-180' : ''}`}
                />
            </button>

            {/* ── Floating panel via Portal ── */}
            {open && rect && createPortal(
                <div
                    ref={panelRef}
                    className="fixed z-[9999] w-[320px] bg-[#0a0a0c] border border-zinc-800 shadow-[0_20px_60px_rgba(0,0,0,0.7)]"
                    style={{
                        top: rect.bottom + 5,
                        left: rect.left,
                        animation: 'algoDropIn 0.14s cubic-bezier(0.16,1,0.3,1) both'
                    }}
                >
                    {/* panel header */}
                    <div className="px-3 py-1.5 border-b border-zinc-800/80 flex items-center justify-between">
                        <span className="text-[9px] text-zinc-600 uppercase tracking-[0.18em] font-bold">
                            Scheduling Algorithm
                        </span>
                        <span className="text-[9px] text-zinc-700 font-mono">{ALGO_OPTIONS.length} modes</span>
                    </div>

                    {/* options list */}
                    <ul className="py-0.5">
                        {ALGO_OPTIONS.map(opt => {
                            const isActive = opt.value === value;
                            return (
                                <li key={opt.value}>
                                    <button
                                        type="button"
                                        onClick={() => { onChange(opt.value); setOpen(false); }}
                                        className={[
                                            'w-full text-left px-3 py-2 flex items-start gap-2.5 transition-colors duration-100 group',
                                            isActive ? 'bg-zinc-800/80' : 'hover:bg-zinc-900',
                                        ].join(' ')}
                                    >
                                        {/* active left bar */}
                                        <div className={[
                                            'mt-[3px] w-0.5 self-stretch rounded-full flex-shrink-0 transition-colors',
                                            isActive ? 'bg-white' : 'bg-transparent group-hover:bg-zinc-700',
                                        ].join(' ')} />

                                        {/* code badge */}
                                        <span className={[
                                            'text-[8px] font-bold px-1 py-0.5 border mt-0.5 leading-none tracking-wider flex-shrink-0 uppercase font-mono',
                                            isActive ? 'border-zinc-400 text-zinc-300' : 'border-zinc-700 text-zinc-600',
                                        ].join(' ')}>
                                            {opt.code}
                                        </span>

                                        {/* text block */}
                                        <div className="flex flex-col gap-0.5 min-w-0 flex-1">
                                            <div className="flex items-center gap-1.5 flex-wrap">
                                                <span className={[
                                                    'text-[11px] font-semibold uppercase tracking-wide leading-none',
                                                    isActive ? 'text-white' : 'text-zinc-300 group-hover:text-white',
                                                ].join(' ')}>
                                                    {opt.label}
                                                </span>
                                                <span className={`text-[8px] px-1 py-px border leading-none ${opt.tagColor}`}>
                                                    {opt.tag}
                                                </span>
                                            </div>
                                            <span className="text-[10px] text-zinc-600 leading-snug group-hover:text-zinc-500 transition-colors whitespace-normal mt-0.5">
                                                {opt.desc}
                                            </span>
                                        </div>

                                        {/* checkmark */}
                                        {isActive && (
                                            <span className="text-white text-[11px] flex-shrink-0 mt-0.5 leading-none">✓</span>
                                        )}
                                    </button>
                                </li>
                            );
                        })}
                    </ul>

                    {/* footer hint */}
                    <div className="px-3 py-1.5 border-t border-zinc-800/60">
                        <span className="text-[8px] text-zinc-700 uppercase tracking-wider">Press Esc to close</span>
                    </div>

                    {/* inline styles to keep animations bundled */}
                    <style>{`
                        @keyframes algoDropIn {
                            from { opacity: 0; transform: translateY(-5px) scaleY(0.96); transform-origin: top; }
                            to   { opacity: 1; transform: translateY(0)  scaleY(1);      transform-origin: top; }
                        }
                    `}</style>
                </div>,
                document.body
            )}
        </div>
    );
};

