import { Process } from '../../../core/types';

export const sjf = (readyQueue: number[], processes: Process[]): number | null => {
    let shortestProcessId: number | null = null;
    let minBurstTime = Infinity;

    for (const pid of readyQueue) {
        const process = processes.find(p => p.id === pid);
        if (process) {
            if (process.burstTime < minBurstTime) {
                minBurstTime = process.burstTime;
                shortestProcessId = pid;
            } else if (shortestProcessId === null) {
                // Initialize with the first valid process found
                minBurstTime = process.burstTime;
                shortestProcessId = pid;
            }
        }
    }

    return shortestProcessId;
};
