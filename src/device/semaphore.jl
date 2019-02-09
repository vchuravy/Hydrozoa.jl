using LLVM
using LLVM.Compat
using CUDAnative

##
# TODO:
# - Do we need to support address-spaces
# - Alignment
##

abstract type AbstractSemaphore end

const SUCCESS = Int32(0)
const ERROR_TIMEOUT = Int32(11)
const ERROR_INVALID = Int32(22)

# must match verbs_exp enum
const GDS_WAIT_COND = Int32
const GDS_WAIT_COND_GEQ = Int32(0)
const GDS_WAIT_COND_EQ  = Int32(1)
const GDS_WAIT_COND_AND = Int32(2)
const GDS_WAIT_COND_NOR = Int32(3)

# Not currently needed
# mutable struct Semaphore{T} <: AbstractSemaphore
#     sem::T
#     value::T
# end
# 
# const Sem32 = Semaphore{UInt32}
# const Sem64 = Semaphore{UInt64}
# 
# @inline function Base.getindex(sem::ISemaphore{T}) where T
#     # volatile load from field
# end
# 
# @inline function Base.setindex(sem::ISemaphore{T}, val::T) where T
#     # volatile store to field
# end

struct ISemaphore{T} <: AbstractSemaphore
    sem::Ptr{T}
    value::T
    ISemaphore() = new(C_NULL, 0)
end
const ISem32 = ISemaphore{UInt32}
const ISem64 = ISemaphore{UInt64}

@generated function Base.getindex(sem::ISemaphore{T}) where T
    eltyp = convert(LLVMType, T)
    T_ptr = convert(LLVMType, Ptr{T})
    T_actual_ptr = LLVM.PointerType(eltyp)

    # create a function
    param_types = [T_ptr]
    llvm_f, _ create_function(eltyp, param_types)

    Builder(JuliaContext()) do builder
        entry = BasicBlock(llvm_f, "entry", JuliaContext())
        position!(builder, entry)

        ptr = inttoptr!(builder, parameters(llvm_f)[1], T_actual_ptr)
        ld = load!(builder, ptr)
        LLVM.API.LLVMSetVolatile(ld, LLVM.True)
        ret!(builder, ld)
    end

    call_function(llvm_f, T, Tuple{Ptr{T}}, :(sem.sem,))
end

@generated function Base.setindex!(sem::ISemaphore{T}, val::T) where T
    eltyp = convert(LLVMType, T)
    T_ptr = convert(LLVMType, Ptr{T})
    T_actual_ptr = LLVM.PointerType(eltyp)

    # create a function
    param_types = [T_ptr, eltyp]
    llvm_f, _ create_function(LLVM.VoidType(JuliaContext()), param_types)

    Builder(JuliaContext()) do builder
        entry = BasicBlock(llvm_f, "entry", JuliaContext())
        position!(builder, entry)

        ptr = inttoptr!(builder, parameters(llvm_f)[1], T_actual_ptr)
        val = parameters(llvm_f)[2]
        st = store!(builder, val, ptr)
        LLVM.API.LLVMSetVolatile(st, LLVM.True)
        ret!(builder)
    end

    call_function(llvm_f, Cvoid, Tuple{Ptr{T}, T}, :(sem.sem, val))
end

@inline function release(sem::Semaphore)
    @cuassert(C_NULL != sem[])
    sem[] = sem.value
end

@inline function wait(sem::Semaphore, cond)
    ret = SUCCESS 
    if cond == GDS_WAIT_COND_EQ
        ret = wait(sem, ==)
    elseif cond == GDS_WAIT_COND_GEQ
        ret = wait(sem, >=)
    elseif cond == GDS_WAIT_COND_AND
        # TODO: this is just (a&b) in C
        ret = wait(sem, (a, b) -> (a & b) == 1)
    elseif cond == GDS_WAIT_COND_NOR
        ret = wait(sem, (a, b) -> ~(a | b) != 0)
    else
        ret = ERROR_INVALID
    end
    return ret
end

@inline function wait(sem::Semaphore, cond::F) where F<:Function
    timeout = clock(UInt64) + UInt64(1) << 32 # this is marked volatile
    while (true)
        if cond(sem[], sem.value) 
            return SUCCESS
        end
        threadfence_block()
        if clock(UInt64) >= timeout
            return ERROR_TIMEOUT
        end
    end
end

