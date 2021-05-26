# module CFunction
using MacroTools:splitarg, splitdef, combinedef

"""
    macro C(func::Expr)
Mark a function as a C style weakly-typed function, where arguments are automatically converted to function's argument types. 
Also, insert conversions to julia Bool type where it is required.
For exapmle,
```julia
@C function foo(a::int, b::float)::short
    return a ? a + b : b
end
```
will add a helper function `foo(a::Any, b::Any)` which automatically converts its arguments to the corresponding parameter type by calling `convert`:
```julia
function foo(a::int, b::float)::short
    return convert(Bool, a) ? a + b : b
end
function foo(a, b)
    a = convert(int, a)
    b = convert(float, b)
    return foo(a, b)
end
```
"""
macro C(func::Expr)
    def = splitdef(func)
    args = splitarg.(def[:args])

    argnames = [arg[1] for arg in args]
    funcname = def[:name]
    # TODO: vararg default argument promotion
    converters = map(args) do arg
        quote
            $(arg[1]) = convert($(arg[2]), $(arg[1]))
        end
    end
    apply = Expr(:call, funcname, argnames...)
    def[:body] = Expr(:block, converters..., apply)
    def[:args] = argnames
    convert_func = combinedef(def)
    original_func = insert_bool_conversion(func)

    return quote
        $(esc(original_func))
        $(esc(convert_func))
    end
end


function insert_bool_conversion(e::Expr)
    if e.head ∈ [:if, :elseif, :&&, :||]
        Expr(e.head, :(convert(Bool, $(e.args[1]))), insert_bool_conversion.(e.args[2:end])...)
    else
        Expr(e.head, insert_bool_conversion.(e.args)...)
    end
end

insert_bool_conversion(e) = e

# end