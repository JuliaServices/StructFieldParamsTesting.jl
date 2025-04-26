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

    # typevars = _make_typevar.((pkg,), T)

    return check_field_type_fully_specified(pkg, T, field_type_expr)
end
_fieldname(s::Symbol) = s
_fieldname(e::Expr) = e.args[1]
_fieldtype(::Symbol) = :Any
_fieldtype(e::Expr) = e.args[2]

function check_field_type_fully_specified(mod::Module, typevars, field_type_expr)
    print("TypeVars: ")
    dump(typevars)
    TypeObj = Base.eval(mod, quote
        $(field_type_expr) where {$(typevars...)}
    end)
    @show TypeObj
    @assert TypeObj isa Type

    if isconcretetype(TypeObj)
        # The type is concrete, so it is fully specified.
        @info "Type is concrete: $(TypeObj)"
        return true
    end
    @assert typeof(TypeObj) === UnionAll "$(TypeObj) is not a UnionAll. Got $(typeof(TypeObj))."

    return check_unionall_expr_is_fully_specified(mod, TypeObj, field_type_expr)
end

function check_unionall_expr_is_fully_specified(mod::Module, TypeObj::UnionAll, expr)
    num_type_args = _count_unionall_parameters(TypeObj)
    num_params = _count_type_expr_params(expr)
    dump(expr)
    @show num_type_args, num_params
    # "Less than or equal to" in order to support literal values in the type expression.
    # E.g.: The UnionAll `Array{<:Int, 1}` has 1 type arg but 2 params in the expression.
    return num_type_args <= num_params
end
function _count_unionall_parameters(TypeObj::UnionAll)
    count = 0
    while typeof(TypeObj) === UnionAll
        count += 1
        TypeObj = TypeObj.body
    end
    return count
end
_count_type_expr_params(s::Symbol) = 0
function _count_type_expr_params(expr::Expr)
    count = 0
    while expr.head === :where
        count += length(expr.args) - 1
        expr = expr.args[1]
    end
    if expr.head == :curly
        count += length(expr.args) - 1
    end
    return count
end


end  # module FullySpecifiedFieldTypesStaticTests
