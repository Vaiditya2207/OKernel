import { SimulationState, Process, AlgorithmType } from '../../core/types';
import { fcfs } from './algos/fcfs';
import { sjf } from './algos/sjf';
import { srtf } from './algos/srtf';
import { round_robin, rr_should_preempt } from './algos/round_robin';
import { priority } from './algos/priority';
import { mlfq, MLFQ_QUANTUMS } from './algos/mlfq';

export const tick = (state: SimulationState): SimulationState => {
    // 1. Clone Shallow State
    const newState: SimulationState = {
        ...state,
        processes: [...state.processes],
        readyQueue: [...state.readyQueue],
        ganttChart: [...state.ganttChart],
        completedProcessIds: [...state.completedProcessIds]
    };

    // Build id -> index map (O(N) once per tick)
    const indexMap = new Map<number, number>();
    newState.processes.forEach((p, i) => indexMap.set(p.id, i));

    // MLFQ Pre-tick logic: Priority Boost
    if (newState.algorithm === 'MLFQ') {
        newState.mlfqBoostTicks++;
        if (newState.mlfqBoostTicks >= newState.mlfqBoostTime) {
            // Priority boost: move all ready and running processes back to Q0
            newState.mlfqBoostTicks = 0;
            newState.processes.forEach((p, index) => {
                if (p.state === 'READY' || p.state === 'RUNNING') {
                    newState.processes[index] = { ...p, mlfqLevel: 0 };
                }
            });
            // Running process might need a refreshed quantum since it was boosted
            if (newState.runningProcessId !== null) {
                newState.quantumRemaining = MLFQ_QUANTUMS[0];
            }
        }
    }

    // 2. Handle Arrivals
    newState.processes.forEach((p, index) => {
        if (p.state === 'WAITING' && p.arrivalTime <= newState.currentTime) {
            newState.processes[index] = {
                ...p,
                state: 'READY'
            };
            newState.readyQueue.push(p.id);
        }
    });

    // 3. Algorithm Selection Logic
    const selectProcess = (algo: AlgorithmType, queue: number[], procs: Process[]): number | null => {
        switch (algo) {
            case 'FCFS': return fcfs(queue, procs);
            case 'SJF': return sjf(queue, procs);
            case 'SRTF': return srtf(queue, procs);
            case 'RR': return round_robin(queue, procs);
            case 'PRIORITY': return priority(queue, procs);
            case 'MLFQ': return mlfq(queue, procs);
            default: return fcfs(queue, procs);
        }
    };

    // 4. Scheduling Decision
    let processToRunId = newState.runningProcessId;
    let shouldPreempt = false;

    // Check preemption for RR
    if (newState.algorithm === 'RR' && processToRunId !== null) {
        if (rr_should_preempt(newState.quantumRemaining)) {
            shouldPreempt = true;
        }
    }

    // Check preemption for MLFQ
    if (newState.algorithm === 'MLFQ' && processToRunId !== null) {
        if (newState.quantumRemaining <= 0) {
            shouldPreempt = true;
            // Demote the process
            const idx = indexMap.get(processToRunId);
            if (idx !== undefined) {
                const currentProc = newState.processes[idx];
                const currentLevel = currentProc.mlfqLevel ?? 0;
                if (currentLevel < 2) {
                    newState.processes[idx] = {
                        ...currentProc,
                        mlfqLevel: currentLevel + 1
                    };
                }
            }
        } else {
            // SRTF-like preemption: a higher priority process might have arrived or been boosted
            const bestCandidate = selectProcess('MLFQ', [...newState.readyQueue, processToRunId], newState.processes);
            if (bestCandidate !== null && bestCandidate !== processToRunId) {
                shouldPreempt = true;
            }
        }
    }

    // Check preemption for SRTF (Simulated by checking if selection changes)
    if (newState.algorithm === 'SRTF' && processToRunId !== null) {
        const bestCandidate = selectProcess('SRTF', [...newState.readyQueue, processToRunId], newState.processes);
        if (bestCandidate !== null && bestCandidate !== processToRunId) {
            shouldPreempt = true;
        }
    }

    // If no running process or preempted, select next
    if (processToRunId === null || shouldPreempt) {
        if (processToRunId !== null) {
            const idx = indexMap.get(processToRunId);
            if (idx !== undefined && newState.processes[idx].state === 'RUNNING') {
                newState.processes[idx] = {
                    ...newState.processes[idx],
                    state: 'READY'
                };
                newState.readyQueue.push(processToRunId);
            }
            newState.runningProcessId = null;
        }

        // Pick next
        const nextId = selectProcess(newState.algorithm, newState.readyQueue, newState.processes);

        if (nextId !== null) {
            const idx = indexMap.get(nextId);
            if (idx !== undefined) {
                newState.processes[idx] = {
                    ...newState.processes[idx],
                    state: 'RUNNING',
                    startTime:
                        newState.processes[idx].startTime ?? newState.currentTime
                };

                if (newState.algorithm === 'RR') {
                    newState.quantumRemaining = newState.timeQuantum;
                } else if (newState.algorithm === 'MLFQ') {
                    const level = newState.processes[idx].mlfqLevel ?? 0;
                    newState.quantumRemaining = MLFQ_QUANTUMS[level];
                }

                newState.runningProcessId = nextId;
                const index = newState.readyQueue.indexOf(nextId);
                if (index !== -1) {
                    newState.readyQueue.splice(index, 1);
                }
                processToRunId = nextId;
            }
        }
    }

    // 5. Execution Step
    if (newState.runningProcessId !== null) {
        const idx = indexMap.get(newState.runningProcessId);
        if (idx !== undefined) {
            const proc = newState.processes[idx];

            const updatedProc = {
                ...proc,
                remainingTime: proc.remainingTime - 1
            };

            newState.processes[idx] = updatedProc;

            if (newState.algorithm === 'RR' || newState.algorithm === 'MLFQ') {
                newState.quantumRemaining--;
            }

            // Update Gantt Chart
            const lastBlock = newState.ganttChart[newState.ganttChart.length - 1];
            if (lastBlock && lastBlock.processId === updatedProc.id && lastBlock.endTime === newState.currentTime) {
                newState.ganttChart[newState.ganttChart.length - 1] = {
                    ...lastBlock,
                    endTime: lastBlock.endTime + 1
                }
            } else {
                // New block
                newState.ganttChart.push({
                    processId: updatedProc.id,
                    startTime: newState.currentTime,
                    endTime: newState.currentTime + 1
                });
            }

            // Completion
            if (updatedProc.remainingTime - 1 < 0 || updatedProc.remainingTime === 0) {
                const completionTime = newState.currentTime + 1;
                const turnaroundTime = completionTime - updatedProc.arrivalTime;

                newState.processes[idx] = {
                    ...updatedProc,
                    state: 'COMPLETED',
                    completionTime,
                    turnaroundTime,
                    waitingTime: turnaroundTime - updatedProc.burstTime
                };

                newState.completedProcessIds.push(updatedProc.id);
                newState.runningProcessId = null;
            }
        }
    } else {
        // Idle Time
        const lastBlock = newState.ganttChart[newState.ganttChart.length - 1];
        if (lastBlock && lastBlock.processId === null && lastBlock.endTime === newState.currentTime) {
            newState.ganttChart[newState.ganttChart.length - 1] = {
                ...lastBlock,
                endTime: lastBlock.endTime + 1
            }
        } else {
            newState.ganttChart.push({
                processId: null,
                startTime: newState.currentTime,
                endTime: newState.currentTime + 1
            });
        }
    }

    // 6. Advance Time
    newState.currentTime++;

    return newState;
};
