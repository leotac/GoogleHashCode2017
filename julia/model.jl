using JuMP, Gurobi, CPLEX
include("utils.jl")

function build_solution(x)
    x_val = getvalue(x)
    V = size(x_val,1)
    C = size(x_val,2)
    nonempty_servers = [c for c in 1:C if sum(x_val[1:end,c]) > 0.9] 
    solution = Dict{Int, Vector{Int}}()
    for c in nonempty_servers
        solution[c] = Vector{Int}()
        for v in 1:V
            if x_val[v,c] > 0.9
                push!(solution[c], v)
            elseif x_val[v,c] > 0.1
                println("Warning!!")
            end
        end
    end
    return solution
end

function set_mip_start(sol, x)
    for c in keys(sol), v in sol[c]
        setvalue(x[v,c], 1)
    end
end

function solve_instance(instance_name,
    conn_divider = 1,
    req_divider = 1, 
    mip_start_file = "")
    
    println("Reading the data from $instance_name...")
    inst = read_instance("../dataset/$instance_name.in")
    V, E, R, C, X, S, Ld, L, num_req, origins_of_request = inst.V, inst.E, inst.R, inst.C, inst.X, inst.S, inst.Ld, inst.L, inst.num_req, inst.origins_of_request
    
    println("Read a dataset with $V videos, $E endpoints, $R requests and $C cache servers...")
    
    bad_connections = 0
    for e=1:E, c in keys(L[e])
        if (Ld[c] <= L[e][c])
            print("\r$bad_connections cache/endpoint connections with higher latency than the data center have been removed.")
            flush(STDOUT)
            delete!(L[e], c)
            bad_connections += 1
        end
    end
    print("\n")

    #if conn_divider > 1, consider only the fastest connections for each endpoint
    L_original = copy(L)
    L = [Dict{Int,Int}() for e in 1:E]
    for e in 1:E 
       L[e] = Dict(sort(collect(L_original[e]), by=x->x[2])[1:div(end,conn_divider)])
    end
 
    #if req_divider > 1, consider only the most convenient requests for each endpoint
    num_req_original = copy(num_req)
    num_req = [Dict{Int,Int}() for e in 1:E]
    for e in 1:E 
       num_req[e] = Dict(sort(collect(num_req_original[e]), by=x->-x[2]/S[x[1]])[1:div(end,req_divider)])
    end
   
    distinct_req = 0
    for e in 1:E, v in keys(num_req[e])
        distinct_req +=1
    end
    println("$distinct_req distinct requests..")
    
    # V #number of videos
    # E #number of endpoints
    # R #number of requests
    # C #number of cache servers
    # X #capacity
    # S[v]    #size of video v
    # Ld[e]   #latency from data center to endpoint e
    # L[e,c]  #latency from cache server c to endpoint e
    # num_req[e,v]    #number of requests for video v from endpoint e
    good_V = [keys(num_req[e]) for e in 1:E]
    good_C = [keys(L[e]) for e in 1:E]
    
    println("Building the model...")
    m = Model(solver=GurobiSolver())
    #m = Model(solver=CplexSolver(CPX_PARAM_TILIM=600))
    
    println("Adding the variables...")
    # Assignment variables
    @variable(m, x[1:V,1:C], Bin)
    
    if mip_start_file != ""
        mip_start = read_solution(mip_start_file)
        set_mip_start(mip_start, x)
    end
    
    # Auxiliary variables
    # Minimum delay for video v from endpoint e
    @variable(m, η[e in 1:E, v in good_V[e]] ≥ 0)
 
    # Whether the data center has been chosen to serve video v for endpoint e
    @variable(m, ζ[e in 1:E, v in good_V[e]], Bin)
    
    if instance_name != "trending_today" 
        # Whether the cache server c has been chosen to serve video v for endpoint e
        # i.e., it has minimum delay for video v from endpoint e
        @variable(m, σ[e in 1:E, c in good_C[e], v in good_V[e]], Bin)
    end

    # Objective function: min latency for (e,v) weighed by the number of requests
    @objective(m, Min, sum(num_req[e][v]*η[e,v] for e ∈ 1:E, v ∈ good_V[e] ) )
    
    # Capacity constraint
    println("Adding the capacity constraints...")
    @constraint(m, capacity[c=1:C], ∑(S[v]*x[v,c] for v ∈ 1:V) ≤ X)
    
    # Auxiliary constraints - linearization
    
    if instance_name != "trending_today" 
        # If v is not in the cache server c, then c cannot be selected
        # for the request (e,v)
        println("Auxiliary 1...")
        for e ∈ 1:E, c ∈ good_C[e], v ∈ good_V[e]
            @constraint(m, σ[e,c,v] ≤ x[v,c])
        end
        
        # For each video v requested from e, either a cache server is selected,
        # or the request is served from the data center.
        println("Auxiliary 2...")
        for e ∈ 1:E, v ∈ good_V[e] 
            @constraint(m, ζ[e,v] + ∑(σ[e,c,v] for c ∈ keys(L[e])) == 1)
        end
            
        # Ensure η takes the correct value in an optimal solution 
        println("Auxiliary 3...")
        for e ∈ 1:E, c ∈ good_C[e], v ∈ good_V[e]
        
            # The latency for a request is either the latency from the selected cache server..
            @constraint(m, η[e,v] ≥ L[e][c] * σ[e,c,v])
        end    
        for e in 1:E, v = keys(num_req[e])
            # or the latency from the data center.
            @constraint(m, η[e,v] ≥ Ld[e] * ζ[e,v])
        end
    else 
        #trending_today instance: all cache servers have the same latency (100 ms), 
        # all data center latencies are the same (600 ms)
        Ld = Ld[1]
        Lc = L[1][1]
        for e ∈ 1:E, v ∈ good_V[e]
            # For each video v requested from e, either it is assigned to a cache server,
            # or it is served from the data center.
            @constraint(m, ζ[e,v] + ∑(x[v,c] for c in good_C[e]) == 1)
            
            # If v is served from the data center, the delay is Ld
            # otherwise it is Lc
            @constraint(m, η[e,v] ≥ Ld * ζ[e,v] + Lc * (1 - ζ[e,v]) )
        end
    end

    status = solve(m)
    
    if(status == :Optimal)
        println("Optimal!")
    else
        println("Not optimal! End with status: $status")
    end
    
    all_requests = sum(sum(values(num_req[e])) for e in 1:E)
    base_delay = sum(sum(values(num_req[e]))*Ld[e] for e in 1:E)
    minimum_delay = m.objVal 
    total_saving = base_delay - minimum_delay 
    println("Minimum delay as per the objective function: $minimum_delay")
    per_request_saving_in_ms = trunc(1000*total_saving / all_requests)
    println("Optimal savings as per the objective function: $per_request_saving_in_ms ms")
    
    solution = build_solution(x)
    evaluate(solution, inst)
    #write_solution("$instance_name.mip.sol",solution)
    solution
end
