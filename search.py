import random

def greedy(input_data):
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

    #random.seed(1)
    #random.shuffle(requests)

    requests = sorted(requests, key=lambda request: request[2], reverse=True)

    video_cache_gain = {}

    for (v, e, num_req) in requests:
        if len(connected_servers[e]) == 0:
            continue

        best_score, selected_c = max([(num_req * (Ld[e] - L[c, e]), c) for c in connected_servers[e]])

        k = str(v)+"_"+str(selected_c)
        if not k in video_cache_gain:
            video_cache_gain[k] = 0;
        video_cache_gain[k] += best_score

    video_cache_gain_list = list()
    for key, value in video_cache_gain.iteritems():
        video_cache_gain_list.append({'key': key, 'value':value})

    video_cache_gain_list = sorted(video_cache_gain_list, key=lambda item: item['value'], reverse=True)

    for idx, value in enumerate(video_cache_gain_list):
        v, selected_c = value['key'].split("_")
        v = int(v)
        selected_c = int(selected_c)

        if load[selected_c] + video_sizes[v] <= X:
            if v not in sol[selected_c]:
                sol[selected_c].append(v)
                load[selected_c] += video_sizes[v]

    #requests = sorted(requests, key=lambda request: video_sizes[request[0]], reverse=True)

    # for (v, e, num_req) in requests:
    #     if len(connected_servers[e]) == 0:
    #         continue
    #
    #     best_score, selected_c = max([ (num_req * (Ld[e] - L[c,e]), c) for c in connected_servers[e] ])
    #
    #     if load[selected_c] + video_sizes[v] <= X:
    #         if v not in sol[selected_c]:
    #             sol[selected_c].append(v)
    #             load[selected_c] += video_sizes[v]

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
        connected_servers[e] = [c for (c, Lc) in endpoint_latency2cache[e]]
        for (c, Lc) in endpoint_latency2cache[e]:
            L[c, e] = Lc

    min_latency = { (v,e): Ld[e] for (v,e,num_req) in requests }
    for (v,e,num_req) in requests:
        for c in connected_servers[e]:
            if v in assignment[c]:
                min_latency[v,e] = min(min_latency[v,e], L[c,e])
  

    score = int(sum( num_req*(Ld[e] - min_latency[v,e]) for (v,e,num_req) in requests)/ sum(num_req for (v,e,num_req) in requests)*1000)
    return score
