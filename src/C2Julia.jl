module C2Julia
using Base: Base
include("CNumbers.jl")
# `float` is also exported, which conflicts with `Base.float`. Resolve it with `const float = C2Julia.float`
export bool, char, unsigned_char, short, unsigned_short, int, unsigned_int, long, unsigned_long, long_long, unsigned_long_long, float, double

include("CFunction.jl")
export @C

end # module
