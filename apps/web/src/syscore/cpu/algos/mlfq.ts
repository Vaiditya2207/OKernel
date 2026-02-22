import { Process } from '../../../core/types';

export const mlfq = (readyQueue: number[], processes: Process[]): number | null => {
  if (readyQueue.length === 0) return null;

  let bestCandidateId: number | null = null;
  let highestPriorityLevel = Infinity;

  for (const processId of readyQueue) {
    const process = processes.find(p => p.id === processId);
    if (process) {
      const level = process.mlfqLevel ?? 0;
      if (level < highestPriorityLevel) {
        highestPriorityLevel = level;
        bestCandidateId = processId;
      } else if (level === highestPriorityLevel && bestCandidateId !== null) {
        // FIFO within the same queue
        // We rely on readyQueue order which is usually insertion order (FIFO)
        // So we do nothing if level is equal, preferring the first encountered.
      }
    }
  }

  return bestCandidateId;
};

// Quantum configuration per MLFQ level
export const MLFQ_QUANTUMS: Record<number, number> = {
  0: 2,  // High Priority: Small Quantum
  1: 4,  // Medium Priority: Medium Quantum
  2: Infinity, // Lowest Priority: FCFS (runs to completion or very large quantum)
};
