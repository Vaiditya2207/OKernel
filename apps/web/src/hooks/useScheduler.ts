import { useState, useEffect } from 'react';
import { SimulationState, Process } from '../core/types';
import { tick } from '../syscore/cpu';

const initialState: SimulationState = {
    currentTime: 0,
    processes: [],
    readyQueue: [],
    runningProcessId: null,
    completedProcessIds: [],
    ganttChart: [],
    algorithm: 'FCFS',
    timeQuantum: 2,
    isPlaying: false,
    speed: 1000,
    mlfqBoostTime: 20, // Boost every 20 ticks
    mlfqBoostTicks: 0,
};

export const useScheduler = () => {
    const [state, setState] = useState<SimulationState>(initialState);

    useEffect(() => {
        let timeout: ReturnType<typeof setTimeout> | undefined;

        const performTick = () => {
            const allDone = state.processes.length > 0 && state.processes.every(p => p.state === 'COMPLETED');
            if (allDone || state.currentTime > 1000) {
                setState(prev => ({ ...prev, isPlaying: false }));
                return;
            }

            try {
                // Use local simulation logic instead of backend
                const nextState = tick(state);
                setState(nextState);
            } catch (error) {
                console.error('Simulation tick failed:', error);
                setState(prev => ({ ...prev, isPlaying: false }));
            }
        };

        if (state.isPlaying) {
            timeout = setTimeout(performTick, state.speed);
        }

        return () => {
            if (timeout) clearTimeout(timeout);
        };
    }, [state]);

    const addProcess = (processData: Omit<Process, 'id' | 'state' | 'color' | 'remainingTime' | 'startTime' | 'completionTime' | 'waitingTime' | 'turnaroundTime' | 'mlfqLevel'>) => {
        setState(prev => {
            const newId = prev.processes.length > 0 ? Math.max(...prev.processes.map(p => p.id)) + 1 : 1;
            const colors = ['#3b82f6', '#8b5cf6', '#ec4899', '#10b981', '#f59e0b', '#6366f1'];
            const color = colors[(newId - 1) % colors.length];

            const newProcess: Process = {
                id: newId,
                ...processData,
                state: 'WAITING', // Correct initial state. Scheduler promotes to READY at AT.
                remainingTime: processData.burstTime,
                startTime: null,
                completionTime: null,
                waitingTime: 0,
                turnaroundTime: 0,
                mlfqLevel: 0
            };

            return {
                ...prev,
                processes: [...prev.processes, newProcess],
                readyQueue: prev.readyQueue // DO NOT add to queue here. Scheduler loop handles it.
            };
        });
    };

    const reset = () => {
        setState(prev => ({
            ...initialState,
            algorithm: prev.algorithm,
            timeQuantum: prev.timeQuantum,
            speed: prev.speed,
            processes: prev.processes.map(p => ({
                ...p,
                state: 'WAITING',
                remainingTime: p.burstTime,
                startTime: null,
                completionTime: null,
                waitingTime: 0,
                turnaroundTime: 0
            })),
            currentTime: 0,
            readyQueue: [],
            runningProcessId: null,
            ganttChart: [],
            quantumRemaining: 0,
            isPlaying: false,
            mlfqBoostTicks: 0
        }));
    };

    const clear = () => {
        setState(prev => ({ ...initialState, algorithm: prev.algorithm, speed: prev.speed, timeQuantum: prev.timeQuantum }));
    }

    return { state, setState, addProcess, reset, clear };
};
