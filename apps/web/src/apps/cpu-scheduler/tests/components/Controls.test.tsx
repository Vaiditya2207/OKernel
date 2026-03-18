import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { Controls } from '../../components/Controls';
import { SimulationState } from '../../../../core/types';

describe('Controls Component', () => {
  const mockState: SimulationState = {
    currentTime: 0,
    processes: [],
    readyQueue: [],
    runningProcessIds: [null],
    completedProcessIds: [],
    ganttChart: [],
    algorithm: 'FCFS',
    timeQuantum: 2,
    quantumRemaining: [0],
    isPlaying: false,
    speed: 1000,
    contextSwitchCost: 1,
    contextSwitchCount: 0,
    contextSwitchTimeWasted: 0,
    contextSwitchCooldown: [0],
    priorityAgingEnabled: false,
    priorityAgingInterval: 5,
    numCores: 1,
    mlfqQueues: [[], [], []],
    mlfqQuantums: [2, 4, 8],
    mlfqNumQueues: 3,
    mlfqCurrentLevel: [0],
  };

  const mockSetState = vi.fn();
  const mockOnReset = vi.fn();

  it('renders correctly in initial state', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);

    expect(screen.getByText('[ EXEC ]')).toBeInTheDocument();
    expect(screen.getByTitle('Reset Simulation')).toBeInTheDocument();
    expect(screen.getByText('ALGO:')).toBeInTheDocument();
    expect(screen.getByText('First Come First Serve')).toBeInTheDocument();
    expect(screen.getByText('T=')).toBeInTheDocument();
    expect(screen.getByText('0ms')).toBeInTheDocument();
  });

  it('toggles playback state when play button is clicked', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);
    const playButton = screen.getByText('[ EXEC ]').closest('button');
    if (!playButton) throw new Error("Play button not found");
    fireEvent.click(playButton);
    expect(mockSetState).toHaveBeenCalledTimes(1);
  });

  it('renders PAUSE when playing', () => {
    const playingState = { ...mockState, isPlaying: true };
    render(<Controls state={playingState} setState={mockSetState} onReset={mockOnReset} />);
    expect(screen.getByText('[ PAUSE ]')).toBeInTheDocument();
  });

  it('calls onReset when reset button is clicked', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);
    const resetButton = screen.getByTitle('Reset Simulation');
    fireEvent.click(resetButton);
    expect(mockOnReset).toHaveBeenCalledTimes(1);
  });

  it('changes algorithm when selected', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);
    const trigger = screen.getByText('FCFS').closest('button');
    if (!trigger) throw new Error("Dropdown trigger not found");
    fireEvent.click(trigger);
    
    const sjfOption = screen.getByText('Shortest Job First');
    fireEvent.click(sjfOption.closest('button')!);
    expect(mockSetState).toHaveBeenCalled();
  });

  it('shows time quantum input only when RR is selected', () => {
    const rrState = { ...mockState, algorithm: 'RR' as const };
    render(<Controls state={rrState} setState={mockSetState} onReset={mockOnReset} />);
    expect(screen.getByText('Q_TIME:')).toBeInTheDocument();
    expect(screen.getByDisplayValue('2')).toBeInTheDocument();
  });

  it('does not show time quantum input when non-RR algorithm is selected', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);
    expect(screen.queryByText('Q_TIME:')).not.toBeInTheDocument();
  });

  it('updates speed when slider is moved', () => {
    render(<Controls state={mockState} setState={mockSetState} onReset={mockOnReset} />);
    const slider = screen.getByRole('slider');
    fireEvent.change(slider, { target: { value: '1500' } });
    expect(mockSetState).toHaveBeenCalled();
  });
});