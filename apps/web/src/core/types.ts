export type ProcessState = 'READY' | 'RUNNING' | 'COMPLETED' | 'WAITING';

export interface Process {
    id: number;
    name: string;
    burstTime: number;
    arrivalTime: number;
    priority: number;
    remainingTime: number;
    color: string;
    state: ProcessState;

    // Stats
    startTime: number | null;
    completionTime: number | null;
    waitingTime: number;
    turnaroundTime: number;

    // MLFQ
    mlfqLevel?: number; // 0, 1, 2
}
export type AlgorithmType = 'FCFS' | 'SJF' | 'SRTF' | 'RR' | 'PRIORITY' | 'MLFQ';
export interface GanttBlock {
    processId: number | null;
    startTime: number;
    endTime: number;
}

export interface SimulationState {
    currentTime: number;
    processes: Process[];
    readyQueue: number[]; // Process IDs
    runningProcessId: number | null;
    completedProcessIds: number[];
    ganttChart: GanttBlock[];

    // Control State
    algorithm: AlgorithmType;
    timeQuantum: number;
    quantumRemaining: number; // For RR
    speed: number;

    // MLFQ State
    mlfqBoostTime: number;
    mlfqBoostTicks: number; // Ticks since last boost
}
