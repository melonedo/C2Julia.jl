module stdlib
using Base: RefValue
using C2Julia: CNumber
export printf, scanf, sprintf, snprintf, sscanf

to_c_type(x) = x
to_c_type(::Type{CNumber{T}}) where T = T
# to_c_type(::Type{Pointer{T}}) where T = Ref{T}
to_c_type(::Type{<:AbstractString}) = Cstring
to_c_type(::Type{Vector{T}}) where T = Ref{T}
to_c_type(::Type{RefValue{T}}) where T = Ref{T} # Ref{Int} is actually RefValue{Int}

@generated function ccall_vararg(::Val{name}, fix_args, var_args, ::Type{rettype}) where {name,rettype}
    counter = Iterators.countfrom(1)
    fix_arg_pairs = map(counter, to_c_type.(fieldtypes(fix_args))) do ind, type
        :(fix_args[$ind]::$type)
    end
    var_arg_pairs = map(counter, to_c_type.(fieldtypes(var_args))) do ind, type
        :(var_args[$ind]::$type)
    end
    quote
        @ccall $name($(fix_arg_pairs...); $(var_arg_pairs...))::$rettype
    end
end

printf(format, args...) = ccall_vararg(Val(:printf), (format,), args, Cint)
scanf(format, args...) = ccall_vararg(Val(:scanf), (format,), args, Cint)
sprintf(buf, format, args...) = ccall_vararg(Val(:sprintf), (buf, format), args, Cint)
sscanf(buf, format, args...) = ccall_vararg(Val(:sscanf), (buf, format), args, Cint)
# C99, but julia source is only C89
# snprintf(buf, length, format, args...) = ccall_vararg(Val(:snprintf), (buf, length, format), args, Cint)

end