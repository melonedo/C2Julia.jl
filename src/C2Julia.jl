module C2Julia
include("CNumbers.jl")
# `float` is also exported, which conflicts with `Base.float`. Resolve it with `const float = C2Julia.float`
export bool, char, unsigned_char, short, unsigned_short, int, unsigned_int, long, unsigned_long, long_long, unsigned_long_long, float, double
export @post_inc, @post_dec

include("CFunction.jl")
export @C, @bool, @cfor

include("CPointer.jl")
export @pointer, Pointer, malloc, free

# Export Base symbols
export +, -, *, /, %, &, |, ⊻, <<, >>, ~, !
export <, >, <=, >=, ==, !=
export sizeof

include("stdlib.jl")

end # module
