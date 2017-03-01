type Instance
    V::Int
    E::Int
    R::Int
    C::Int
    X::Int
    S
    Ld
    L
    num_req
    origins_of_request
end

function write_solution(path::String, solution)
    f = open(path,"w")
    nonempty_servers = solution.count
    write(f, "$nonempty_servers\n")
    for c in sort(collect(keys(solution)))
        write(f, "$(c-1)")
        for v in solution[c]
            write(f, " $(v-1)")
        end
        write(f, "\n")
    end
    close(f)
end

function read_solution(path::String)
    f = open(path,"r")
    read_split_and_cast() = map(parse,split(strip(readline(f))))
    assigned_servers = read_split_and_cast()[1]
    solution = Dict{Int, Vector{Int}}()
    for s in 1:assigned_servers
        elements = read_split_and_cast()
        c = elements[1] + 1
        solution[c] = elements[2:end] + 1
    end
    return solution
    close(f)
end


function read_instance(path::String)
    f = open(path)
    read_split_and_cast() = map(parse,split(strip(readline(f))))

    V, E, R, C, X = read_split_and_cast()
    println("$V $E $R $C $X")
    S = read_split_and_cast()

    Ld = zeros(Int, E)
    L = [Dict{Int,Int}() for i in 1:E]
    for e in 1:E
        Ld[e], K = read_split_and_cast()
        for k in 1:K
            #when using index read from file, must add 1
            c, L[e][c+1] = read_split_and_cast()
        end
    end

    num_req = [Dict{Int,Int}() for i in 1:E]
    origins_of_request = [Set{Int}() for i in 1:V]
    for r in 1:R
        #when using index read from file, must add 1
        v, e, n_req = read_split_and_cast()
        if haskey(num_req[e+1], v+1)
            #println("The video $v already has a request from $e")
            num_req[e+1][v+1] += n_req
        else
            num_req[e+1][v+1] = n_req
        end
        push!(origins_of_request[v+1], e+1)
    end

    close(f)
    Instance(V, E, R, C, X, S, Ld, L, num_req, origins_of_request)
end

function evaluate(solution, inst::Instance)
    V, E, Ld, L, num_req, origins_of_request = inst.V, inst.E, inst.Ld, inst.L, inst.num_req, inst.origins_of_request

    all_requests = sum(sum(values(num_req[e])) for e in 1:E)
    base_delay = sum(sum(values(num_req[e]))*Ld[e] for e in 1:E)
    
    min_latency = Dict{Tuple{Int,Int},Int}()
    for c in keys(solution)
        for v in solution[c], e in origins_of_request[v] 
            if c in keys(L[e])
                min_latency[e,v] = min(L[e][c], get(min_latency, (e,v), Ld[e]))
            end
        end
    end

    minimum_delay = 0
    for e in 1:E, v in keys(num_req[e])
        minimum_delay += num_req[e][v]*get(min_latency, (e,v), Ld[e])
    end
    
    println("Minimum delay: $minimum_delay")
    total_saving = base_delay - minimum_delay 
    per_request_saving_in_ms = trunc(1000*total_saving / all_requests)
    println("Optimal savings: $per_request_saving_in_ms ms")
end
