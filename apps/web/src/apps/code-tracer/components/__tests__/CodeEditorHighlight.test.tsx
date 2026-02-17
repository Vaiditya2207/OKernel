import { render } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import CodeEditor from '../CodeEditor';

// Mock types
const mockDeltaDecorations = vi.fn();
const mockGetModel = vi.fn();
const mockGetDecorationsInRange = vi.fn();
const mockRevealLineInCenter = vi.fn();

const mockEditorInstance = {
    getModel: mockGetModel,
    deltaDecorations: mockDeltaDecorations,
    getDecorationsInRange: mockGetDecorationsInRange,
    revealLineInCenter: mockRevealLineInCenter,
};

const mockMonaco = {
    Range: class Range {
        constructor(public startLine: number, public startCol: number, public endLine: number, public endCol: number) {}
    },
};

vi.mock('@monaco-editor/react', () => ({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    Editor: ({ onMount, value }: any) => {
        if (onMount) {
            setTimeout(() => onMount(mockEditorInstance), 0);
        }
        return <div data-testid="monaco-editor">{value}</div>;
    },
    useMonaco: () => mockMonaco,
}));

describe('CodeEditor Highlights', () => {
    it('applies correct decoration styles for highlighted line', async () => {
        // Setup mocks
        mockGetModel.mockReturnValue({
            getFullModelRange: () => ({}),
        });
        mockGetDecorationsInRange.mockReturnValue([]);

        const { rerender } = render(
            <CodeEditor
                code="print('hello')"
                onChange={() => {}}
                language="python"
                highlightLine={undefined}
            />
        );

        // Wait for onMount to fire
        await new Promise(resolve => setTimeout(resolve, 50));

        // Rerender with highlightLine
        rerender(
            <CodeEditor
                code="print('hello')"
                onChange={() => {}}
                language="python"
                highlightLine={5}
            />
        );

        // Wait for useEffect to run
        await new Promise(resolve => setTimeout(resolve, 50));

        // Check deltaDecorations call
        expect(mockDeltaDecorations).toHaveBeenCalled();
        
        const calls = mockDeltaDecorations.mock.calls;
        const lastCall = calls[calls.length - 1];
        const newDecorations = lastCall[1]; // The second argument is the new decorations array

        expect(newDecorations).toHaveLength(1);
        const decoration = newDecorations[0];
        
        expect(decoration.range.startLine).toBe(5);
        expect(decoration.options.isWholeLine).toBe(true);
        expect(decoration.options.className).toBe('monaco-active-line');
    });

    it('clears old decorations correctly', async () => {
        // Setup existing decorations to be cleared
        const oldDecorationId = 'old-decoration-id';
        mockGetDecorationsInRange.mockReturnValue([
            {
                id: oldDecorationId,
                options: {
                    className: 'monaco-active-line'
                }
            }
        ]);

        const { rerender } = render(
            <CodeEditor
                code="print('hello')"
                onChange={() => {}}
                language="python"
                highlightLine={undefined}
            />
        );
        
        // Wait for onMount to fire
        await new Promise(resolve => setTimeout(resolve, 50));

        rerender(
            <CodeEditor
                code="print('hello')"
                onChange={() => {}}
                language="python"
                highlightLine={5}
            />
        );

        // Wait for useEffect to run
        await new Promise(resolve => setTimeout(resolve, 50));

        const calls = mockDeltaDecorations.mock.calls;
        const lastCall = calls[calls.length - 1];
        const oldDecorationsIds = lastCall[0];
        
        expect(oldDecorationsIds).toContain(oldDecorationId);
    });
});
