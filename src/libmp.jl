module LIBMP

const SUCCESS = 0
const FAILURE = 1

const libmp = ""

macro apicall(fun, argtypes, args...)
    isa(fun, QuoteNode) || error("first argument to @apicall should be a symbol")

    return quote
        status = ccall(($fun, libcuda), Cint,
                       $(esc(argtypes)), $(map(esc, args)...))

        if status != SUCCESS
            error()
        end
    end
end

const PARAM_VERSION = Cint(0)
const NUM_PARAMS = Cint(1)


function query_param(param)
    val = Ref{Cint}()
    @apicall(:mp_query_param, (Cint, Ref{Cint}), param, val)
    return val[]
end

# Opaque handles
struct mp_reg end
struct mp_request end
struct mp_window end

const Reg = Ptr{mp_reg};
const Request = Ptr{mp_request};
const Window = Ptr{mp_request};

const INIT_DEFAULT       = Cint(0)
const INIT_WQ_ON_GPU     = Cint(1)
const INIT_RX_CQ_ON_GPU  = Cint(2)
const INIT_TX_CQ_ON_GPU  = Cint(3)
const INIT_DBREC_ON_GPU  = Cint(4)

"""
    init(comm, peers, flags, gpu_id)

Initialize the MP library

# Arguments:
- comm: MPI communicator to use to bootstrap connection establishing
- peers: array of MPI ranks with which to establish a connection
- flags: combination of mp_init_flags
"""
function init(comm, peers, flags, gpu_id)
    @apicall(:mp_init, (MPI.CComm, Ptr{Cint}, Cint, Cint, Cint), comm, peers, length(peers), flags, gpu_id)
end

function finalize()
    @apicall(:mp_finalize, ())
end


function register(addr, length, reg)
    @apicall(:mp_register, (Ptr{Cvoid}, Csize_t, Ptr{Reg}), addr, length, reg)
end

function deregister(reg)
    @apicall(:mp_deregister, (Ptr{Reg},), reg)
end

function irecv(buf, size, peer, mp_req, req)
    @apicall(:mp_irecv, (Ptr{Cvoid}, Cint, Cint, Ptr{Req}, Ptr{Request}), buf, size, peer, mp_reg, req)
end

function isend(buf, size, peer, mp_req, req)
    @apicall(:mp_irecv, (Ptr{Cvoid}, Cint, Cint, Ptr{Reg}, Ptr{Request}), buf, size, peer, mp_reg, req)
end

function wait(reg)
    @apicall(:mp_wait, (Ptr{Reg},), reg)
end

function wait_all(regs::Vector{Reg})
    @apicall(:mp_wait_all, (UInt32, Ptr{Reg},), length(regs), regs)
end

function progress_all(regs::Vector{Reg})
    @apicall(:mp_progress_all, (UInt32, Ptr{Reg},), length(regs), regs)
end

# /*
# * CUDA stream synchronous primitives
# */
# int mp_send_on_stream  (void *buf, int size, int peer, mp_reg_t *mp_reg,
#                   mp_request_t *req, cudaStream_t stream);
# int mp_isend_on_stream (void *buf, int size, int peer, mp_reg_t *mp_reg,
#                   mp_request_t *req, cudaStream_t stream);
# //int mp_irecv_on_stream (void *buf, int size, int peer, mp_reg_t *mp_reg,
# //                        mp_request_t *req, cudaStream_t stream);

# /* vector sends/recvs
# * caveats: all blocks are within same registration
# */
# int mp_isendv(struct iovec *v, int nblocks, int peer, mp_reg_t *mp_reg, mp_request_t *req);
# int mp_irecvv(struct iovec *v, int nblocks, int peer, mp_reg_t *mp_reg, mp_request_t *req);

# int mp_isendv_on_stream (struct iovec *v, int nblocks, int peer, mp_reg_t *mp_reg,
#        mp_request_t *req, cudaStream_t stream);

# /*
# * GPU synchronous functions
# */
# int mp_wait_on_stream (mp_request_t *req, cudaStream_t stream);
# int mp_wait_all_on_stream (uint32_t count, mp_request_t *req, cudaStream_t stream);


# /* Split API to allow for batching of operations issued to the GPU
# */

function send_prepare(buf, size, peer, reg, req)
    @apicall(:mp_send_prepare, (Ptr{Cvoid}, Cint, Cint, Ptr{Reg}, Ptr{Request}), buf, size, peer, reg, req)
end
# int mp_sendv_prepare (struct iovec *v, int nblocks, int peer, mp_reg_t *mp_reg,
#                    mp_request_t *req);

# int mp_send_post_on_stream (mp_request_t *req, cudaStream_t stream);
# int mp_isend_post_on_stream (mp_request_t *req, cudaStream_t stream);
# int mp_send_post_all_on_stream (uint32_t count, mp_request_t *req, cudaStream_t stream);
# int mp_isend_post_all_on_stream (uint32_t count, mp_request_t *req, cudaStream_t stream);

# /*
# * One-sided communication primitives
# */

# /* window creation */
# int mp_window_create(void *addr, size_t size, mp_window_t *window_t);
# int mp_window_destroy(mp_window_t *window_t);

# enum mp_put_flags {
# MP_PUT_INLINE  = 1<<0,
# MP_PUT_NOWAIT  = 1<<1, // don't generate a CQE, req cannot be waited for
# };

# int mp_iput (void *src, int size, mp_reg_t *src_reg, int peer, size_t displ, mp_window_t *dst_window_t, mp_request_t *req, int flags);
# int mp_iget (void *dst, int size, mp_reg_t *dst_reg, int peer, size_t displ, mp_window_t *src_window_t, mp_request_t *req);

# int mp_iput_on_stream (void *src, int size, mp_reg_t *src_reg, int peer, size_t displ, mp_window_t *dst_window_t, mp_request_t *req, int flags, cudaStream_t stream);

# int mp_put_prepare (void *src, int size, mp_reg_t *src_reg, int peer, size_t displ, mp_window_t *dst_window_t, mp_request_t *req, int flags);

# int mp_iput_post_on_stream (mp_request_t *req, cudaStream_t stream);

# int mp_iput_post_all_on_stream (uint32_t count, mp_request_t *req, cudaStream_t stream);

# /*
# * Memory related primitives
# */

# enum mp_wait_flags {
# MP_WAIT_GEQ = 0,
# MP_WAIT_EQ,
# MP_WAIT_AND,
# };

# int mp_wait32(uint32_t *ptr, uint32_t value, int flags);
# int mp_wait32_on_stream(uint32_t *ptr, uint32_t value, int flags, cudaStream_t stream);

# static inline int mp_wait_dword_geq_on_stream(uint32_t *ptr, uint32_t value, cudaStream_t stream)
# {
# return mp_wait32_on_stream(ptr, value, MP_WAIT_GEQ, stream);
# }

# static inline int mp_wait_dword_eq_on_stream(uint32_t *ptr, uint32_t value, cudaStream_t stream)
# {
# return mp_wait32_on_stream(ptr, value, MP_WAIT_EQ, stream);
# }

# /*
# *
# */

# typedef struct mp_desc_queue *mp_desc_queue_t;

# int mp_desc_queue_alloc(mp_desc_queue_t *dq);
# int mp_desc_queue_free(mp_desc_queue_t *dq);
# int mp_desc_queue_add_send(mp_desc_queue_t *dq, mp_request_t *req);
# int mp_desc_queue_add_wait_send(mp_desc_queue_t *dq, mp_request_t *req);
# int mp_desc_queue_add_wait_recv(mp_desc_queue_t *dq, mp_request_t *req);
# int mp_desc_queue_add_wait_value32(mp_desc_queue_t *dq, uint32_t *ptr, uint32_t value, int flags);
# int mp_desc_queue_add_write_value32(mp_desc_queue_t *dq, uint32_t *ptr, uint32_t value);
# int mp_desc_queue_post_on_stream(cudaStream_t stream, mp_desc_queue_t *dq, int flags);

end
