import main
import numpy as np
import random 

def greedy(input_data, seed=2):
    (V, E, R, C, X), video_sizes, endpoint_latency2datacenter, endpoint_latency2cache, requests = input_data
 
    L = {}
    Ld = endpoint_latency2datacenter
    connected_servers = {}
    for e in range(E):
        connected_servers[e] = [c for (c,Lc) in endpoint_latency2cache[e]]
        for (c,Lc) in endpoint_latency2cache[e]:
            L[c,e] =  Lc

   
    sol= [[] for c in range(C)] 
    load = [0 for c in range(C)]

    random.seed = seed 
    random.shuffle(requests)
    for (v, e, num_req) in requests:
        if len(connected_servers[e]) == 0:
            continue

        best_score, selected_c = min([ (num_req * (Ld[e] - L[c,e]), c) for c in connected_servers[e] ])
        
        if load[selected_c] + video_sizes[v] <= X:
            if v not in sol[selected_c]:
                sol[selected_c].append(v)
                load[selected_c] += video_sizes[v]
    
    print(evaluate(sol, input_data)) 
    return sol

def greedy_improved(input_data):
    (V, E, R, C, X), video_sizes, endpoint_latency2datacenter, endpoint_latency2cache, requests = input_data
    L = {}
    Ld = endpoint_latency2datacenter
    connected_servers = {}
    for e in range(E):
        connected_servers[e] = [c for (c,Lc) in endpoint_latency2cache[e]]
        for (c,Lc) in endpoint_latency2cache[e]:
            L[c,e] =  Lc

   
    sol= [[] for c in range(C)] 
    load = [0 for c in range(C)]
    
    count = {}
    for (v, e, num_req) in requests:
        count[v] = count.get(v,0) + num_req

    requests_with_score = [((count[v] * (Ld[e] - np.mean([L[c,e] for c in connected_servers[e]])))*(1/video_sizes[v]), v,e,num_req) for (v,e,num_req) in requests if len(connected_servers[e]) > 0]
    sorted_requests = sorted(requests_with_score, reverse=True)

    updated = True
    for (score, v, e, num_req) in sorted_requests:
        if len(connected_servers[e]) == 0:
            continue

        best_score, selected_c = max([ (num_req * (Ld[e] - L[c,e]), c) for c in connected_servers[e] ])
        
        if load[selected_c] + video_sizes[v] <= X:
            if v not in sol[selected_c]:
                sol[selected_c].append(v)
                load[selected_c] += video_sizes[v]
    
    #print(evaluate(sol, input_data)) 
    return sol


def transform_sol(sol):
    transformed_sol = [[i] for i,s in enumerate(sol) if len(s) > 0]
    for t in transformed_sol:
        t.extend(sol[t[0]])
    return transformed_sol

def evaluate(assignment, input_data):
    
    (V, E, R, C, X), video_sizes, endpoint_latency2datacenter, endpoint_latency2cache, requests = input_data
    L = {}
    Ld = endpoint_latency2datacenter
    connected_servers = {}
    for e in range(E):
        connected_servers[e] = [c for (c,Lc) in endpoint_latency2cache[e]]
        for (c,Lc) in endpoint_latency2cache[e]:
            L[c,e] =  Lc

    
    for c in range(C):
        if sum(video_sizes[v] for v in assignment[c]) > X:
            return -1
    
    min_latency = { (v,e): Ld[e] for (v,e,num_req) in requests }
    for (v,e,num_req) in requests:
        for c in connected_servers[e]:
            if v in assignment[c]:
                min_latency[v,e] = min(min_latency[v,e], L[c,e])
  

    #print(min_latency)
    score = int(sum( num_req*(Ld[e] - min_latency[v,e]) for (v,e,num_req) in requests)/ sum(num_req for (v,e,num_req) in requests)*1000)
    return score


def replace(sol, cache_server, inserted_video, removed_video, input_data):
    s = [x.copy() for x in sol]
    s[cache_server].remove(removed_video)
    s[cache_server].append(inserted_video)
    return s, evaluate(s, input_data) 
 
def replace(sol, cache_server, inserted_video, removed_video, input_data):
    s = [x.copy() for x in sol]
    s[cache_server].remove(removed_video)
    s[cache_server].append(inserted_video)
    return s, evaluate(s, input_data) 
    

def local_search(start_sol, input_data, maxit=10):
    cur_sol = start_sol
    cur_val = evaluate(cur_sol, input_data)
    for it in range(maxit):
      print(it)
      for c, assigned in enumerate(start_sol):
        for j in cur_sol[c]:
            for i in range(V):
                if i not in cur_sol[c] and j in cur_sol[c]:
                    new_sol, new_val = replace(cur_sol, c, i, j, input_data)
                    if new_val > cur_val:
                        print("found new best", new_val)
                        cur_sol = new_sol
                        cur_val = new_val
                        
    return cur_sol 

#    #feasible
#    if 
#    removed_value = sum( num_req*(Ld[e] - min_latency[v,e]) for (v,e,num_req) in requests if v == removed_video and )
            #/ sum(num_req for (v,e,num_req) in requests)*1000)

