function test_all_fields_fully_specified(pkg::Module, struct_expr; location = nothing)
    (struct_name, T, fields_dict) = _extract_struct_field_types(pkg::Module, struct_expr)
    @testset "$struct_name" begin
        for (field_name, field_type_expr) in fields_dict
            check_field_type_fully_specified(pkg, struct_name, field_name, T,
                                            field_type_expr,
                                            report_error = true, location = location)
            @test true
        end
    end
end

function field_is_fully_specified(pkg::Module, struct_expr, field_name; location = nothing)
    (name, T, fields_dict) = _extract_struct_field_types(pkg::Module, struct_expr)
    field_type_expr = fields_dict[field_name]

    return check_field_type_fully_specified(
            pkg, name, field_name, T, field_type_expr,
            report_error = false, location = location)
end

function _extract_struct_field_types(pkg::Module, struct_expr)
    @capture(
        struct_expr,
        struct name_{T__} <: S_ fields__ end | struct name_ <: S_ fields__ end |
        struct name_{T__} fields__ end | struct name_ fields__ end |
        mutable struct name_{T__} <: S_ fields__ end | mutable struct name_ <: S_ fields__ end |
        mutable struct name_{T__} fields__ end | mutable struct name_ fields__ end
    ) || error("Invalid struct expression: $(struct_expr)")

    T === nothing && (T = [])

    fields_split = split_field.(fields)
    filter!(x -> x !== nothing, fields_split)
    fields_dict = Dict{Symbol, Any}(fields_split)
    return (name, T, fields_dict)
end
function split_field(e)
    @capture(e, n_::T_ | n_) || return nothing
    n isa Symbol || return nothing
    T === nothing && (T = Any)
    return (n, T)
end

function check_field_type_fully_specified(
    mod::Module, struct_name, field_name, typevars, field_type_expr;
    report_error, location,
)
    @debug "Module:" mod
    @debug "TypeVars:" typevars
    TypeObj = Base.eval(mod, quote
        $(field_type_expr) where {$(typevars...)}
    end)
    @debug "Type:" TypeObj
    @assert TypeObj isa Type

    if isconcretetype(TypeObj)
        # The type is concrete, so it is fully specified.
        @debug "Type is concrete: $(TypeObj)"
        return true
    end
    if typeof(TypeObj) == DataType
        # The type is a DataType, so it is fully specified.
        # Presumably, it is an abstract type like `Number` or `Any`
        @debug "Type is a DataType: $(TypeObj)"
        return true
    end
    if typeof(TypeObj) == Union
        # TODO: Handle every branch of the union.
        #     For now, just skip these fields.
        return true
    end
    if TypeObj == Type
        # TODO: FOR NOW, to avoid noisy result
        return true
    end
    @assert typeof(TypeObj) === UnionAll "$(TypeObj) is not a UnionAll. Got $(typeof(TypeObj))."

    num_type_params = _count_unionall_free_parameters(TypeObj)
    num_expr_args = _count_type_expr_params(mod, field_type_expr)
    # "Less than or equal to" in order to support fully constrained parameters in the expr.
    # E.g.: `Vector{T} where T<:Int` has 0 free type params but 1 param in the expression.
    success = num_type_params <= num_expr_args
    if !success && report_error
        throw(FieldTypeIncompleteException(
            mod, struct_name, field_name, field_type_expr, TypeObj, num_type_params,
            num_expr_args, location,
        ))
    end
    return success
end

# TODO: What do we actually want to do for alias types?
# E.g.
#   IterableResult{K} = Union{Vector{K}, BeTreeV2_Typed{K}}
# which unwraps to
#   Union{Array{K, 1}, BeTreeV2_Typed{K, V, E, KNorm, VNorm, TD}}
# I think this is a reason to separate "fully-specified" from "concrete".
# And to be fully-specified this requires exactly 1 type param (for K).
recurise_unwrap_unionall(@nospecialize(T)) = Base.unwrap_unionall(T)
recurise_unwrap_unionall(T::UnionAll) = recurise_unwrap_unionall(Base.unwrap_unionall(T))
recurise_unwrap_unionall(T::Union) = Union{recurise_unwrap_unionall(T.a), recurise_unwrap_unionall(T.b)}

struct FieldTypeIncompleteException <: Exception
    mod::Module
    struct_name::Symbol
    field_name::Symbol
    field_type_expr::Any
    TypeObj::Type
    num_type_params::Int
    num_expr_args::Int
    location::Union{Nothing, String}
end
function Base.showerror(io::IO, ex::FieldTypeIncompleteException)
    msg = field_type_not_complete_message(
        ex.mod, ex.struct_name, ex.field_name, ex.field_type_expr, ex.TypeObj,
        ex.num_type_params, ex.num_expr_args, ex.location,
    )
    print(io, msg)
end

function field_type_not_complete_message(
    mod::Module, struct_name, field_name, field_type_expr, TypeObj,
    num_type_params, num_expr_args, location,
)
    # io = IOBuffer()
    # show(IOContext(io, :compact=>false), TypeObj)
    # complete_type = String(take!(io))
    typename = TypeObj isa DataType ? nameof(TypeObj) : string(TypeObj)
    typevars = join(["T$i" for i in 1:(num_type_params - num_expr_args)], ", ")
    typestr = "$(field_type_expr)"
    @debug "Type string:" typestr
    if occursin("}", typestr)
        typestr = replace(typestr, "}" => ", $(typevars)}")
    else
        typestr = "$(typestr){$(typevars)}"
    end
    # complete_type = "$(typestr) where {$(typevars)}"
    complete_type = recurise_unwrap_unionall(TypeObj)
    """
    In struct `$(mod).$(struct_name)`, the field `$(field_name)` does not have a fully \
    specified type:
      - `$(field_name)::$(field_type_expr)`

    Defined at line:
        $(location)

    The complete type is `$(complete_type)`, which expects $(num_type_params) type \
    parameter(s), but the current definition `$(field_type_expr)` specifies only \
    $(num_expr_args) type arguments. This means the struct's field currently has an \
    abstract type (it is type unstable), and any access to it will cause a dynamic dispatch.

    If this was a mistake, possibly caused by a change to the `$(typename)` type that \
    introduced new parameters to it, please make sure that your field `$(field_name)` is \
    fully concrete, with all parameters specified.

    If, instead, this type instability is on purpose, please fully specify the omitted \
    type parameters to silence this message. You can write that as `$(complete_type)`, or \
    possibly in a shorter alias form which this message can't always detect. (E.g. you can \
    write `Vector{T} where T` instead of `Array{T, 1} where T`.)
    """
end

_count_unionall_free_parameters(@nospecialize(::Any)) = 0
function _count_unionall_free_parameters(TypeObj::UnionAll)
    count = 0
    while typeof(TypeObj) === UnionAll
        # in `T<:ConcreteType` we don't consider `T` as a free parameter
        count += !isconcretetype(TypeObj.var.ub)
        TypeObj = TypeObj.body
    end
    # The parameters might themselves be `UnionAll`
    for param in TypeObj.parameters
        count += _count_unionall_free_parameters(param)
    end
    return count
end

_count_type_expr_params(mod::Module, @nospecialize(x)) = 0
_count_type_expr_params(mod::Module, s::Symbol) = Int(!isdefined(mod, s))
function _count_type_expr_params(mod::Module, expr::Expr)
    count = 0
    if expr.head === :where
        expr = expr.args[1]
        count = _count_type_expr_params(mod, expr)
    elseif expr.head == :curly
        count += sum(_count_type_expr_params(mod, arg) for arg in expr.args)
    end
    return count
end
