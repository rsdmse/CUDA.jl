module CUSPARSE

using ..CuArrays
using ..CuArrays: libcusparse, unsafe_free!, @argout, @workspace, @retry_reclaim

using CUDAapi

using CUDAdrv
using CUDAdrv: CUstream

using CUDAnative

using CEnum

const SparseChar = Char

# core library
include("libcusparse_common.jl")
include("error.jl")
include("libcusparse.jl")

# low-level wrappers
include("array.jl")
include("util.jl")
include("wrappers.jl")

# high-level integrations
include("interfaces.jl")

const handles_lock = ReentrantLock()
const created_handles = Dict{Tuple{UInt,Int},cusparseHandle_t}()
const active_handles = Vector{Union{Nothing,cusparseHandle_t}}()

function handle()
    tid = Threads.threadid()
    if @inbounds active_handles[tid] === nothing
        ctx = context()
        key = (objectid(ctx), tid)
        lock(handles_lock) do
            active_handles[tid] = get!(created_handles, key) do
                handle = cusparseCreate()
                atexit(()->CUDAdrv.isvalid(ctx) && cusparseDestroy(handle))
                handle
            end
        end
    end
    @inbounds active_handles[tid]
end

function __init__()
    resize!(active_handles, Threads.nthreads())
    fill!(active_handles, nothing)

    CUDAnative.atcontextswitch() do tid, ctx
        # we don't eagerly initialize handles, but do so lazily when requested
        active_handles[tid] = nothing
    end
end

end
