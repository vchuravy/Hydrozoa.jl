
export SendDesc, WaitDesc, send, wait, signal

const Cond = Int32

struct SendDesc
    dbrec::ISem32
    db::ISem64
end

struct WaitDesc
    cond::GDS_WAIT_COND
    sema::ISem32
    flag::ISem32
end

@inline function send(info::SendDesc)
    release(ind.dbrec)
    threadfence_system()
    release(info.db)
end

@inline function wait(info::WaitDesc)
    wait(info.sema, info.cond)
end

@inline function signal(info::WaitDesc)
    release(info.flag)
end
