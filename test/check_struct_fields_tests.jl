
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
