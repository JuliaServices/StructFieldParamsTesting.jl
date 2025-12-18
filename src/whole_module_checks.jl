function test_all_structs_have_fully_specified_fields(pkg::Module; verbose::Bool=false)
    dir = pkgdir(pkg)
    @assert !isnothing(dir) "No file found for Module `$(pkg)`."
    entrypoint = joinpath(dir, "src", "$(nameof(pkg)).jl")
    @assert ispath(entrypoint) "Package $(pkg) source not found: $entrypoint"
    @testset "$(pkg).jl" verbose=verbose begin
        test_all_structs_have_fully_specified_fields(pkg, entrypoint; verbose)
    end
end

function test_all_structs_have_fully_specified_fields(
    mod::Module, filename::AbstractString; verbose::Bool=false
)
    # Parse the file and call handle_parsed_expression on each expression.
    contents = read(filename, String)
    walk_string(contents, filename) do parsed, loc
        handle_parsed_expression(mod, parsed, loc; verbose)
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

handle_parsed_expression(::Module, x::Any, _loc; kw...) = nothing
function handle_parsed_expression(mod::Module, parsed::Expr, loc; verbose::Bool=false)
    # @show loc
    if parsed.head == :struct
        # DO THE THING
        location = "$(loc.file):$(loc.line)"
        test_all_fields_fully_specified(mod, parsed; location)
    elseif parsed.head == :call && parsed.args[1] == :include
        # Follow includes to more files
        new_file = joinpath(dirname(String(loc.file)), parsed.args[2])
        return test_all_structs_have_fully_specified_fields(mod, new_file)
    elseif parsed.head == :module
        modname = parsed.args[2]
        inner_mod = Core.eval(mod, modname)
        @testset "$(inner_mod)" verbose=verbose begin
            for expr in parsed.args
                handle_parsed_expression(inner_mod, expr, loc; verbose)
            end
        end
    else
        for expr in parsed.args
            handle_parsed_expression(mod, expr, loc)
        end
    end
end
