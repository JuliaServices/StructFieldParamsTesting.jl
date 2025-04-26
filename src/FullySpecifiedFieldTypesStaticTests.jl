module FullySpecifiedFieldTypesStaticTests

export test_all_structs_have_fully_specified_fields
export test_all_fields_fully_specified, field_is_fully_specified

using MacroTools: @capture
using Test

include("check_struct_fields.jl")
include("whole_module_checks.jl")

end  # module FullySpecifiedFieldTypesStaticTests
