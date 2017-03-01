using JuMP, Gurobi, CPLEX
include("utils.jl")

function build_solution(x)
    x_val = getvalue(x)
    C = size(x_val,2)
    solution = [Vector{Int}() for i in 1:C]
    for c in 1:C, v in 1:V
        if x_val[v,c] > 0.9
            push!(solution[c], v-1)
        elseif x_val[v,c] > 0.1
            println("Warning!!")
        end
    end
    return solution
end

instance_name = "trending_today.in" 

println("Reading the data...")
V, E, R, C, X, S, Ld, L, num_req, origins_of_request = read_instance("dataset/$instance_name")

println("Reading a dataset with $V videos, $E endpoints, $R requests and $C cache servers...")
#assert(all(Ld[e] ≥ L[e,c] for e=1:E,c=1:C))

distinct_req = 0
for e in 1:E, c ∈ keys(L[e]), v = keys(num_req[e])
    distinct_req +=1
end
println("$distinct_req distinct requests..")

# In trending_today.in, all latencies are the same..
Ld = Ld[1]
Lc = L[1][1] #it exists

println("Building the model...")
#m = Model(solver=GurobiSolver(Threads=6))
m = Model(solver=CplexSolver(CPX_PARAM_EPGAP=1e-2))

# Assignment variables
@variable(m, x[1:V,1:C], Bin)

# Auxiliary variables
# Latency for video v from endpoint e -- it's either Ld or Lc
@variable(m, η[i in 1:E, v in keys(num_req[i])] ≥ 0)

# Whether the data center has been chosen to serve video v for endpoint e
@variable(m, ζ[e = 1:E, v = keys(num_req[e])], Bin)

@objective(m, Min, sum(num_req[e][v]*η[e,v] for e in 1:E, v in keys(num_req[e]) ) )

# Capacity constraint
@constraint(m, capacity[c=1:C], ∑(S[v]*x[v,c] for v ∈ 1:V) ≤ X)

# Auxiliary constraint

# For each video v requested from e, either it is assigned to a cache server,
# or it is served from the data center.
for e ∈ 1:E, v ∈ keys(num_req[e])
    @constraint(m, ζ[e,v] + ∑(x[v,c] for c in keys(L[e])) ≥ 1)
end

for e in 1:E, v = keys(num_req[e])
    # If v is served from the data center, the delay is Ld
    # otherwise it is Lc
    @constraint(m, η[e,v] ≥ Ld * ζ[e,v] + Lc * (1 - ζ[e,v]) )
end

status = solve(m)

if(status == :Optimal)
    all_requests = sum(sum(values(num_req[e])) for e in 1:E)
    base_delay = sum(sum(values(num_req[e]))*Ld for e in 1:E)
    minimum_delay = m.objVal 
    total_saving = base_delay - minimum_delay 
    per_request_saving_in_ms = trunc(1000*total_saving / all_requests)
    println("Optimal savings: $per_request_saving_in_ms ms")

    solution = build_solution(x)
    write_solution("$instance_name.mip.sol",solution)
else
    println("Not optimal!")
end

