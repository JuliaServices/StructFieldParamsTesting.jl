mutable struct StructStats
    total::Int
    unspecified::Int

    StructStats() = new(0, 0)
end

function test_all_structs_have_fully_specified_fields(pkg::Module; verbose::Bool=false)
    dir = pkgdir(pkg)
    @assert !isnothing(dir) "No file found for Module `$(pkg)`."
    entrypoint = joinpath(dir, "src", "$(nameof(pkg)).jl")
    @assert ispath(entrypoint) "Package $(pkg) source not found: $entrypoint"
    @testset "$(pkg).jl" verbose=verbose begin
        test_all_structs_have_fully_specified_fields(pkg, entrypoint; verbose)
    end
end

function print_all_structs_have_fully_specified_fields(pkg::Module)
    dir = pkgdir(pkg)
    @assert !isnothing(dir) "No file found for Module `$(pkg)`."
    entrypoint = joinpath(dir, "src", "$(nameof(pkg)).jl")
    @assert ispath(entrypoint) "Package $(pkg) source not found: $entrypoint"

    # Use a shared stats object across all files
    struct_stats = StructStats()
    print_all_structs_have_fully_specified_fields(pkg, entrypoint, struct_stats)

    # Print summary only once at the end
    if struct_stats.total > 0
        fully_specified = struct_stats.total - struct_stats.unspecified
        println("Module `$(pkg)` has $(fully_specified)/$(struct_stats.total) structs with fully specified fields")
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

function print_all_structs_have_fully_specified_fields(
    mod::Module, filename::AbstractString, struct_stats::Union{StructStats, Nothing} = nothing
)
    # Parse the file and call handle_parsed_expression_print on each expression.
    contents = read(filename, String)

    # If no stats provided, create one and mark that we should print summary
    should_print_summary = struct_stats === nothing
    if struct_stats === nothing
        struct_stats = StructStats()
    end

    walk_string(contents, filename) do parsed, loc
        handle_parsed_expression_print(mod, parsed, loc, struct_stats)
    end

    # Print summary only if this was the top-level call
    if should_print_summary && struct_stats.total > 0
        fully_specified = struct_stats.total - struct_stats.unspecified
        println("Module `$(mod)` has $(fully_specified)/$(struct_stats.total) structs with fully specified fields")
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

handle_parsed_expression_print(::Module, x::Any, _loc, stats) = nothing
function handle_parsed_expression_print(mod::Module, parsed::Expr, loc, stats)
    if parsed.head == :struct
        # Count all structs and check if they have unspecified fields
        location = "$(loc.file):$(loc.line)"

        # Check if struct has any unspecified fields first
        (struct_name, T, fields_dict) = StructFieldParamsTesting._extract_struct_field_types(mod, parsed)
        has_unspecified = false

        for (field_name, field_type_expr) in fields_dict
            is_specified = StructFieldParamsTesting.check_field_type_fully_specified(
                mod, struct_name, field_name, T, field_type_expr,
                report_error = false, location = location)

            if !is_specified
                has_unspecified = true
                break
            end
        end

        # Update statistics
        stats.total += 1
        if has_unspecified
            stats.unspecified += 1
        end

        # Only print if there are issues
        if has_unspecified
            print_all_fields_fully_specified(mod, parsed; location)
            println()  # Add spacing between structs
        end
    elseif parsed.head == :call && parsed.args[1] == :include
        # Follow includes to more files
        new_file = joinpath(dirname(String(loc.file)), parsed.args[2])
        return print_all_structs_have_fully_specified_fields(mod, new_file, stats)
    elseif parsed.head == :module
        modname = parsed.args[2]
        inner_mod = Core.eval(mod, modname)
        println("=== Module: $(inner_mod) ===")
        for expr in parsed.args
            handle_parsed_expression_print(inner_mod, expr, loc, stats)
        end
    else
        for expr in parsed.args
            handle_parsed_expression_print(mod, expr, loc, stats)
        end
    end
end
