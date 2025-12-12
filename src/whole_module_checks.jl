function test_all_structs_have_fully_specified_fields(pkg::Module)
    @testset "$(pkg)" begin
        dir = pkgdir(pkg)
        @assert !isnothing(dir) "No file found for Module `$(pkg)`."
        entrypoint = joinpath(dir, "src", "$(nameof(pkg)).jl")
        @assert ispath(entrypoint) "Package $(pkg) source not found: $entrypoint"
        test_file(pkg, entrypoint)
    end
end

function test_file(pkg::Module, filename::String)
    # Parse the file and call handle_parsed_expression on each expression.
    contents = read(filename, String)
    walk_string(contents, filename) do parsed, loc
        handle_parsed_expression(pkg, parsed, loc)
    end
end

# Based on `Base.include_string` but with two differences:
# 1. `mapexpr` takes a second argument which is a `LineNumberNode`
# 2. we do not eval the expressions, just call `mapexpr` on them
#   - this also means we do not need a `mod::Module` argument
function walk_string(mapexpr::Function, code::AbstractString, filename::AbstractString)
    loc = LineNumberNode(1, Symbol(filename))
    try
        ast = Meta.parseall(code; filename)
        @assert Meta.isexpr(ast, :toplevel)
        for ex in ast.args
            if ex isa LineNumberNode
                loc = ex
                continue
            end
            mapexpr(ex, loc)
        end
        return nothing
    catch exc
        rethrow(LoadError(filename, loc.line, exc))
    end
end

handle_parsed_expression(::Module, x::Any, _loc) = nothing
function handle_parsed_expression(pkg::Module, parsed::Expr, loc)
    if parsed.head == :struct
        # DO THE THING
        location = "$(loc.file):$(loc.line)"
        test_all_fields_fully_specified(pkg, parsed; location)
    elseif parsed.head == :call && parsed.args[1] == :include
        # Follow includes to more files
        new_file = joinpath(dirname(String(loc.file)), parsed.args[2])
        return test_file(pkg, new_file)
    elseif parsed.head == :module
        modname = parsed.args[2]
        inner_mod = Core.eval(pkg, modname)
        @testset "$(inner_mod)" begin
            for expr in parsed.args
                handle_parsed_expression(inner_mod, expr, loc)
            end
        end
    else
        for expr in parsed.args
            handle_parsed_expression(pkg, expr, loc)
        end
    end
end
