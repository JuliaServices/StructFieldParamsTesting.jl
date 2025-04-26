
@testitem "FullySpecifiedFieldTypesStaticTests.jl" begin

    # Concrete DataType
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

end
