"""
    submodule CNumbers
Provides C-style numbers, whose conversion rule is different from julia's:
* Downcast to a smaller type is simply truncating, with no bounds check. (Although C11 6.3.1.3p3  permits throwing an InexactError, this may not be expected to C programmers)
* Integers promoted to int before performing arithmetic, possibly converted back later(C11 6.3 Conversions)
* Floating-point to integer conversion is plain `trunc`
Also it exports C-style lowercase type names like `float`, `int`, or `unsigned_int`.
"""

"""
    struct CNumber{T <: Number} <: Number
Wrapper of a C number, conforming to C-style integer/floating-point number conversion/arithmetic. Only intended for internal usage.
To get the wrapped value, call `value`.
"""
struct CNumber{T <: Number} <: Number
    v::T
end

"Get the wrapped value of a CNumber."
value(x::CNumber) = x.v

"Get the wrapped type of a CNumber."
basetype(::CNumber{T}) where T = T

"Integer rank is for comparing types. Defined on julia's primitive types."
function rank end

# Aliases

for (ind, (name, type)) in [
    (:bool, Bool),
    (:char, Cchar),
    (:unsigned_char, Cuchar),
    (:short, Cshort),
    (:unsigned_short, Cushort),
    (:int, Cint),
    (:unsigned_int, Cuint),
    (:long, Clong),
    (:unsigned_long, Culong),
    (:long_long, Clonglong),
    (:unsigned_long_long, Culonglong),
    (:float, Cfloat),
    (:double, Cdouble)] |> enumerate
    @eval begin
        const $name = CNumber{$type}
        # Avoid redefinition
        if !hasmethod(rank, Tuple{Type{$type}})
            rank(::Type{$type}) = $ind ÷ 2
        end
    end
end

# Convert to normal julia types (outer constructor is not defined)
Base.convert(::Type{T}, x::CNumber) where {T <: Number} = Base.convert(T, value(x))
# Convert between integer types by truncating
Base.convert(::Type{CNumber{T}}, x::CNumber{<:Integer}) where {T <: Integer} = CNumber{T}(value(x) % T)
# Convert to floating point number by direct julian conversion
Base.convert(::Type{CNumber{T}}, x::CNumber) where {T <: AbstractFloat} = CNumber{T}(Base.convert(T, value(x)))
# Convert from floating point number to integer by truncating
Base.convert(::Type{CNumber{T}}, x::CNumber{<:AbstractFloat}) where {T <: Integer} = CNumber{T}(trunc(value(x)))
# Convert to bool is !iszero
Base.convert(::Type{Bool}, x::CNumber) = !iszero(value(x))
Base.convert(::Type{bool}, x::CNumber) = bool(Base.convert(Bool, x))


"Integers with rank smaller than int are promoted to int"
promote_integer(::Type{T}) where T = rank(T) ≥ rank(Cint) ? T : Cint

signedness(::Type{<:Signed}) = true
signedness(::Type{<:Unsigned}) = false

function c_promote(::Type{T1}, ::Type{T2}) where {T1 <: AbstractFloat,T2}
    return promote_type(T1, T2)
end

function c_promote(::Type{T1}, ::Type{T2}) where {T1,T2 <: AbstractFloat}
    return promote_type(T1, T2)
end

function c_promote(::Type{T1}, ::Type{T2}) where {T1,T2}
    T3, T4 = promote_integer(T1), promote_integer(T2)
    if !(signedness(T3) ⊻ signedness(T4))
        return rank(T3) > rank(T4) ? T3 : T4
    elseif T3 <: Unsigned
        U, S = T3, T4
    else
        U, S = T4, T3
    end

    if rank(U) ≥ rank(S)
        return U
    elseif sizeof(U) < sizeof(S)
        return S
    else
        return U
    end
end


function Base.promote_rule(::Type{CNumber{T1}}, ::Type{CNumber{T2}}) where {T1,T2}
    return CNumber{c_promote(T1, T2)}
end

# Always favor CNumber over julian nubers
function Base.promote_rule(::Type{CNumber{T1}}, ::Type{T2}) where {T1, T2}
    Base.promote_rule(CNumber{T1}, CNumber{T2})
end

# Arithmetic

for op in [:+, :-, :*, :/, :%, :&, :|, :⊻, :<<, :>>] # XOR is ⊻ in julia
    @eval function Base.$op(a::CNumber{T}, b::CNumber{T}) where T
        CNumber{T}($op(value(a), value(b)))
    end
end

for op in [:+, :-, :~]
    @eval function Base.$op(a::CNumber{T}) where T
        CNumber{T}($op(value(a)))
    end
end

# Return Bool
for op in [:(==), :!=, :<, :>, :<=, :(>=)]
    @eval function Base.$op(a::CNumber, b::CNumber)
        a, b = Base.promote(a, b)
        Base.$op(value(a), value(b))
    end
end

function Base.:!(a::CNumber)
    iszero(a)
end

"@post_inc i is equivalent to i++"
macro post_inc(i)
	quote
		local v = $(esc(i))
		$(esc(i)) += 1
		v
	end
end

"@post_dec i is equivalent to i--"
macro post_dec(i)
	quote
		local v = $(esc(i))
		$(esc(i)) -= 1
		v
	end
end
