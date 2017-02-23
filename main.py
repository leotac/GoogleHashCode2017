def read_input(file):

    file = open("dataset/" + file, "r")

    video_sizes = list()

    endpoint_latency2datacenter = list()
    endpoint_latency2cache = list()

    requests = list()

    # dimensioni
    V, E, R, C, X = file.readline().split(" ")
    V = int(V)
    E = int(E)
    R = int(R)
    C = int(C)
    X = int(X)

    # video sizes
    video_sizes = file.readline().split(" ")
    for idx, value in enumerate(video_sizes):
        video_sizes[idx] = int(value)

    # endpoints e latenze
    for E_idx in range(E):
        Ld, K = file.readline().split(" ")
        Ld = int(Ld)
        K = int(K)
        endpoint_latency2datacenter.append(Ld)

        # cache2endpoints latency
        latencies = list()
        for K_idx in range(K):
            c, Lc = file.readline().split(" ")
            c = int(c)
            Lc = int(Lc)
            latencies.append((c, Lc))

        endpoint_latency2cache.append(latencies)

    # richieste
    for R_idx in range(R):
        Rv, Re, Rn = file.readline().split(" ")
        Rv = int(Rv)
        Re = int(Re)
        Rn = int(Rn)
        requests.append((Rv, Re, Rn))

    file.close()

    return ((V, E, R, C, X), video_sizes, endpoint_latency2datacenter, endpoint_latency2cache, requests)

def write_output(file, output):

    caches = output
    N = len(caches)

    file = open("dataset/" + file, "w")
    file.write(str(N)+"\n")

    for idx, value in enumerate(caches):
        file.write(caches[idx][0])
        " ".join(caches[idx][1::])

def risolvi(input):
    print("esegui()")
    return " "

def main():
    print("start")

    dataset_files = ("me_at_the_zoo", "videos_worth_spreading", "trending_today", "kittens")

    inputs = list()
    output = list()

    for idx, value in enumerate(dataset_files):
        inputs.append(read_input(value+".in"))
        output.append(risolvi(inputs[idx]))
        write_output(value, output[idx]+".out")

    print("end")

main()