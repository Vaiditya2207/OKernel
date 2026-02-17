import { Process } from '../../../core/types';

export const priority = (readyQueue: number[], processes: Process[]): number | null => {
    if (readyQueue.length === 0) return null;

    // Optimize: Create a map for O(1) lookup
    // We only set the value if the key doesn't exist to match Array.find behavior (returns first match)
    const processMap = new Map<number, Process>();
    for (const p of processes) {
        if (!processMap.has(p.id)) {
            processMap.set(p.id, p);
        }
    }

    let highestPriorityId = readyQueue[0];
    // Lower number means higher priority
    let bestPriority = processMap.get(readyQueue[0])?.priority;
    if (bestPriority === undefined) bestPriority = Infinity;

    for (const pid of readyQueue) {
        const process = processMap.get(pid);
        if (process && process.priority < bestPriority) {
            bestPriority = process.priority;
            highestPriorityId = pid;
        }
    }

    return highestPriorityId;
};
