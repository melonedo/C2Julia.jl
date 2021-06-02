using Base
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
    @test convert(int, float(3)) === int(3)
    @test convert(int, float(3)) == 3
    @test convert(float, int(3)) === float(3)
    @test convert(float, int(3)) == 3
    @test convert(long, double(1e9)) |> value == 1e9
    @test convert(unsigned_char, int(1000)) |> value == 1000 % Cuchar
    @test convert(Cint, int(2000)) == 2000
    @test convert(Float32, int(2000)) == 2000
end

@testset "CFunction" begin
    @C function foo(a::int, b::float)::int
        return @bool(a) ? a + b : b
    end
    @test foo(2, 2) === int(4)
    @test foo(3, 2) === int(5)
    @test foo(0, 2) === int(2)
end

mutable struct S1
    a::int
    b::double
end

@testset "@pointer" begin
    s = S1(2, 3)
    @test @pointer(s.a)[] == 2
    a::Pointer{int} = C2Julia.malloc(sizeof(int) * 2)
    a[] = 1
    a[1] = 2
    @test @pointer(a[0])[] == 1
    @test @pointer(a[1])[] == 2
end

@testset "FieldRef" begin
    function add_one(x)
        @post_inc x[]
    end
    x = int(123)
    s = S1(x, 2.3)
    @test s.a == x
    add_one(@pointer s.a)
    @test s.a == x + 1
end

@testset "Postfix operators" begin
    orig = 234
    x::int = orig
    y::int = @post_dec x
    @test y == orig
    @test x == orig - 1
end