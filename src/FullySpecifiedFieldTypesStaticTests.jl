module FullySpecifiedFieldTypesStaticTests

export test_all_struct_fields_fully_specified, field_is_fully_specified

using MacroTools: @capture
using Test

function test_all_struct_fields_fully_specified(pkg::Module)
    dir = pkgdir(pkg)
    struct_obj = getfield(mod, struct_name)
    field_type_expr
end


function field_is_fully_specified(pkg::Module, struct_expr, field_name)
    @capture(
        struct_expr,
        struct name_{T__} <: S_ fields__ end | struct name_{T__} fields__ end |
        struct name_ fields__ end | struct name_ <: S_ fields__ end) ||
            error("Invalid struct expression")

    # dump(T)
    # dump(fields)
    T === nothing && (T = [])

    fields_dict = Dict{Symbol, Any}(_fieldname(e) => _fieldtype(e) for e in fields)
    field_type_expr = fields_dict[field_name]

    typevars = _make_typevar.((pkg,), T)

    return check_field_type_fully_specified(pkg, typevars, field_type_expr)
end
_fieldname(s::Symbol) = s
_fieldname(e::Expr) = e.args[1]
_fieldtype(s::Symbol) = :Any
_fieldtype(e::Expr) = e.args[2]

function _make_typevar(mod, Texpr)
    # NOTE: Julia currently doesn't allow `B_ >: T_ >: A_`.
    # @show(Texpr)
    @capture(Texpr, (A_ <: T_ <: B_) | (T_ <: B_) | (T_ >: A_) | T_) ||
        error("Invalid type expression: $(Texpr)")
    A === nothing && (A = Union{})
    B === nothing && (A = Any)
    A = Base.eval(mod, A)
    B = Base.eval(mod, B)
    return TypeVar(T, A, B)
end

function check_field_type_fully_specified(mod::Module, typevars, field_type_expr)
    # dump(typevars)
    # NOTE: Julia doesn't seem to produce the right type if you use a concrete typevar.
    # Example:
    # let T = TypeVar(:T, Union{}, Int)
    #     t = Vector{T}
    #     println(typeof(t))   # DataType
    #     println(Int[] isa t) # false
    # end
    # So it seems we are forced to extract the concrete type itself in such scenarios.
    type_or_var(t) = isconcretetype(t.ub) ? t.ub : t
    assignments = [:($(v.name) = $(type_or_var(v))) for v in typevars]
    # type_expr = _
    TypeObj = Base.eval(mod, quote
        let $(assignments...)
            $(field_type_expr)
        end
    end)
    # @show TypeObj
    # @test TypeObj isa Type
    @assert TypeObj isa Type

    if isconcretetype(TypeObj)
        # The type is concrete, so it is fully specified.
        # @info "Type is concrete: $(TypeObj)"
        return true
    end
    @assert typeof(TypeObj) === UnionAll "$(TypeObj) is not a UnionAll. Got $(typeof(TypeObj))."

    return check_unionall_expr_is_fully_specified(mod, TypeObj, field_type_expr)
end

function check_unionall_expr_is_fully_specified(mod::Module, TypeObj::UnionAll, expr::Expr)
    num_type_args = _count_unionall_parameters(TypeObj)
    num_params = _count_type_expr_params(expr)
    # dump(expr)
    # @show num_type_args, num_params
    return num_type_args == num_params
end
function _count_unionall_parameters(TypeObj::UnionAll)
    count = 0
    while typeof(TypeObj) === UnionAll
        count += 1
        TypeObj = TypeObj.body
    end
    return count
end
function _count_type_expr_params(expr::Expr)
    if expr.head !== :curly
        return 0
    end
    return length(expr.args) - 1
end


end  # module FullySpecifiedFieldTypesStaticTests
