
@testitem "check field tests" begin

    # Concrete DataType
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Int end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Vector{Int} end),
        :x,
    )
    # Fully specified field type (DataType)
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T<:Int} x::Vector{T} end),
        :x,
    )

    # Fully specified UnionAll field type
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Vector{<:Int} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Array{<:Int, 1} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Array{Int, 1} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1,T2} x::Vector{Int} end),
        :x,
    )

    # Proper type arguments
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T} x::Vector{T} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1,T2} x::Dict{T1,T2} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T0,T1,T2} x::Dict{T1,T2} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1} x::Dict{T1,Int} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T2} x::Dict{Int,T2} end),
        :x,
    )
    # where-clause on the field
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1} x::Dict{T1, T2} where {T2<:Int} end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1} x::Dict{T1,T2} where T2 end),
        :x,
    )

    # False cases:
    @test false == field_is_fully_specified(
        @__MODULE__,
        :(struct S{T1} x::Dict{T1} end),
        :x,
    )
    @test false == field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Dict end),
        :x,
    )
    @test false == field_is_fully_specified(
        @__MODULE__,
        :(struct S{T} x::Dict end),
        :x,
    )

    # Not applicable (abstract type or no type at all):
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Any end),
        :x,
    )
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x::Number end),
        :x,
    )
    # TODO: Should this complain also? I don't think so.
    #     - Maybe an option to have it complain?
    @test field_is_fully_specified(
        @__MODULE__,
        :(struct S x end),
        :x,
    )
end

@testitem "all fields" begin
    test_all_fields_fully_specified(@__MODULE__,
        :(struct S{T}
            x::Vector{T}
            y::Vector{T}
        end))

    test_all_fields_fully_specified(@__MODULE__,
        :(struct S{T}
            x::Vector{T}
            y::Vector{T}
        end))
end

@testitem "all fields failures" begin
    function test_failure(f, msgs)
        # HACK: Hide the active testset from Test.jl, so that it cannot register
        # the tests failures with the outer testset.
        failed = false
        e = task_local_storage(:__BASETESTNEXT__, Test.AbstractTestSet[]) do
            try
                f()
            catch e;
                failed = true
                e
            end
        end
        @test failed
        @test length(e.errors_and_fails) == length(msgs)
        for (i,expected_msg) in enumerate(msgs)
            msg = e.errors_and_fails[i].value
            @assert startswith(msg, "AssertionError(\"")
            msg = msg[17:end-2]
            msg = Base.unescape_string(msg)
            @test msg == expected_msg
        end
    end
    # ---

    test_failure([
        """
        In struct `$(@__MODULE__).S`, the field `y` does not have a fully specified type:
          - `y::Vector`

        The complete type is `Vector{T1} where {T1}`. The current definition specifies 0 \
        type arguments, but the type `Vector{T1} where {T1}` expects 1 type parameter(s). \
        This means the struct's field currently has an abstract type (it is type \
        unstable), and any access to it will cause a dynamic dispatch.

        If this was a mistake, possibly caused by a change to the `Array` type that \
        introduced new parameters to it, please make sure that your field `y` is fully \
        concrete, with all parameters specified.

        If, instead, this type instability is on purpose, please fully specify the omitted \
        type parameters to silence this message. You can write that as `Vector{T1} where \
        {T1}`, or possibly in a shorter alias form which this message can't always detect. \
        (E.g. you can write `Vector{T} where T` instead of `Array{T, 1} where T`.)
        """
    ]) do
        test_all_fields_fully_specified(@__MODULE__,
            :(struct S{T}
                x::Vector{T}
                y::Vector
            end))
    end

    test_failure([
        """
        In struct `$(@__MODULE__).S`, the field `d` does not have a fully specified type:
          - `d::Dict`

        The complete type is `Dict{T1, T2} where {T1, T2}`. The current definition \
        specifies 0 type arguments, but the type `Dict{T1, T2} where {T1, T2}` expects 2 \
        type parameter(s). This means the struct's field currently has an abstract type \
        (it is type unstable), and any access to it will cause a dynamic dispatch.

        If this was a mistake, possibly caused by a change to the `Dict` type that \
        introduced new parameters to it, please make sure that your field `d` is fully \
        concrete, with all parameters specified.

        If, instead, this type instability is on purpose, please fully specify the omitted \
        type parameters to silence this message. You can write that as `Dict{T1, T2} where \
        {T1, T2}`, or possibly in a shorter alias form which this message can't always \
        detect. (E.g. you can write `Vector{T} where T` instead of `Array{T, 1} where T`.)
        """
    ]) do
        test_all_fields_fully_specified(@__MODULE__,
            :(struct S{T}
                a::Int
                d::Dict
                y::Vector{T}
            end))
    end

    test_failure([
        """
        In struct `$(@__MODULE__).S`, the field `d` does not have a fully specified type:
          - `d::Dict{K}`

        The complete type is `Dict{K, T1} where {T1}`. The current definition \
        specifies 1 type arguments, but the type `Dict{K, T1} where {T1}` expects 2 \
        type parameter(s). This means the struct's field currently has an abstract type \
        (it is type unstable), and any access to it will cause a dynamic dispatch.

        If this was a mistake, possibly caused by a change to the `Dict` type that \
        introduced new parameters to it, please make sure that your field `d` is fully \
        concrete, with all parameters specified.

        If, instead, this type instability is on purpose, please fully specify the omitted \
        type parameters to silence this message. You can write that as `Dict{K, T1} where \
        {T1}`, or possibly in a shorter alias form which this message can't always \
        detect. (E.g. you can write `Vector{T} where T` instead of `Array{T, 1} where T`.)
        """
    ]) do
        test_all_fields_fully_specified(@__MODULE__,
            :(struct S{K}
                a::Int
                d::Dict{K}
                y::Vector{K}
            end))
    end


    # MULTIPLE FAILURES
    # TODO: unfortunately we can only report one at a time right now.

    test_failure([
        """
        In struct `$(@__MODULE__).S`, the field `d` does not have a fully specified type:
          - `d::Dict`

        The complete type is `Dict{T1, T2} where {T1, T2}`. The current definition \
        specifies 0 type arguments, but the type `Dict{T1, T2} where {T1, T2}` expects 2 \
        type parameter(s). This means the struct's field currently has an abstract type \
        (it is type unstable), and any access to it will cause a dynamic dispatch.

        If this was a mistake, possibly caused by a change to the `Dict` type that \
        introduced new parameters to it, please make sure that your field `d` is fully \
        concrete, with all parameters specified.

        If, instead, this type instability is on purpose, please fully specify the omitted \
        type parameters to silence this message. You can write that as `Dict{T1, T2} where \
        {T1, T2}`, or possibly in a shorter alias form which this message can't always \
        detect. (E.g. you can write `Vector{T} where T` instead of `Array{T, 1} where T`.)
        """
    ]) do
        test_all_fields_fully_specified(@__MODULE__,
            :(struct S
                a::Int
                d::Dict
                e::Dict
                y::Vector{T} where T
            end))
    end

end

