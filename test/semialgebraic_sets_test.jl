@testset "SemialgebraicSets" begin
    solver = SemialgebraicSetsHCSolver(; compile = false)
    @polyvar x y
    V = SemialgebraicSets.@set x^2 == 1 && y^2 == 2 solver
    S = collect(V)
    S = sort!(map(s -> round.(s, digits = 2), S))
    @test S == [[-1.0, -1.41], [-1.0, 1.41], [1.0, -1.41], [1.0, 1.41]]

    # Inspired from https://jump.dev/SumOfSquares.jl/v0.4.6/generated/Polynomial%20Optimization/
    function f(ε, tol)
        solver = SemialgebraicSetsHCSolver(; excess_residual_tol = tol, real_tol = tol, compile = false)
        @test sprint(show, solver) == "SemialgebraicSetsHCSolver(; excess_residual_tol = $tol, real_tol = $tol, compile = false)"
        o = 1 + ε
        V = SemialgebraicSets.algebraicset([
            -x - y + o,
            -o * x*y + o * y^2 - y,
            -o * x^2 + y^2 - 2y + o],
            solver,
        )
        S = collect(V)
        S = sort!(map(s -> round.(s, digits = 2), S))
        @test length(S) == 2
        @test S[1] ≈ [0.0, 1.0] atol=ε
        @test S[2] ≈ [1.0, 0.0] atol=ε
    end
    f(1e-5, 1e-5)
    f(1e-4, 1e-3)
    f(1e-3, 1e-3)
    f(1e-2, 1e-1)
end
