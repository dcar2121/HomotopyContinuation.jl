export PolyhedralHomotopy, PolyhedralHomotopyCache, gamma

"""
    PolyhedralHomotopy(G, F; gamma=exp(i * 2π*rand()))

Construct the homotopy ``H(x, s) = Σ_α c_α e^{(α̂⋅γ̂) s} x^α``.
"""
mutable struct PolyhedralHomotopy{S<:SPSystem, T} <: AbstractHomotopy
    system::S
    nterms::Vector{Int}
    support::Matrix{Int32}
    lifting::Vector{Int32}
    coeffs::Vector{T}
    s_weights::Vector{Float64}
end

function PolyhedralHomotopy(supports::Vector{<:Matrix}, liftings::Vector{Vector{Int32}}, coefficients::Vector{Vector{T}}) where T
    @assert all(length.(coefficients) .== size.(supports,2))
    @assert length(liftings) == length(supports)

    system = SPSystem(supports, coefficients)
    # StaticPolynomials possibly changes the order of the terms.
    # Therefore the coefficient vectors are maybe no more correct.
    # We correct this by applying the permutation applied to the columns
    # of the support

    nterms = length.(liftings)
    M = sum(nterms)
    n = length(liftings)
    support = Matrix{Int32}(undef, n, M)
    lifting = Vector{Int32}(undef, M)
    coeffs = Vector{T}(undef, M)
    k = 1
    for (i, f) in enumerate(system.system.polys)
        p = SP.permutation(f)
        for j in p
            @. support[:,k] = supports[i][:,j]
            lifting[k] = liftings[i][j]
            coeffs[k] = coefficients[i][j]
            k += 1
        end
    end
    s_weights = zeros(sum(nterms))

    PolyhedralHomotopy(system, nterms, support, lifting, coeffs, s_weights)
end

function update_cell!(H::PolyhedralHomotopy, cell::MixedSubdivisions.MixedCell)
    n = length(H.nterms)
    γ = cell.normal
    k = 1
    @inbounds for (i, m) in enumerate(H.nterms)
        βᵢ = cell.β[i]
        for _ in 1:m
            s_k = Float64(H.lifting[k]) - βᵢ
            for l in 1:n
                s_k += H.support[l,k] * γ[l]
            end
            H.s_weights[k] = s_k
            k += 1
        end
    end
    H
end

"""
    PolyhedralHomotopyCache

An simple cache for `PolyhedralHomotopyCache`.
"""
mutable struct PolyhedralHomotopyCache{C<:AbstractSystemCache, T} <: AbstractHomotopyCache
    system::C
    coeffs::Vector{T}
    coeffs_dt::Vector{T}
    views_coeffs::Vector{SubArray{T,1,Vector{T},Tuple{UnitRange{Int}}, true}}
    views_coeffs_dt::Vector{SubArray{T,1,Vector{T},Tuple{UnitRange{Int}}, true}}
    s::Float64
    ds::Float64
    active_coeffs::ActiveCoeffs
end

function cache(H::PolyhedralHomotopy{S,T}, x, s) where {S,T}
    system = cache(H.system, x, s)
    U = promote_type(T, typeof(s))
    coeffs = convert.(U, H.coeffs)
    coeffs_dt = copy(H.coeffs)
    views_coeffs = [view(coeffs, 1:H.nterms[1])]
    views_coeffs_dt = [view(coeffs_dt, 1:H.nterms[1])]
    k = H.nterms[1] + 1
    for i in 2:length(H.nterms)
        push!(views_coeffs, view(coeffs, k:k+H.nterms[i]-1))
        push!(views_coeffs_dt, view(coeffs_dt, k:k+H.nterms[i]-1))
        k += H.nterms[i]
    end
    s = ds = NaN
    active_coeffs = COEFFS_UNKNOWN
    PolyhedralHomotopyCache(system, coeffs, coeffs_dt, views_coeffs, views_coeffs_dt, s, ds, active_coeffs)
end

Base.size(H::PolyhedralHomotopy) = size(H.system)

function update_coeffs!(cache::PolyhedralHomotopyCache, H::PolyhedralHomotopy, s)
    if s == cache.s
        if cache.active_coeffs != COEFFS_EVAL
            set_coefficients!(H.system, cache.views_coeffs)
            cache.active_coeffs == COEFFS_EVAL
        end
        return nothing
    end

    cache.s = s
    @inbounds for k in eachindex(cache.coeffs)
        cache.coeffs[k] = exp(H.s_weights[k] * s) * H.coeffs[k]
    end
    set_coefficients!(H.system, cache.views_coeffs)
    cache.active_coeffs == COEFFS_EVAL
    nothing
end

function update_coeffs_dt!(cache::PolyhedralHomotopyCache, H::PolyhedralHomotopy, s)
    if s == cache.ds
        if cache.active_coeffs != COEFFS_DT
            set_coefficients!(H.system, cache.views_coeffs_dt)
            cache.active_coeffs == COEFFS_DT
        end
        return nothing
    end

    if s == cache.s
        cache.ds = s
        @inbounds for k in eachindex(cache.coeffs)
            cache.coeffs_dt[k] = H.s_weights[k] * cache.coeffs[k]
        end
    else
        cache.ds = s
        @inbounds for k in eachindex(cache.coeffs)
            cache.coeffs_dt[k] = H.s_weights[k] * exp(H.s_weights[k] * s) * H.coeffs[k]
        end
    end
    set_coefficients!(H.system, cache.views_coeffs_dt)
    cache.active_coeffs == COEFFS_DT
    nothing
end


function evaluate!(u, H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs!(c, H, real(s))
    @inbounds evaluate!(u, H.system, x, c.system)
    u
end

function dt!(u, H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs_dt!(c, H, real(s))
    @inbounds evaluate!(u, H.system, x, c.system)
    u
end

function jacobian!(U, H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs!(c, H, real(s))
    @inbounds jacobian!(U, H.system, x, c.system)
end

function evaluate_and_jacobian!(u, U, H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs!(c, H, real(s))
    @inbounds evaluate_and_jacobian!(u, U, H.system, x, c.system)
    nothing
end

function evaluate(H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs!(c, H, real(s))
    evaluate(H.system, x, c.system)
end

function dt(H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs_dt!(c, H, real(s))
    evaluate(H.system, x, c.system)
end

function jacobian(H::PolyhedralHomotopy, x, s, c::PolyhedralHomotopyCache)
    update_coeffs!(c, H, real(s))
    jacobian(H.system, x, c.system)
end

(H::PolyhedralHomotopy)(x, t, c=cache(H, x, t)) = evaluate(H, x, t, c)
