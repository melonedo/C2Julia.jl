
"""
    macro pointer(e::Expr)
Turn `A.B` and `A[B]` into corresponding reference.
"""
macro pointer(e::Expr)
    if e.head == :. # A.B
        A, B = e.args
        :(FieldRef($(esc(A)), $(esc(B))))
    elseif e.head == :ref # A[B]
        A, B = e.args
        :($(esc(A)) + $(esc(B)))
    else
        @error "Can not turn expression $e into pointer expression."
    end
end

"Reference to a field of a struct."
struct FieldRef{T, FieldVal, ObjType}
    obj::ObjType
end

FieldRef(obj::ObjType, field::Symbol) where ObjType = FieldRef{fieldtype(ObjType, field), Val{field}, ObjType}(obj)
Base.getindex(r::FieldRef{T, Val{field}}) where {T, field} = Base.getproperty(r.obj, field)
Base.setindex!(r::FieldRef{T, Val{field}}, v) where {T, field} = Base.setproperty!(r.obj, field, v)

"Temporarily hold the result of a malloc, converted to a pointer when assigned."
struct MallocWrapper
    size::Int
    calloc::Bool
end

malloc(size) = MallocWrapper(size, false)
calloc(size) = MallocWrapper(size, true)
free(_) = nothing


"Manage an array but appears as a pointer."
struct ArrayPointer{T}
    vec::Vector{T} # note: julia `Array` is mutable, this involves one more level of indirection, which is bad for performance
    offset::Int
end

"All representations of a pointer."
const Pointer{T} = Union{FieldRef{T}, ArrayPointer{T}}
Base.convert(::Type{Pointer{T}}, m::MallocWrapper) where T = materialize_malloc(T, m)

function Base.cconvert(::Type{Ref{T}}, p::ArrayPointer{T}) where T
    pointer(getarray(p), getoffset(p))
end

function Base.unsafe_convert(::Type{Ref{T}}, p::FieldRef{T, field, ObjType}) where {T, field, ObjType}
    pointer_from_objref(p.obj) + fieldoffset(ObjType, field)
end

# Maybe this could rule them all?
# struct GCPointer{T}
#     ptr::Ptr{T}
#     obj::Any # GC reference
#     GCPointer{T}(p::FieldRef{T, Val{field}}) where {T, field} = new(pointer_from_objref(p.obj) + fieldoffset(T, field), p.obj)
#     GCPointer{T}(p::ArrayPointer{T}) where T = new(pointer(getarray(p), getoffset(p)), getarray(p))
# end
# Base.unsafe_convert(::Type{Ptr}, p::GCPointer) = p.ptr

"Convert wrapper into a pointer."
function materialize_malloc(::Type{T}, m::MallocWrapper) where T
    len, rem = divrem(m.size, sizeof(T))
    rem == 0 || @error "Malloc'ed size $(m.size) is not a multiple of size of $T (=$(sizeof(T)))"
    # if len > 1
    #     alloc_array(T, len, m.calloc)
    # elseif m.calloc
    #     Ref{T}(0)
    # else
    #     Ref{T}()
    # end
    alloc_array(T, len, m.calloc)
end

### Pointer arithmetic ###
const IndexBase = 0 # 0-based. Why not? Julia internally subtracts indices by one.

# Native methods
alloc_array(T, len, init::Bool) = ArrayPointer{T}(Vector{T}(undef, len), IndexBase)
# calloc_array(T, len) = ArrayPointer{T}(Vector{T}(0, len), 0)

getarray(p::ArrayPointer) = Base.getfield(p, :vec)
# Turn 0-based to 1-based, julia is clever enough to know i+1-1 = i
getoffset(p::ArrayPointer) = Base.getfield(p, :offset) + 1 - IndexBase

# is @inbounds needed here?
getvalue(p::ArrayPointer) = Base.getindex(getarray(p), getoffset(p))
setvalue!(p::ArrayPointer, v) = Base.setindex!(getarray(p), v, getoffset(p))

offsetby(p::ArrayPointer{T}, i::Number) where {T} = ArrayPointer{T}(getarray(p), Base.getfield(p, :offset) + i)

# Pointer arithmetic
Base.:+(p::ArrayPointer, i::Number) = offsetby(p, i)
Base.:+(i::Number, p::ArrayPointer) = p + i
Base.:-(p::ArrayPointer, i::Number) = offsetby(p, -i)
# Base.:-(i::Number, p::ArrayPointer) = offset(p, -i) # No such thing

# Array-like indexing, i.e., p[i] and p[i] = v
Base.getindex(p::ArrayPointer, i) = getvalue(p + i)
Base.setindex!(p::ArrayPointer, v, i) = setvalue!(p + i, v)

# Explicit dereferencing, i.e., *p is mapped to p[]
Base.getindex(p::ArrayPointer) = getvalue(p)
Base.setindex!(p::ArrayPointer, v) = setvalue!(p, v)

# ptr->attr is translated to ptr.attr, without dereferencing explicitly
Base.getproperty(p::ArrayPointer, s::Symbol) = getproperty(getvalue(p), s)
# Make sure T is mutable!
Base.setproperty!(p::ArrayPointer{T}, s::Symbol, v::T) where {T} = setproperty!(getvalue(p), s, v)
# Function Pointer
(p::ArrayPointer)(args...) = getvalue(p)(args...)