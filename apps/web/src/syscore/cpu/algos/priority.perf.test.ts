import { priority } from './priority';
import { Process } from '../../../core/types';
import { describe, it, expect } from 'vitest';

describe('Priority Algorithm', () => {
    const mockProcess = (overrides: Partial<Process>): Process => ({
        id: 0,
        name: 'Process',
        burstTime: 10,
        arrivalTime: 0,
        priority: 0,
        remainingTime: 10,
        color: '#000000',
        state: 'READY',
        startTime: null,
        completionTime: null,
        waitingTime: 0,
        turnaroundTime: 0,
        ...overrides,
    });

    const generateProcesses = (count: number): Process[] => {
        return Array.from({ length: count }, (_, i) => mockProcess({
            id: i,
            name: `Process ${i}`,
            priority: Math.floor(Math.random() * 20),
        }));
    };

    it('should be fast', () => {
        const processCount = 20000;
        const queueSize = 5000;
        const processes = generateProcesses(processCount);
        const readyQueue = Array.from({ length: queueSize }, () => Math.floor(Math.random() * processCount));

        const start = performance.now();
        const iterations = 10;
        for (let i = 0; i < iterations; i++) {
            priority(readyQueue, processes);
        }
        const end = performance.now();
        console.log(`[Perf] Time taken for ${iterations} iterations with ${processCount} processes and ${queueSize} queue size: ${(end - start).toFixed(2)}ms`);
        console.log(`[Perf] Average time per iteration: ${((end - start) / iterations).toFixed(4)}ms`);
    });

    it('should correctly select highest priority (lowest number)', () => {
        const processes: Process[] = [
            mockProcess({ id: 1, priority: 10 }),
            mockProcess({ id: 2, priority: 5 }),
            mockProcess({ id: 3, priority: 8 }),
            mockProcess({ id: 4, priority: 5 }) // Same priority as 2
        ];
        const readyQueue = [1, 2, 3, 4];

        // Should select 2 because it has lowest priority number (5) and appears before 4 in readyQueue
        expect(priority(readyQueue, processes)).toBe(2);
    });

    it('should handle tie breaking by readyQueue order', () => {
        const processes: Process[] = [
            mockProcess({ id: 1, priority: 10 }),
            mockProcess({ id: 2, priority: 5 }),
            mockProcess({ id: 3, priority: 5 })
        ];
        // If readyQueue order is 3, 2, 1
        const readyQueue = [3, 2, 1];

        // bestPriority starts at p(id=3).priority = 5.
        // Checks p(id=2). priority 5 < 5 is false.
        // Checks p(id=1). priority 10 < 5 is false.
        // Returns 3.
        expect(priority(readyQueue, processes)).toBe(3);
    });

    it('should handle null / empty readyQueue', () => {
         expect(priority([], [])).toBe(null);
    });
});
