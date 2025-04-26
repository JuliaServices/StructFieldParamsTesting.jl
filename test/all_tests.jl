
@testitem "FullySpecifiedFieldTypesStaticTests.jl" begin

    test_field_fully_specified(
        @__MODULE__,
        :(struct S{T<:Int} x::Vector{T} end),
        :x,
    )

end
