module StepSize

export AbstractStepSize,
    AbstractStepSizeState,
    HeuristicStepSize,
    HeuristicStepSizeState,
    state,
    initial_steplength,
    update!

"""
    AbstractStepSize

Abstract type representing the configuration for the step length logic of a path tracker.
This always deals with a normalized parameter space, i.e., ``t ∈ [0, 1]``.
"""
abstract type AbstractStepSize end

"""
    AbstractStepSizeState

Abstract type representing the state of a `AbstractStepSize` implementation.
"""
abstract type AbstractStepSizeState end

"""
    state(::AbstractStepSize)::AbstractStepSizeState

Initialize the state for the given step length type.
"""
function state end

"""
    reset!(state::AbstractStepSizeState)

Reset the state to the initial state again.
"""
function reset! end


# FIXME: The API is not stable. This needs to be modified for verified pathtracking.

"""
    isrelative(::AbstractStepSize)

Indicate whether the returned step length is relative or absolute, i.e.,
if we want to track from `1` to `5`. A relative step length of `0.1` would result
in an effective step length of `0.4` while an absolute step length of `0.1` would result
in an effective step length of `0.1`.
"""
function isrelative end

"""
    initial_steplength(::AbstractStepSize)

Return the initial step length of a path.
"""
function initial_steplength end

"""
    update(curr_steplength, step::AbstractStepSize, state::AbstractStepSizeState, success::Bool)

Returns `(t, status)` where `t` is the new step length and `status` is either
`:ok` (usually) or  any symbol indicating why the update failed (e.g. `:steplength_too_small` if the step size is too small).
The argument `success` indicates whether the step was successfull. This
modifies `state` if necessary.
"""
function update end


# Implementation
"""
    HeuristicStepSize(;initial=0.1,
        increase_factor=2.0,
        decrease_factor=inv(increase_factor),
        consecutive_successes_necessary=3,
        minimal_stepsize=eps())

The step length is defined as follows. Initially the step length is `initial`.
If `consecutive_successes_necessary` consecutive steps were sucessfull the step length
is increased by the factor `increase_factor`. If a step fails, i.e. the corrector does
not converge, the steplength is reduced by the factor `decrease_factor`.
"""
struct HeuristicStepSize <: AbstractStepSize
    initial::Float64
    increase_factor::Float64
    decrease_factor::Float64
    consecutive_successes_necessary::Int
    minimal_stepsize::Float64
end
function HeuristicStepSize(;initial=0.1,
    increase_factor=2.0,
    decrease_factor=inv(increase_factor),
    consecutive_successes_necessary=3,
    minimal_stepsize=eps())

    HeuristicStepSize(initial, increase_factor,
        decrease_factor, consecutive_successes_necessary, minimal_stepsize)
end

mutable struct HeuristicStepSizeState <: AbstractStepSizeState
    consecutive_successes::Int
end

state(step::HeuristicStepSize) = HeuristicStepSizeState(0)
function reset!(state::HeuristicStepSizeState)
    state.consecutive_successes = 0
end

isrelative(::HeuristicStepSize) = true
initial_steplength(step::HeuristicStepSize) = step.initial

function update(curr_steplength, step::HeuristicStepSize, state::HeuristicStepSizeState, success)
    if success
        if (state.consecutive_successes += 1) == step.consecutive_successes_necessary
            state.consecutive_successes = 0
            return (step.increase_factor * curr_steplength, :ok)
        end
        return (curr_steplength, :ok)
    end
    # reset successes
    state.consecutive_successes = 0

    # we decrease the steplength
    new_steplength = step.decrease_factor * curr_steplength

    if new_steplength < step.minimal_stepsize
        return (new_steplength, :step_size_too_small)
    end

    (new_steplength, :ok)
end

end