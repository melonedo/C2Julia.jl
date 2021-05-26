using Test
using C2Julia
using C2Julia:value
const float = C2Julia.float

@testset "CNumber type promotion" begin
    @test promote_type(int, char) == int
    @test promote_type(char, unsigned_char) == int
    @test promote_type(unsigned_int, long) == unsigned_int
    @test promote_type(long_long, float) == float
end

@testset "CNumber type conversion" begin
    @test convert(int, float(3)) |> value == 3
    @test convert(float, int(3)) |> value == 3
    @test convert(long, double(1e9)) |> value == 1e9
    @test convert(unsigned_char, int(1000)) |> value == 1000 % Cuchar
    @test convert(Cint, int(2000)) == 2000
    @test convert(float, int(2000)) == 2000
end