
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
    line = 0
    Base.include_string(eval_module, contents, relpath(file)) do e
        line = handle_parsed_expression(pkg, e, file, line)
    end
end

handle_parsed_expression(::Module, ::Any, _file, _line) = nothing
handle_parsed_expression(::Module, loc::LineNumberNode, _file, _line) = loc.line
function handle_parsed_expression(pkg::Module, parsed::Expr, file, line)
    if parsed.head == :struct
        # DO THE THING
        test_all_fields_fully_specified(pkg, parsed, location = "$(file):$(line)")
    elseif parsed.head == :call && parsed.args[1] == :include
        # Follow includes to more files
        new_file = joinpath(dirname(file), parsed.args[2])
        include_and_parse_file(pkg, new_file)
    elseif parsed.head == :module
        modname = parsed.args[2]
        inner_mod = Core.eval(pkg, modname)
        @testset "$(inner_mod)" begin
            for expr in parsed.args
                if expr isa LineNumberNode
                    line = expr.line
                else
                    line = handle_parsed_expression(inner_mod, expr, file, line)
                end
            end
        end
    else
        for expr in parsed.args
            line = handle_parsed_expression(pkg, expr, file, line)
        end
    end
end
