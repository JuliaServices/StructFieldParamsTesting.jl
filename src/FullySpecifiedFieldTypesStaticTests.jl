module FullySpecifiedFieldTypesStaticTests

export test_all_struct_fields_fully_specified, test_field_fully_specified

using MacroTools: @capture
using Test

function test_all_struct_fields_fully_specified(pkg::Module)
    dir = pkgdir(pkg)
    struct_obj = getfield(mod, struct_name)
    field_type_expr
end


function test_field_fully_specified(pkg::Module, struct_expr, field_name)
    @capture(
        struct_expr,
        struct name_{T__} <: S_
            fields__
        end | struct name_{T__}
            fields__
        end) || error("Invalid struct expression")

    dump(T)
    dump(fields)

    fields_dict = Dict{Symbol, Any}(_fieldname(e) => _fieldtype(e) for e in fields)
    field_type_expr = fields_dict[field_name]

    typevars = _make_typevar.((pkg,), T)
    dump(typevars)

    check_field_type_fully_specified(pkg, typevars, field_type_expr)
end
_fieldname(s::Symbol) = s
_fieldname(e::Expr) = e.args[1]
_fieldtype(s::Symbol) = :Any
_fieldtype(e::Expr) = e.args[2]

function check_field_type_fully_specified(mod::Module, typevars, field_type_expr)
    assignments = [:($(v.name) = $(v)) for v in typevars]
    # type_expr = _
    TypeObj = Base.eval(mod, quote
        let $(assignments...)
            $(field_type_expr)
        end
    end)
    @test TypeObj isa Type
end
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

end
