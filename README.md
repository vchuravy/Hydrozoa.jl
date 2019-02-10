# Hydrozoa.jl
*Distributed communication driven by GPU kernels*

`Hydrozoa.jl` is a prototype to implement NVIDIA's GPUDirect Async
technology in Julia, with the goal to allow native Julia GPU kernels
written with [`CUDAnative.jl`](https://github.com/JuliaGPU/CUDAnative.jl)
to efficiently trigger distributed memory copies. This allows for GPU-GPU
communication without using MPI it builds on `libgdsync` and `libmp` from
NVIDIA.

- [`libmp`](https://github.com/gpudirect/libmp)
- [`libgdsync`](https://github.com/gpudirect/libgdsync)

## Low-level device interface

- `libmp`
  - [x] `send`
  - [x] `wait`
  - [x] `signal`
- `libgdsync`
  - [x] `ISem32`
  - [x] `release`
  - [x] `wait`

## Low-level host interface

- `libmp`
  - [x] `mp_init`
  - [x] `mp_finalize`
  - [x] `mp_request_t`
  - [x] `mp_reg_t`
  - [x] `mp_register`
  - [x] `mp_send_prepare`
  - [x] `mp_irecv`
  - [ ] `mp::mlx5::get_descriptors`
  - [x] `mp_wait_all`
  - [x] `mp_deregister`

## High-level interface

- [ ] Implement `all_gather`
