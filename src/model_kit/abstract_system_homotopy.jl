export AbstractSystem, AbstractHomotopy, jacobian

"""
    AbstractSystem

An abstract type representing a polynomial system ``F(x, p)`` where ``x`` are variables
and ``p`` are possible parameters.
"""
abstract type AbstractSystem end

# Base.size(F::AbstractSystem)
Base.size(F::AbstractSystem, i::Integer) = size(F)[i]
Base.length(F::AbstractSystem) = size(F, 1)

"""
    parameters(F::AbstractSystem)

Returns the [`Variable`](@ref)s used in the system.
"""
parameters(F::AbstractSystem) = Variable[]

"""
    variable_groups(F::AbstractSystem)

Returns the variable groups of the system.
"""
variable_groups(::AbstractSystem) = nothing

"""
    nvariables(F::AbstractSystem)

Returns the number of variables of a given system `F`.
"""
nvariables(F::AbstractSystem) = size(F, 2)

"""
    nparameters(F::AbstractSystem)

Returns the number of parameters of a given system `F`.
"""
nparameters(F::AbstractSystem) = length(parameters(F))

"""
    System(F::AbstractSystem)

Construct a (symbolic) [`System`](@ref) from `F`.
"""
function System(F::AbstractSystem)
    x, p = variables(F), parameters(F)
    System(F(x, p), x, p, variable_groups(F))
end

(F::AbstractSystem)(x, p = nothing) = evaluate(F, x, p)

"""
    evaluate(F::AbstractSystem, x, p = nothing)

Evaluate the given system.
"""
function evaluate(F::AbstractSystem, x, p = nothing)
    u = Vector{Any}(undef, size(F, 1))
    evaluate!(u, F, x, p)
    ModelKit.to_smallest_eltype(u)
end

"""
    jacobian(F::AbstractSystem, x, p = nothing)

Compute the Jacobian of the given system.
"""
function jacobian(F::AbstractSystem, x, p = nothing)
    u = Vector{Any}(undef, size(F, 1))
    U = Matrix{Any}(undef, size(F))
    evaluate_and_jacobian!(u, U, F, x, p)
    ModelKit.to_smallest_eltype(U)
end

##############
## Homotopy ##
##############

"""
    AbstractHomotopy

An abstract type representing a homotopy ``H(x, t)`` where ``x`` are variables
and ``t`` is space / time.
"""
abstract type AbstractHomotopy end

Base.size(H::AbstractHomotopy, i::Integer) = i == 1 ? first(size(H)) : last(size(H))

(H::AbstractHomotopy)(x, t, p = nothing) = evaluate(H, x, t, p)
function evaluate(H::AbstractHomotopy, x, t, p = nothing)
    U = Vector{Any}(undef, first(size(H)))
    to_smallest_eltype(evaluate!(U, H, x, t, p))
end

function jacobian(H::AbstractHomotopy, x, t, p = nothing)
    n, m = size(H)
    u = Vector{Any}(undef, size(H, 1))
    U = Matrix{Any}(undef, size(H))
    evaluate_and_jacobian!(u, U, H, x, t, p)
    to_smallest_eltype(U)
end
