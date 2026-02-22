
import React, { useState } from 'react';
import { useScheduler } from '../../hooks/useScheduler';
import { Cpu } from './components/Cpu';
import { ReadyQueue } from './components/ReadyQueue';
import { ProcessList } from './components/ProcessList';
import { Controls } from './components/Controls';
import { Layout } from '../../components/layout/Layout';
import { Loader } from '../../components/ui/Loader';

import { LayoutGroup } from 'framer-motion';

const BOOT_LOGS = [
    "> INITIALIZING_SCHEDULER_ENGINE...",
    "> LOADING_ALGORITHMS [FCFS, SJF, RR]...",
    "> CALIBRATING_QUANTUM_TICKS...",
    "> STARTING_VISUALIZER... OK"
];

export const CPUSchedulerPage = () => {
    const [booting, setBooting] = useState(true);

    const handleBootComplete = React.useCallback(() => {
        setBooting(false);
    }, []);

    const { state, setState, addProcess, reset, clear } = useScheduler();

    const runningProcess = state.runningProcessId
        ? state.processes.find(p => p.id === state.runningProcessId)
        : undefined;

    const completed = state.processes.filter(p => p.state === 'COMPLETED');
    const avgTat = completed.length > 0
        ? (completed.reduce((acc, p) => acc + (p.turnaroundTime || 0), 0) / completed.length).toFixed(2)
        : 0;
    const avgWt = completed.length > 0
        ? (completed.reduce((acc, p) => acc + (p.waitingTime || 0), 0) / completed.length).toFixed(2)
        : 0;


    if (booting) {
        return <Loader logs={BOOT_LOGS} onComplete={handleBootComplete} />;
    }

    return (
        <Layout showFooter={false}>
            <LayoutGroup>
                {/* Main Cockpit Container - Fixed Grid Layout to prevent Layout Shifts */}
                <div
                    className="h-auto lg:h-[calc(100vh-64px)] p-2 bg-background font-mono text-sm flex flex-col gap-2 lg:grid lg:grid-cols-12 lg:grid-rows-[60px_minmax(0,1fr)_200px] overflow-y-auto lg:overflow-hidden"
                >

                    {/* Top Bar: Controls & Stats (Row 1) */}
                    <div className="lg:col-span-12 h-[60px] bg-card border border-border rounded-lg flex items-center px-4 justify-between gap-4 overflow-hidden shrink-0">
                        <div className="flex-1">
                            <Controls state={state} setState={setState} onReset={reset} />
                        </div>

                        {/* Retro Stat Displays */}
                        <div className="flex gap-2">
                            <div className="bg-black border border-zinc-800 px-3 py-1 min-w-[100px] flex flex-col justify-center shadow-inner">
                                <span className="text-[9px] text-zinc-600 uppercase font-bold tracking-widest">AVG TAT</span>
                                <span className="text-lg font-mono text-primary leading-none tracking-widest">{avgTat}</span>
                            </div>
                            <div className="bg-black border border-zinc-800 px-3 py-1 min-w-[100px] flex flex-col justify-center shadow-inner">
                                <span className="text-[9px] text-zinc-600 uppercase font-bold tracking-widest">AVG WAIT</span>
                                <span className="text-lg font-mono text-blue-500 leading-none tracking-widest">{avgWt}</span>
                            </div>
                        </div>
                    </div>

                    {/* Middle Section: Process List | CPU | Ready Queue */}
                    <div className="lg:col-span-12 grid grid-cols-12 gap-2 min-h-0 lg:h-full h-[800px] shrink-0">

                        {/* Left Sidebar: Process List (Cols 1-3) */}
                        <div className="col-span-12 lg:col-span-3 bg-card border border-border rounded-lg overflow-hidden flex flex-col h-[300px] lg:h-full">
                            <ProcessList
                                processes={state.processes}
                                addProcess={addProcess}
                                onClear={clear}
                                currentTime={state.currentTime}
                            />
                        </div>

                        {/* Main Visualizer Area (Cols 4-12) */}
                        <div className="col-span-12 lg:col-span-9 grid grid-cols-1 grid-rows-2 gap-2 h-full min-h-0">
                            {/* CPU Panel (Top Half) */}
                            <div className="bg-card border border-border rounded-lg p-1 relative overflow-hidden flex flex-col shadow-sm h-full">
                                <div className="absolute top-2 left-3 text-xs font-bold text-muted-foreground uppercase tracking-wider z-20">System Core</div>
                                <div className="h-full w-full">
                                    <Cpu runningProcess={runningProcess} />
                                </div>
                            </div>
                            {/* Ready Queue Panel (Bottom Half) */}
                            <div className="bg-card border border-border rounded-lg p-1 relative overflow-hidden flex flex-col shadow-sm h-full">
                                <div className="absolute top-2 left-3 text-xs font-bold text-muted-foreground uppercase tracking-wider z-20">Memory Buffer</div>
                                <div className="h-full w-full pt-6">
                                    <ReadyQueue queue={state.readyQueue} processes={state.processes} algorithm={state.algorithm} />
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Bottom Panel: Execution Log (Row 3, fixed 200px) */}
                    <div className="lg:col-span-12 bg-card border border-border rounded-lg overflow-hidden flex flex-col shadow-sm lg:h-[200px] h-[300px] shrink-0">
                        <div className="p-2 border-b border-border bg-muted/20 flex justify-between items-center">
                            <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Kernel Log</span>
                            <span className="text-[10px] text-zinc-600 font-mono">/var/log/scheduler.log</span>
                        </div>
                        <div className="flex-1 overflow-auto custom-scrollbar p-0 bg-black/20">
                            <table className="w-full text-xs text-left border-collapse">
                                <thead className="bg-muted/30 sticky top-0 text-muted-foreground text-[10px] uppercase font-bold tracking-wider">
                                    <tr>
                                        <th className="px-4 py-2 border-b border-white/5">Process</th>
                                        <th className="px-4 py-2 border-b border-white/5">Arrival</th>
                                        <th className="px-4 py-2 border-b border-white/5">Burst</th>
                                        <th className="px-4 py-2 border-b border-white/5">Finish</th>
                                        <th className="px-4 py-2 text-blue-400 border-b border-white/5">TAT</th>
                                        <th className="px-4 py-2 text-purple-400 border-b border-white/5">WT</th>
                                        <th className="px-4 py-2 text-center border-b border-white/5">Status</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-white/5">
                                    {state.processes.map(p => (
                                        <tr key={p.id} className="hover:bg-white/5 transition-colors group">
                                            <td className="px-4 py-1.5 font-bold flex items-center gap-2">
                                                <div className="w-1.5 h-1.5 rounded-sm" style={{ backgroundColor: p.color }}></div>
                                                <span className="group-hover:text-primary transition-colors">{p.name}</span>
                                            </td>
                                            <td className="px-4 py-1.5 text-muted-foreground font-mono">{p.arrivalTime}</td>
                                            <td className="px-4 py-1.5 text-muted-foreground font-mono">{p.burstTime}</td>
                                            <td className="px-4 py-1.5 text-muted-foreground font-mono">{p.completionTime ?? '-'}</td>
                                            <td className="px-4 py-1.5 text-blue-500 font-mono font-bold">{p.turnaroundTime ?? '-'}</td>
                                            <td className="px-4 py-1.5 text-purple-500 font-mono font-bold">{p.waitingTime ?? '-'}</td>
                                            <td className="px-4 py-1.5 text-center">
                                                <span className={`text-[9px] px-1.5 py-px rounded border ${p.state === 'COMPLETED' ? 'bg-green-500/10 text-green-500 border-green-500/20' :
                                                    p.state === 'RUNNING' ? 'bg-blue-500/10 text-blue-500 border-blue-500/20' :
                                                        'text-zinc-500 border-white/5'
                                                    }`}>{p.state}</span>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </LayoutGroup>
        </Layout >
    );
};
