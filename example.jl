##
# Based of https://github.com/gpudirect/libmp/blob/master/examples/mp_sendrecv_kernel.cu
##
import MPI

using Hydrozoa
using Hydrozoa.Device
using CUDAnative

const MAX_SIZE = 64*1024
const ITER_COUNT_SMALL = 20
const ITER_COUNT_LARGE = 10
const WINDOW_SIZE = 64

struct Comms{N}
    tx::NTuple{N, SendDesc}
    tx_wait::NTuple{N, WaitDesc}
    rx_wait::NTuple{N, WaitDesc}
end

function exchange_kernel(rank, descs::Comms, N)
    @cuassert(gridDim().x == 1)
    for i in 1:N
        if rank == 0
            if threadIdx().x == 1
                @cuprintf("i=%ld, send+recv", i)
                threadfence()
                send(descs.tx[i])
                wait(descs.tx_wait[i])
                signal(descs.tx_wait[i])
                wait(descs.rx_wait[i])
                signal(descs.rx_wait[i])
            end
            sync_threads()
        else
            if threadIdx().x == 1
                @cuprintf("i=%ld, recv+send", i)
                threadfence()
                wait(descs.rx_wait[i])
                signal(descs.rx_wait[i])
                send(descs.tx[i])
                wait(descs.tx_wait[i])
            end
            sync_threads()
        end
    end
end

function exchange(comm, size, iter_count, validate)
    @info "implementation not yet done"


    # @cuda blocks=1, threads=16, stream=stream exchange_kernel(rank, descs, N)
end

function main(validate = true)
    MPI.Init()
    comm = MPI.COMM_WORLD

    if MPI.Comm_size(comm) != 2
        @error "This test requires exactly two processes"
        MPI.Abort(comm, -1)
        return
    end

    rank = MPI.Comm_rank(comm)

    # init gpus
    # init MP
    iter_count = ITER_COUNT_SMALL

    size = 1
    while size <= MAX_SIZE
        if size > 1024
            iter_count = ITER_COUNT_LARGE
        end

        exchange(comm, size, iter_count, validate)

        if rank == 0
            @info "SendRecv test passed validation with message size" size
        end

        size *= 2
    end

    # mp_finalize
    MPI.Barrier(comm)
    MPI.finalize()
end
