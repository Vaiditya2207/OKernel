import React from 'react';
import { RotateCcw, ChevronDown } from 'lucide-react';
import { AlgorithmType, SimulationState } from '../../../core/types';

interface Props {
    state: SimulationState;
    setState: React.Dispatch<React.SetStateAction<SimulationState>>;
    onReset: () => void;
}

export const Controls: React.FC<Props> = ({ state, setState, onReset }) => {
    return (
        <div className="flex flex-wrap items-center gap-4 w-full font-mono text-xs">

            {/* Playback Controls */}
            <div className="flex items-center -space-x-px">
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

            <div className="w-px h-6 bg-zinc-800 mx-2 hidden sm:block"></div>

            {/* Algorithm Selector */}
            <div className="flex items-center gap-2">
                <span className="text-zinc-500 select-none">ALGO:</span>
                <div className="relative group">
                    <select
                        value={state.algorithm}
                        onChange={e => setState(s => ({ ...s, algorithm: e.target.value as AlgorithmType }))}
                        className="appearance-none bg-black border border-zinc-700 text-white h-8 pl-3 pr-8 focus:outline-none focus:border-primary cursor-pointer hover:border-zinc-500 transition-colors uppercase"
                        disabled={state.isPlaying}
                    >
                        <option value="FCFS">First Come First Serve</option>
                        <option value="SJF">Shortest Job First</option>
                        <option value="SRTF">Shortest Remaining Time</option>
                        <option value="RR">Round Robin</option>
                        <option value="PRIORITY">Priority</option>
                        <option value="MLFQ">Multi-Level Feedback Queue (MLFQ)</option>
                    </select>
                    <ChevronDown size={12} className="absolute right-2 top-1/2 -translate-y-1/2 text-zinc-500 pointer-events-none group-hover:text-white transition-colors" />
                </div>
            </div>

            {/* Time Quantum (Conditional) */}
            {state.algorithm === 'RR' && (
                <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200">
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

            {/* MLFQ Boost Time (Conditional) */}
            {state.algorithm === 'MLFQ' && (
                <div className="flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-200">
                    <span className="text-zinc-500 select-none">BOOST_TICKS:</span>
                    <input
                        type="number"
                        value={state.mlfqBoostTime}
                        onChange={e => setState(s => ({ ...s, mlfqBoostTime: Number(e.target.value) }))}
                        className="bg-black border border-zinc-700 text-white h-8 w-16 px-2 focus:outline-none focus:border-primary text-center"
                        min={1}
                        disabled={state.isPlaying}
                    />
                </div>
            )}

            <div className="flex-1"></div>

            {/* Speed Control */}
            <div className="flex items-center gap-4">
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
            <div className="flex items-center gap-2 border border-zinc-800 bg-black h-8 px-3 min-w-[100px] justify-between">
                <span className="text-zinc-600">T=</span>
                <span className="text-primary font-bold">{state.currentTime}ms</span>
            </div>

        </div>
    );
};
