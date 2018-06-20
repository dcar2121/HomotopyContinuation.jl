function testevaluations(H, x)
    m, n = size(H)
    t = rand()
    u = zeros(Complex{Float64}, m)
    U = zeros(Complex{Float64}, m, n)

    cache = Homotopies.cache(H, x, t)

    Homotopies.evaluate!(u, H, x, t, cache)
    @test Homotopies.evaluate(H, x, t, cache) == u
    @test Homotopies.evaluate(H, x, t) == u

    Homotopies.dt!(u, H, x, t, cache)
    @test Homotopies.dt(H, x, t, cache) == u
    @test Homotopies.dt(H, x, t) == u

    Homotopies.jacobian!(U, H, x, t, cache)
    @test Homotopies.jacobian(H, x, t, cache) == U
    @test Homotopies.jacobian(H, x, t) == U

    Homotopies.evaluate_and_jacobian!(u, U, H, x, t, cache)
    @test Homotopies.evaluate_and_jacobian(H, x, t, cache) == (u, U)
    @test (u, U) == (Homotopies.evaluate(H, x, t), Homotopies.jacobian(H, x, t))

    Homotopies.jacobian_and_dt!(U, u, H, x, t, cache)
    @test Homotopies.jacobian_and_dt(H, x, t, cache) == (U, u)
    @test (U, u) == (Homotopies.jacobian(H, x, t), Homotopies.dt(H, x, t))
end

@testset "Homotopies.StraightLineHomotopy" begin
    F = Systems.SPSystem(equations(katsura(5)))
    G = Systems.SPSystem(equations(cyclic(6)))
    H = Homotopies.StraightLineHomotopy(F, G)
    @test H isa Homotopies.AbstractHomotopy
    @test size(H) == (6, 6)


    testevaluations(H, rand(Complex{Float64}, 6))
end

@testset "Homotopies.HomotopyWithCache" begin
    x = rand(Complex{Float64}, 6)
    t = rand()
    F = Systems.SPSystem(equations(katsura(5)))
    G = Systems.SPSystem(equations(cyclic(6)))
    H = Homotopies.HomotopyWithCache(Homotopies.StraightLineHomotopy(F, G), x, t)
    @test H isa Homotopies.AbstractHomotopy
    @test size(H) == (6, 6)

    m, n = size(H)
    u = zeros(Complex{Float64}, m)
    U = zeros(Complex{Float64}, m, n)

    Homotopies.evaluate!(u, H, x, t)
    @test Homotopies.evaluate(H, x, t) == u

    Homotopies.dt!(u, H, x, t)
    @test Homotopies.dt(H, x, t) == u

    Homotopies.jacobian!(U, H, x, t)
    @test Homotopies.jacobian(H, x, t) == U

    Homotopies.evaluate_and_jacobian!(u, U, H, x, t)
    @test Homotopies.evaluate_and_jacobian(H, x, t) == (u, U)
    @test (u, U) == (Homotopies.evaluate(H, x, t), Homotopies.jacobian(H, x, t))

    Homotopies.jacobian_and_dt!(U, u, H, x, t)
    @test Homotopies.jacobian_and_dt(H, x, t) == (U, u)
    @test (U, u) == (Homotopies.jacobian(H, x, t), Homotopies.dt(H, x, t))
end

@testset "Homotopies.ParameterHomotopy" begin
    F = Systems.FPSystem(equations(katsura(5)))
    parameters = [5, 6]
    H = Homotopies.ParameterHomotopy(F, parameters, rand(2), rand(2))
    @test H isa Homotopies.AbstractHomotopy
    @test size(H) == (6, 4)
    @test gamma(H) isa Complex128
    @test Homotopies.γ(H) isa Complex128


    testevaluations(H, rand(Complex{Float64}, 4))
end

@testset "Homotopies.FixedPointHomotopy" begin
    F = Systems.SPSystem(equations(katsura(5)))
    H = Homotopies.FixedPointHomotopy(F, rand(Complex128, 6))
    @test H isa Homotopies.AbstractHomotopy
    @test size(H) == (6, 6)

    testevaluations(H, rand(Complex{Float64}, 6))
end

@testset "Homotopies.PatchedHomotopy" begin
    F = Systems.SPSystem(equations(katsura(5)))
    G = Systems.SPSystem(equations(cyclic(6)))
    x = ProjectiveVectors.PVector(rand(Complex{Float64}, 6), 1)
    H = Homotopies.PatchedHomotopy(Homotopies.StraightLineHomotopy(F, G),
        AffinePatches.OrthogonalPatch(),
        x)
    @test H isa Homotopies.AbstractHomotopy
    @test size(H) == (7, 6)

    testevaluations(H, x)
end