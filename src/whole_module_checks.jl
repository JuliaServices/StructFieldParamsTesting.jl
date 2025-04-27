
function test_all_structs_have_fully_specified_fields(pkg::Module)
    @testset "$(pkg)" begin
        dir = pkgdir(pkg)
        @assert !isnothing(dir) "No file found for Module `$(pkg)`."
        entrypoint = joinpath(dir, "src", "$(nameof(pkg)).jl")
        @assert ispath(entrypoint) "Package $(pkg) source not found: $entrypoint"

        include_and_parse_file(pkg, entrypoint)
    end
end

function include_and_parse_file(pkg::Module, file::String)
    # Parse the file and call handle_parsed_expression on each expression.
    contents = read(file, String)
    eval_module = Module(:FullySpecifiedFieldTypesStaticTests__Evals)
    Base.include_string(eval_module, contents, relpath(file)) do e
        handle_parsed_expression(pkg, e)
    end
end

handle_parsed_expression(::Module, ::Any) = nothing
function handle_parsed_expression(pkg::Module, parsed::Expr)
    if parsed.head == :struct
        # DO THE THING
        @show parsed
        test_all_fields_fully_specified(pkg, parsed)
    elseif parsed.head == :call && parsed.args[1] == :include
        # Follow includes to more files
        include_and_parse_file(pkg, parsed.args[2])
    else
        for expr in parsed.args
            handle_parsed_expression(pkg, expr)
        end
    end
end
