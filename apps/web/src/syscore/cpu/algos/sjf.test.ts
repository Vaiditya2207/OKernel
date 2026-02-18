import { describe, it, expect } from 'vitest';
import { sjf } from './sjf';
import { Process } from '../../../core/types';

describe('SJF Algorithm', () => {
    const processes: Process[] = [
        {
            id: 1,
            name: 'P1',
            burstTime: 10,
            arrivalTime: 0,
            priority: 1,
            remainingTime: 10,
            color: 'red',
            state: 'READY',
            startTime: null,
            completionTime: null,
            waitingTime: 0,
            turnaroundTime: 0,
        },
        {
            id: 2,
            name: 'P2',
            burstTime: 5,
            arrivalTime: 0,
            priority: 2,
            remainingTime: 5,
            color: 'blue',
            state: 'READY',
            startTime: null,
            completionTime: null,
            waitingTime: 0,
            turnaroundTime: 0,
        },
        {
            id: 3,
            name: 'P3',
            burstTime: 8,
            arrivalTime: 0,
            priority: 3,
            remainingTime: 8,
            color: 'green',
            state: 'READY',
            startTime: null,
            completionTime: null,
            waitingTime: 0,
            turnaroundTime: 0,
        },
    ];

    it('should return null if readyQueue is empty', () => {
        expect(sjf([], processes)).toBeNull();
    });

    it('should return the only process in the readyQueue', () => {
        expect(sjf([1], processes)).toBe(1);
    });

    it('should return the process with the shortest burst time', () => {
        expect(sjf([1, 2, 3], processes)).toBe(2);
    });

    it('should return the process with the shortest burst time among a subset', () => {
        expect(sjf([1, 3], processes)).toBe(3);
    });

    it('should return the first process if there is a tie in burst time', () => {
        const tiedProcesses: Process[] = [
            ...processes,
            {
                id: 4,
                name: 'P4',
                burstTime: 5,
                arrivalTime: 0,
                priority: 4,
                remainingTime: 5,
                color: 'yellow',
                state: 'READY',
                startTime: null,
                completionTime: null,
                waitingTime: 0,
                turnaroundTime: 0,
            },
        ];
        // Both 2 and 4 have burstTime 5. If [2, 4] is readyQueue, it should pick 2.
        expect(sjf([2, 4], tiedProcesses)).toBe(2);
        // If [4, 2] is readyQueue, it should pick 4.
        expect(sjf([4, 2], tiedProcesses)).toBe(4);
    });

    it('should handle missing processes by ignoring them', () => {
        // pid 99 and 100 don't exist in processes.
        // 1 exists and should be returned.
        expect(sjf([99, 1, 100], processes)).toBe(1);
    });

    it('should return null if no processes in readyQueue exist in processes array', () => {
        expect(sjf([99, 100], processes)).toBeNull();
    });
});
