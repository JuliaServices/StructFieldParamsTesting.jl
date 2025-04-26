function test_all_fields_fully_specified(pkg::Module, struct_expr)
    (struct_name, T, fields_dict) = _extract_struct_field_types(pkg::Module, struct_expr)
    @testset "$struct_name" begin
        for (field_name, field_type_expr) in fields_dict
            check_field_type_fully_specified(pkg, struct_name, field_name, T,
                                            field_type_expr, report_error = true)
            @test true
        end
    end
end

function field_is_fully_specified(pkg::Module, struct_expr, field_name)
    (name, T, fields_dict) = _extract_struct_field_types(pkg::Module, struct_expr)
    field_type_expr = fields_dict[field_name]

    return check_field_type_fully_specified(
            pkg, name, field_name, T, field_type_expr,
            report_error = false)
end

function _extract_struct_field_types(pkg::Module, struct_expr)
    @capture(
        struct_expr,
        struct name_{T__} <: S_ fields__ end | struct name_ <: S_ fields__ end |
        struct name_{T__} fields__ end | struct name_ fields__ end
    ) || error("Invalid struct expression")

    T === nothing && (T = [])

    fields_dict = Dict{Symbol, Any}(_fieldname(e) => _fieldtype(e) for e in fields)
    return (name, T, fields_dict)
end
_fieldname(s::Symbol) = s
_fieldname(e::Expr) = e.args[1]
_fieldtype(::Symbol) = :Any
_fieldtype(e::Expr) = e.args[2]

function check_field_type_fully_specified(
    mod::Module, struct_name, field_name, typevars, field_type_expr;
    report_error,
)
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

    num_type_params = _count_unionall_parameters(TypeObj)
    num_expr_args = _count_type_expr_params(field_type_expr)
    # "Less than or equal to" in order to support literal values in the type expression.
    # E.g.: The UnionAll `Array{<:Int, 1}` has 1 type arg but 2 params in the expression.
    success = num_type_params <= num_expr_args
    if report_error
        @assert success field_type_not_complete_message(
            mod, struct_name, field_name, field_type_expr, TypeObj, num_type_params, num_expr_args
        )
    end
    return success
end

function field_type_not_complete_message(
    mod::Module, struct_name, field_name, field_type_expr, TypeObj,
    num_type_params, num_expr_args,
)
    # with_full_where = :($(field_type_expr) where {$(typevars...)})
    """
    In struct $(mod).$(struct_name), field `$(field_name)` does not have fully specified type:
        - `$(field_name)::$(field_type_expr)`

    The complete type should be `$(complete_type)`. The current definition only specifies \
    $(num_expr_args) type arguments, but the type `$(TypeObj)` expects $(num_type_args) \
    type parameters. This means the field has an abstract type (it is type unstable), and \
    any access to it will cause a dynamic dispatch.

    If this type instability is on purpose, please fully specify the omitted type \
    parameters. You can write that as `$(complete_type)`.

    If instead this was a mistake, possibly caused by a change that introduced new \
    parameters to the type, please make sure that your field is fully concrete, with all \
    parameters specified.
    """
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
