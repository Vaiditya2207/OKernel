import React from 'react';
import { Process, AlgorithmType } from '../../../core/types';
import { motion, AnimatePresence } from 'framer-motion';

interface Props {
    queue: number[];
    processes: Process[];
    algorithm?: AlgorithmType;
}

const ProcessSlot = ({ id, index, process }: { id: number, index: number, process: Process }) => {
    const address = `0x${(1024 + (index * 64)).toString(16).toUpperCase().padStart(4, '0')}`;

    return (
        <motion.div
            layoutId={`process-${id}`}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            className="relative bg-zinc-950 border border-zinc-800 hover:border-primary/50 group transition-colors overflow-hidden rounded-sm"
        >
            {/* Header: Address */}
            <div className="bg-zinc-900/80 px-2 py-1 flex justify-between items-center border-b border-zinc-800">
                <span className="text-[9px] text-zinc-600 font-mono">{address}</span>
                {/* Priority Indicator: Red(1-2) = High/Urgent, Orange(3-4), Blue(5+) = Low */}
                <div className={`w-1.5 h-1.5 rounded-full ${process.priority <= 2 ? 'bg-red-500 shadow-[0_0_5px_rgba(239,68,68,0.5)]' :
                    process.priority <= 4 ? 'bg-orange-500' :
                        'bg-blue-500'
                    }`}></div>
            </div>

            {/* Body: Data */}
            <div className="p-2 space-y-1">
                <div className="flex justify-between items-end">
                    <span className="text-white font-bold text-sm">{process.name}</span>
                    <span className="text-[9px] text-zinc-500">P{process.priority} {process.mlfqLevel !== undefined && `Q${process.mlfqLevel}`}</span>
                </div>

                {/* Data Visual */}
                <div className="flex gap-0.5 h-1.5 w-full mt-1 opacity-50">
                    {Array.from({ length: 8 }).map((_, i) => (
                        <div key={i} className={`flex-1 rounded-[1px] ${i < (process.priority + 2) ? 'bg-zinc-600 group-hover:bg-primary' : 'bg-zinc-900'}`}></div>
                    ))}
                </div>

                <div className="grid grid-cols-2 gap-2 mt-2 pt-2 border-t border-zinc-900 text-[9px] text-zinc-500">
                    <div>BT: <span className="text-zinc-300">{process.burstTime}</span></div>
                    <div>REM: <span className="text-zinc-300">{process.remainingTime}</span></div>
                </div>
            </div>

            {/* Corner decorative */}
            <div className="absolute top-0 right-0 w-2 h-2 border-l border-b border-zinc-800 bg-zinc-950"></div>
        </motion.div>
    );
};

export const ReadyQueue: React.FC<Props> = ({ queue, processes, algorithm }) => {
    return (
        <div className="h-full flex flex-col font-mono text-xs bg-black p-4 overflow-hidden relative">
            {/* Cyberpunk Grid Background */}
            <div className="absolute inset-0 bg-[linear-gradient(rgba(18,18,18,0.5)_1px,transparent_1px),linear-gradient(90deg,rgba(18,18,18,0.5)_1px,transparent_1px)] bg-[size:20px_20px] pointer-events-none"></div>

            <div className="flex justify-between items-center mb-3 border-b border-zinc-900 pb-2 z-10">
                <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-primary animate-pulse rounded-full"></div>
                    <span className="text-zinc-400 font-bold">MEM_BUFFER</span>
                </div>
                <span className="text-zinc-600 bg-zinc-900 px-2 rounded text-[10px]">ADDR: 0x0000 - 0xFFFF</span>
            </div>

            {/* Advanced Memory Slots */}
            {algorithm === 'MLFQ' ? (
                <div className="flex-1 flex flex-col gap-4 overflow-y-auto custom-scrollbar z-10 pr-2 pb-4">
                    {[0, 1, 2].map(level => {
                        const levelQueue = queue.filter(id => processes.find(p => p.id === id)?.mlfqLevel === level);
                        return (
                            <div key={level} className="flex flex-col gap-2">
                                <div className="text-[10px] text-zinc-500 border-b border-zinc-800 pb-1 uppercase tracking-wider">Queue {level} <span className="text-zinc-700 normal-case ml-2">({level === 0 ? 'High' : level === 1 ? 'Medium' : 'Low'} Priority)</span></div>
                                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-2 min-h-[80px]">
                                    <AnimatePresence mode="popLayout">
                                        {levelQueue.length === 0 && (
                                            <div className="col-span-full h-16 flex flex-col items-center justify-center text-zinc-800 border-2 border-dashed border-zinc-900 rounded-lg">
                                                <span className="text-[10px] opacity-50">EMPTY</span>
                                            </div>
                                        )}
                                        {levelQueue.map((id, index) => {
                                            const process = processes.find(p => p.id === id);
                                            if (!process) return null;
                                            return <ProcessSlot key={id} id={id} index={index} process={process} />;
                                        })}
                                    </AnimatePresence>
                                </div>
                            </div>
                        );
                    })}
                </div>
            ) : (
                <div className="flex-1 content-start grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-2 overflow-y-auto custom-scrollbar z-10 pr-2">
                    <AnimatePresence mode="popLayout">
                        {queue.length === 0 && (
                            <div className="col-span-full h-24 flex flex-col items-center justify-center text-zinc-800 border-2 border-dashed border-zinc-900 rounded-lg">
                                <span className="font-bold text-lg opacity-50">NULL POINTER</span>
                                <span className="text-[10px]">BUFFER IS EMPTY</span>
                            </div>
                        )}
                        {queue.map((id, index) => {
                            const process = processes.find(p => p.id === id);
                            if (!process) return null;
                            return <ProcessSlot key={id} id={id} index={index} process={process} />;
                        })}
                    </AnimatePresence>
                </div>
            )}
        </div>
    );
};
